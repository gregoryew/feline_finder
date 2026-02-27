/// Ordered list of the 10 personality trait names (matches backend).
const List<String> kPersonalityTraitNames = [
  'Energy Level',
  'Playfulness',
  'Affection Level',
  'Independence',
  'Sociability',
  'Vocality',
  'Confidence',
  'Sensitivity',
  'Adaptability',
  'Intelligence',
];

/// One trait: score (1–5 or null), confidence (0–1), evidence (verbatim phrases).
class TraitDetail {
  final int? score;
  final double confidence;
  final List<String> evidence;

  const TraitDetail({
    this.score,
    this.confidence = 0,
    this.evidence = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'confidence': confidence,
      'evidence': List<String>.from(evidence),
    };
  }

  static TraitDetail? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final scoreRaw = map['score'];
    final score = scoreRaw is int
        ? scoreRaw
        : scoreRaw is num
            ? (scoreRaw as num).toInt()
            : null;
    final confidence = (map['confidence'] is num)
        ? (map['confidence'] as num).toDouble()
        : 0.0;
    final evidenceRaw = map['evidence'];
    final evidence = evidenceRaw is List
        ? evidenceRaw
            .where((e) => e is String)
            .map((e) => e as String)
            .toList()
        : <String>[];
    return TraitDetail(score: score, confidence: confidence, evidence: evidence);
  }
}

/// Personality fit record for one RescueGroups animal.
/// Stored in Hive (local) and Firestore (remote), keyed by animalId.
class AnimalFitRecord {
  static const String collectionId = 'animal_fit_scores';

  final String animalId;
  /// Trait names → TraitDetail (score, confidence, evidence). Exactly 10 traits.
  final Map<String, TraitDetail> traits;
  final String? suggestedCatTypeName;
  final double? fitScore;
  final DateTime updatedAt;
  final String? animalUpdatedDate;

  AnimalFitRecord({
    required this.animalId,
    required this.traits,
    this.suggestedCatTypeName,
    this.fitScore,
    required this.updatedAt,
    this.animalUpdatedDate,
  });

  /// Scores only (trait name → 1–5) for fit scoring. Uses score or 3 when null.
  Map<String, int> get traitScores {
    final out = <String, int>{};
    for (final e in traits.entries) {
      final s = e.value.score;
      out[e.key] = s != null && s >= 1 && s <= 5 ? s : 3;
    }
    return out;
  }

  Map<String, dynamic> toMap() {
    final traitsMap = <String, dynamic>{};
    for (final e in traits.entries) {
      traitsMap[e.key] = e.value.toMap();
    }
    return {
      'animalId': animalId,
      'traits': traitsMap,
      if (suggestedCatTypeName != null) 'suggestedCatTypeName': suggestedCatTypeName!,
      if (fitScore != null) 'fitScore': fitScore!,
      'updatedAt': updatedAt.toIso8601String(),
      if (animalUpdatedDate != null) 'animalUpdatedDate': animalUpdatedDate!,
    };
  }

  static AnimalFitRecord? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final animalId = map['animalId'] as String?;
    if (animalId == null) return null;
    final traitsRaw = map['traits'];
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
    final updatedAtStr = map['updatedAt'] as String?;
    final updatedAt = updatedAtStr != null
        ? DateTime.tryParse(updatedAtStr) ?? DateTime.now()
        : DateTime.now();
    return AnimalFitRecord(
      animalId: animalId,
      traits: traits,
      suggestedCatTypeName: map['suggestedCatTypeName'] as String?,
      fitScore: (map['fitScore'] as num?)?.toDouble(),
      updatedAt: updatedAt,
      animalUpdatedDate: map['animalUpdatedDate'] as String?,
    );
  }
}
