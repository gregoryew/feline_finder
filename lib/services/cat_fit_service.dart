import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/animal_fit_record.dart';
import '../models/searchPageConfig.dart';

/// Resolves personality fit for an animal: Hive (local) → Firestore → on-demand callable (Gemini).
class CatFitService {
  CatFitService._();
  static final CatFitService instance = CatFitService._();

  static const String _hiveBoxName = 'cat_fit_scores';

  /// Returns personality fit for [animalId], or null if unavailable.
  /// Tries Hive → Firestore → callable (Gemini). Writes to Hive on Firestore/callable hit.
  Future<AnimalFitRecord?> getFitForAnimal(
    String animalId, {
    String? description,
    String? name,
    String? shelterName,
    String? updatedDate,
  }) async {
    if (animalId.isEmpty) return null;

    // 1. Try Hive — always use cache when an entry exists
    try {
      if (Hive.isBoxOpen(_hiveBoxName)) {
        final raw = Hive.box(_hiveBoxName).get(animalId);
        Map<String, dynamic>? map;
        if (raw is String) {
          map = jsonDecode(raw) as Map<String, dynamic>?;
        } else if (raw is Map) {
          map = Map<String, dynamic>.from(raw as Map);
        }
        if (map != null) {
          final record = AnimalFitRecord.fromMap(map);
          if (record != null) return record;
        }
      }
    } catch (e) {
      print('CatFitService Hive read error for $animalId: $e');
    }

    // 2. Try Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection(AnimalFitRecord.collectionId)
          .doc(animalId)
          .get();
      if (doc.exists && doc.data() != null) {
        final record = AnimalFitRecord.fromMap(doc.data());
        if (record != null && !_isStale(record, updatedDate)) {
          _writeToHive(record);
          return record;
        }
      }
    } catch (e) {
      print('CatFitService Firestore read error for $animalId: $e');
    }

    // 3. Call on-demand function (requires description)
    if (description == null || description.trim().isEmpty) return null;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'computeAnimalPersonalityFit',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'id': animalId,
        'description': description.trim(),
        if (name != null && name.isNotEmpty) 'name': name,
        if (shelterName != null && shelterName.trim().isNotEmpty) 'shelterName': shelterName.trim(),
        if (updatedDate != null && updatedDate.isNotEmpty) 'updatedDate': updatedDate,
      });
      final data = result.data;
      if (data == null) return null;

      final traitsRaw = data['traits'];
      final Map<String, TraitDetail> traits = {};
      if (traitsRaw is Map) {
        for (final e in (traitsRaw as Map).entries) {
          final key = e.key.toString();
          final v = e.value;
          if (v is int) {
            traits[key] = TraitDetail(score: v, confidence: 0, evidence: []);
          } else if (v is num) {
            traits[key] = TraitDetail(score: (v as num).toInt(), confidence: 0, evidence: []);
          } else if (v is Map) {
            final detail = TraitDetail.fromMap(Map<String, dynamic>.from(v as Map));
            if (detail != null) traits[key] = detail;
          }
        }
      }
      final updatedAtStr = data['updatedAt'] as String?;
      final updatedAt = updatedAtStr != null
          ? DateTime.tryParse(updatedAtStr) ?? DateTime.now()
          : DateTime.now();
      final record = AnimalFitRecord(
        animalId: animalId,
        traits: traits,
        suggestedCatTypeName: data['suggestedCatTypeName'] as String?,
        updatedAt: updatedAt,
        animalUpdatedDate: updatedDate,
      );
      _writeToHive(record);
      return record;
    } catch (e) {
      print('CatFitService callable error for $animalId: $e');
      return null;
    }
  }

  bool _isStale(AnimalFitRecord record, String? animalUpdatedDate) {
    if (animalUpdatedDate == null || animalUpdatedDate.isEmpty) return false;
    final stored = record.animalUpdatedDate;
    if (stored == null || stored.isEmpty) return false;
    // If RescueGroups updatedDate is after our stored one, consider stale
    final a = DateTime.tryParse(animalUpdatedDate);
    final b = DateTime.tryParse(stored);
    if (a != null && b != null && a.isAfter(b)) return true;
    return false;
  }

  void _writeToHive(AnimalFitRecord record) {
    try {
      if (Hive.isBoxOpen(_hiveBoxName)) {
        Hive.box(_hiveBoxName).put(
          record.animalId,
          jsonEncode(record.toMap()),
        );
      }
    } catch (e) {
      print('CatFitService Hive write error: $e');
    }
  }

  /// Filter name (search screen) → CatType stat name (trait key from Gemini).
  static const Map<String, String> _filterNameToTrait = {
    'Energy Level': 'Energy Level',
    'Playfulness': 'Playfulness',
    'Affectionate': 'Affection Level',
    'Independence': 'Independence',
    'Sociability': 'Sociability',
    'Vocalization': 'Vocality',
    'Confidence': 'Confidence',
    'Sensitivity': 'Sensitivity',
    'Adaptability': 'Adaptability',
    'Intelligence': 'Intelligence',
    'Calmness': 'Confidence',
    'Gentleness': 'Sensitivity',
    'Lap Cat': 'Affection Level',
    'Likes toys': 'Playfulness',
    'Timid / shy': 'Confidence',
    'Curious': 'Adaptability',
    'New People': 'Sociability',
  };

  /// Builds user trait profile (trait name → 1–5) from current personality slider filters.
  /// Value 0 (Any) is treated as 3 (neutral). Only includes slider personality filters.
  static Map<String, int> userTraitProfileFromFilterOptions(
    List<filterOption> filteringOptions,
  ) {
    final Map<String, int> profile = {};
    for (final f in filteringOptions) {
      if (!f.slider || f.options.isEmpty) continue;
      final traitName = _filterNameToTrait[f.name];
      if (traitName == null) continue;
      final chosen = f.choosenListValues.isNotEmpty ? f.choosenListValues.first : 0;
      // 0 = Any → treat as 3 (neutral); 1–5 = scale
      final value = chosen == 0 ? 3 : chosen.clamp(1, 5);
      profile[traitName] = value;
    }
    return profile;
  }

  /// Computes fit score 0–100 from cat traits vs user profile (higher = better match).
  static double computeFitScore(
    Map<String, int>? catTraits,
    Map<String, int> userProfile,
  ) {
    if (catTraits == null || catTraits.isEmpty || userProfile.isEmpty) return 0;
    double sum = 0;
    int count = 0;
    for (final e in userProfile.entries) {
      final catValue = catTraits[e.key];
      if (catValue == null) continue;
      // Similarity: 1 - normalized distance (0-4 scale -> 0-1)
      final diff = (catValue - e.value).abs();
      sum += 1.0 - (diff / 4.0);
      count++;
    }
    if (count == 0) return 0;
    return (sum / count) * 100;
  }
}
