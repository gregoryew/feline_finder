import 'package:catapp/models/catType.dart';
import 'package:catapp/models/question_cat_types.dart';
import 'package:catapp/models/searchPageConfig.dart';
import 'package:catapp/screens/globals.dart' as globals;

/// Result of [CatTypeFilterMapping.getTopCatTypeFromSearchFilters] (avoids Dart 3 records for SDK compatibility).
class TopCatTypeResult {
  final CatType? type;
  final double matchPercent;
  const TopCatTypeResult(this.type, this.matchPercent);
}

/// Maps cat types to search-screen personality filters.
/// If a trait on the cat type is >= 4, that cat type is considered to have that filter.
/// Only personality filters are mapped.
class CatTypeFilterMapping {
  CatTypeFilterMapping._();

  /// Search-screen slider filter name -> CatType stat name (for setting slider to 1-5 from cat type).
  static const Map<String, String> _sliderFilterToStatName = {
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
    'New People': 'New People', // derived from Sociability + Confidence
  };

  /// Stat name (on CatType) -> list of (filter option name, value to set).
  /// Value is either String (for choosenValue) or List<int> (for choosenListValues).
  /// Energy Level is handled separately: Activity/Energy are set from the cat type's Energy stat (1-2→low, 3→medium, 4-5→high).
  static const Map<String, List<MapEntry<String, dynamic>>> _statToFilters = {
    'Playfulness': [
      MapEntry('Playful', 'Yes'),
      MapEntry('Likes toys', 'Yes'),
    ],
    'Affection Level': [
      MapEntry('Affectionate', 'Yes'),
      MapEntry('Lap Cat', 'Yes'),
    ],
    'Independence': [
      MapEntry('Independent/aloof', 'Yes'),
    ],
    'Sociability': [
      MapEntry('outgoing', 'Yes'),
    ],
    // Vocality: set from cat type's Vocality stat (1–2→Quiet, 3→Some, 4–5→Lots) in applyCatTypeToFilterOptions
    'Sensitivity': [
      MapEntry('Gentleness', 'Yes'),
    ],
    'Adaptability': [
      MapEntry('curious', 'Yes'),
    ],
    'Intelligence': [
      MapEntry('curious', 'Yes'),
    ],
    // Confidence: no personality filter for "confident"; skip
  };

  /// Returns target slider values (1–5) for each personality slider filter from the cat type.
  /// Used when applying a cat type so sliders can be set and optionally animated.
  /// Keys are filter names; values are in range 1–5 (0 = Any is not used for targets).
  static Map<String, int> getSliderTargetValuesForCatType(CatType type) {
    final Map<String, int> out = {};
    double? sociability;
    double? confidence;
    for (final s in type.stats) {
      if (s.name == 'Sociability') sociability = s.value;
      if (s.name == 'Confidence') confidence = s.value;
    }
    for (final entry in _sliderFilterToStatName.entries) {
      final filterName = entry.key;
      final statName = entry.value;
      int value;
      if (statName == 'New People') {
        final s = (sociability ?? 3).round().clamp(1, 5);
        final c = (confidence ?? 3).round().clamp(1, 5);
        value = ((s + c) / 2).round().clamp(1, 5);
      } else {
        try {
          final stat = type.stats.firstWhere((s) => s.name == statName);
          value = stat.value.round().clamp(1, 5);
        } catch (_) {
          continue;
        }
      }
      out[filterName] = value;
    }
    return out;
  }

  /// Returns trait profile (stat name → 1–5) for fit scoring against cat traits.
  /// Use this when a cat type is selected so ordering uses the chosen type's profile, not slider state.
  static Map<String, int> getTraitProfileForCatType(CatType type) {
    final Map<String, int> profile = {};
    for (final s in type.stats) {
      profile[s.name] = s.value.round().clamp(1, 5);
    }
    return profile;
  }

  /// Returns the personality filter updates for this cat type (traits >= 4).
  /// Key = filter option name, value = String for choosenValue or List<int> for choosenListValues.
  static Map<String, dynamic> getPersonalityFiltersForCatType(CatType type) {
    final Map<String, dynamic> out = {};
    for (final stat in type.stats) {
      if (stat.value < 4) continue;
      final entries = _statToFilters[stat.name];
      if (entries == null) continue;
      for (final e in entries) {
        out[e.key] = e.value;
      }
    }
    return out;
  }

  /// Sets all personality filters to "Any" so a cat type mapping starts from a clean state.
  /// Slider filters are set to 0 (Any); other list filters to the "Any" option.
  static void setPersonalityFiltersToAny(List<filterOption> filteringOptions) {
    final personalityFilters = filteringOptions
        .where((f) => f.classification == CatClassification.personality)
        .toList();

    for (final filter in personalityFilters) {
      if (filter.fieldName == 'zipCode') continue;

      if (filter.list) {
        if (filter.options.isNotEmpty) {
          if (filter.slider) {
            filter.choosenListValues = [0]; // 0 = Any for personality sliders
          } else {
            final anyOption = filter.options.last;
            filter.choosenListValues = [anyOption.value];
          }
        }
      } else {
        if (filter.options.isNotEmpty) {
          final anyOption = filter.options.firstWhere(
            (opt) =>
                opt.search == 'Any' ||
                opt.search == 'Any Type' ||
                opt.search == 'any',
            orElse: () => filter.options.last,
          );
          filter.choosenValue = anyOption.search;
        }
      }
    }
  }

  /// Maps energy value (1–5 from cat type stat or personality question) to Activity Level and Energy level filter values.
  /// 1 or 2 → low, 3 → medium, 4 or 5 → high.
  static void _applyEnergyToFilters(
    double energyValue,
    List<filterOption> filteringOptions,
  ) {
    final v = energyValue.round();
    if (v < 1 || v > 5) return;

    List<int> activityListValues;
    List<int> energyListValues;
    if (v == 1 || v == 2) {
      activityListValues = [1]; // Low (Slightly Active)
      energyListValues = [0];   // Low
    } else if (v == 3) {
      activityListValues = [2]; // Medium (Moderately Active)
      energyListValues = [1];   // Medium
    } else {
      activityListValues = [3]; // High (Highly Active)
      energyListValues = [2];   // High
    }

    for (final filter in filteringOptions) {
      if (filter.classification != CatClassification.personality) continue;
      if (filter.name == 'Activity Level') {
        filter.choosenListValues = activityListValues;
      } else if (filter.name == 'Energy level') {
        filter.choosenListValues = energyListValues;
      }
    }
  }

  /// Maps Vocality stat value (1–5) to "Likes to vocalize" filter: 5 levels from Quiet (1) to Lots (5).
  static void _applyVocalityToFilters(
    double vocalityValue,
    List<filterOption> filteringOptions,
  ) {
    final v = vocalityValue.round().clamp(1, 5);
    // 1 → Quiet (0), 2 → A Little (1), 3 → Some (2), 4 → Talkative (3), 5 → Lots (4)
    final vocalizeListValues = [v - 1];

    for (final filter in filteringOptions) {
      if (filter.classification != CatClassification.personality) continue;
      if (filter.name == 'Likes to vocalize') {
        filter.choosenListValues = vocalizeListValues;
        break;
      }
    }
  }

  /// Maps Sociability and Confidence (1–5) to "New People" filter: high (4–5) → Friendly, low (1–2) → Cautious, else → Any.
  /// Uses the higher of the two stats so either trait can indicate friendliness.
  static void _applyNewPeopleToFilters(
    double sociabilityValue,
    double confidenceValue,
    List<filterOption> filteringOptions,
  ) {
    final s = sociabilityValue.round().clamp(1, 5);
    final c = confidenceValue.round().clamp(1, 5);
    final effective = s > c ? s : c;

    List<int> newPeopleListValues;
    if (effective <= 2) {
      newPeopleListValues = [0]; // Cautious
    } else if (effective >= 4) {
      newPeopleListValues = [1]; // Friendly
    } else {
      newPeopleListValues = [2]; // Any
    }

    for (final filter in filteringOptions) {
      if (filter.classification != CatClassification.personality) continue;
      if (filter.name == 'New People') {
        filter.choosenListValues = newPeopleListValues;
        break;
      }
    }
  }

  /// Applies only non-slider parts of a cat type: resets to Any, then sets Activity Level,
  /// Energy level, Likes to vocalize, New People, and any chip-based personality filters.
  /// Does not set slider values; use with animated slider application in the UI.
  static void applyCatTypeNonSliderParts(
    CatType type,
    List<filterOption> filteringOptions,
  ) {
    setPersonalityFiltersToAny(filteringOptions);
    try {
      final energyStat = type.stats.firstWhere((s) => s.name == 'Energy Level');
      _applyEnergyToFilters(energyStat.value, filteringOptions);
    } catch (_) {}
    try {
      final vocalityStat = type.stats.firstWhere((s) => s.name == 'Vocality');
      _applyVocalityToFilters(vocalityStat.value, filteringOptions);
    } catch (_) {}
    double? sociability;
    double? confidence;
    for (final s in type.stats) {
      if (s.name == 'Sociability') sociability = s.value;
      if (s.name == 'Confidence') confidence = s.value;
    }
    if (sociability != null || confidence != null) {
      _applyNewPeopleToFilters(
        sociability ?? 3,
        confidence ?? 3,
        filteringOptions,
      );
    }
    final updates = getPersonalityFiltersForCatType(type);
    final personalityFilters = filteringOptions
        .where((f) => f.classification == CatClassification.personality && !f.slider)
        .toList();
    for (final filter in personalityFilters) {
      final value = updates[filter.name];
      if (value == null) continue;
      if (filter.list && value is List<int> && value.isNotEmpty) {
        filter.choosenListValues = List<int>.from(value);
      } else if (value is String) {
        filter.choosenValue = value;
      }
    }
  }

  /// Applies a cat type's personality filters to [filteringOptions].
  /// Slider personality filters are set to the cat type's trait value (1–5); range is 1–5 (0 = Any).
  /// Activity Level and Energy level are set from the cat type's Energy Level stat
  /// (1–2→low, 3→medium, 4–5→high). Non-slider chip filters use getPersonalityFiltersForCatType.
  static void applyCatTypeToFilterOptions(
    CatType type,
    List<filterOption> filteringOptions, {
    globals.FelineFinderServer? server,
  }) {
    setPersonalityFiltersToAny(filteringOptions);

    final sliderTargets = getSliderTargetValuesForCatType(type);
    final personalityFilters = filteringOptions
        .where((f) => f.classification == CatClassification.personality)
        .toList();

    for (final filter in personalityFilters) {
      if (filter.slider && filter.list && filter.options.isNotEmpty) {
        final value = sliderTargets[filter.name];
        if (value != null) {
          final clamped = value.clamp(1, 5);
          if (filter.options.any((o) => o.value == clamped)) {
            filter.choosenListValues = [clamped];
          }
        }
        continue;
      }

      final value = getPersonalityFiltersForCatType(type)[filter.name];
      if (value == null) continue;

      if (filter.list) {
        if (value is List<int> && value.isNotEmpty) {
          filter.choosenListValues = List<int>.from(value);
        }
      } else {
        if (value is String) {
          filter.choosenValue = value;
        }
      }
    }

    // Set Activity Level and Energy level from this cat type's Energy Level stat (1–2→low, 3→medium, 4–5→high).
    try {
      final energyStat = type.stats.firstWhere((s) => s.name == 'Energy Level');
      _applyEnergyToFilters(energyStat.value, filteringOptions);
    } catch (_) {}

    // Set Likes to vocalize from this cat type's Vocality stat (1–2→Quiet, 3→Some, 4–5→Lots).
    try {
      final vocalityStat = type.stats.firstWhere((s) => s.name == 'Vocality');
      _applyVocalityToFilters(vocalityStat.value, filteringOptions);
    } catch (_) {}

    // Set New People (chip) from Sociability and Confidence (high → Friendly, low → Cautious).
    double? sociability;
    double? confidence;
    for (final s in type.stats) {
      if (s.name == 'Sociability') sociability = s.value;
      if (s.name == 'Confidence') confidence = s.value;
    }
    if (sociability != null || confidence != null) {
      _applyNewPeopleToFilters(
        sociability ?? 3,
        confidence ?? 3,
        filteringOptions,
      );
    }
  }

  /// Whether the user has set any personality slider away from "Flexible" (0).
  static bool hasPersonalityPreference(globals.FelineFinderServer server) {
    return Question_Cat_Types.questions.any(
      (q) => server.getPersonalityFitSliderValue(q.id) > 0,
    );
  }

  static const Map<String, String> _questionToStatName = {
    'Energy Level': 'Energy Level',
    'Playfulness': 'Playfulness',
    'Affection Level': 'Affection Level',
    'Independence': 'Independence',
    'Sociability': 'Sociability',
    'Vocalization': 'Vocality',
    'Confidence': 'Confidence',
    'Sensitivity': 'Sensitivity',
    'Adaptability': 'Adaptability',
    'Intelligence': 'Intelligence',
  };

  /// Top cat type by current personality slider preferences, or null if no preference.
  static CatType? getTopPersonalityCatType(globals.FelineFinderServer server) {
    final desired = <Map<String, dynamic>>[];
    for (var q in Question_Cat_Types.questions) {
      final sliderVal = server.getPersonalityFitSliderValue(q.id);
      if (sliderVal > 0 && sliderVal < q.choices.length) {
        final choice = q.choices[sliderVal];
        // Independence question: 1=Very Independent, 5=Very Affectionate;
        // stat scale: 1=low independence, 5=high. Invert so match is correct.
        final value = q.name == 'Independence' && choice.lowRange > 0
            ? (6.0 - choice.lowRange)
            : choice.lowRange.toDouble();
        desired.add({
          'questionId': q.id,
          'name': q.name,
          'value': value,
        });
      }
    }
    if (desired.isEmpty) return null;

    final newPercentMatch = <int, double>{};
    for (var i = 0; i < catType.length; i++) {
      final ct = catType[i];
      double sum = 0;
      for (var j = 0; j < desired.length; j++) {
        try {
          final questionId = desired[j]['questionId'] as int;
          final questionName = desired[j]['name'] as String;
          final desiredValue = desired[j]['value'] as double;
          StatValue? stat;
          try {
            final statName =
                _questionToStatName[questionName] ?? questionName;
            stat = ct.stats.firstWhere((s) => s.name == statName);
          } catch (_) {
            continue;
          }
          Question_Cat_Types? q;
          try {
            q = Question_Cat_Types.questions.firstWhere((q) => q.id == questionId);
          } catch (_) {
            continue;
          }
          final statVal = stat!.name == 'Independence' ? independenceStatValueMapped(stat.value) : stat.value;
          if (stat.isPercent) {
            sum += 1.0 -
                (desiredValue - statVal).abs() / (q.choices.length - 1);
          } else {
            final traitValues = q.choices
                .where((c) => c.lowRange > 0)
                .map((c) => c.lowRange.toDouble())
                .toList();
            final range = traitValues.isEmpty
                ? 4.0
                : (traitValues.reduce((a, b) => a > b ? a : b) -
                    traitValues.reduce((a, b) => a < b ? a : b));
            final maxDistance = range < 1.0 ? 1.0 : range;
            final score = maxDistance <= 0
                ? (desiredValue == statVal ? 1.0 : 0.0)
                : (1.0 - (desiredValue - statVal).abs() / maxDistance)
                    .clamp(0.0, 1.0);
            sum += score;
          }
        } catch (_) {
          continue;
        }
      }
      newPercentMatch[ct.id] =
          ((sum / desired.length) * 100).floorToDouble() / 100;
    }

    final order = List<int>.from(catType.map((c) => c.id));
    order.sort((a, b) {
      final matchComparison =
          (newPercentMatch[b] ?? 0.0).compareTo(newPercentMatch[a] ?? 0.0);
      if (matchComparison != 0) return matchComparison;
      final nameA = catType.firstWhere((c) => c.id == a).name;
      final nameB = catType.firstWhere((c) => c.id == b).name;
      return nameA.compareTo(nameB);
    });

    if (order.isEmpty) return null;
    final topId = order.first;
    return catType.firstWhere((c) => c.id == topId, orElse: () => catType.first);
  }

  /// Top cat type from search-screen personality sliders (filteringOptions).
  /// Returns the best-matching type and its match percent (0–1), or type=null and matchPercent=0 if no slider preference.
  static TopCatTypeResult getTopCatTypeFromSearchFilters(
    List<filterOption> filteringOptions,
  ) {
    final desired = <String, double>{};
    for (final f in filteringOptions) {
      if (f.classification != CatClassification.personality ||
          !f.slider ||
          !f.list ||
          f.options.isEmpty) continue;
      final statName = _sliderFilterToStatName[f.name];
      if (statName == null) continue;
      final v = f.choosenListValues.isNotEmpty ? f.choosenListValues.first : 0;
      if (v < 1 || v > 5) continue;
      desired[statName] = v.toDouble();
    }
    if (desired.isEmpty) return const TopCatTypeResult(null, 0.0);

    final newPercentMatch = <int, double>{};
    for (var i = 0; i < catType.length; i++) {
      final ct = catType[i];
      double sum = 0;
      int count = 0;
      for (final entry in desired.entries) {
        final statName = entry.key;
        final desiredValue = entry.value;
        StatValue? stat;
        try {
          stat = ct.stats.firstWhere((s) => s.name == statName);
        } catch (_) {
          continue;
        }
        count++;
        // Search sliders use 1=dependent, 5=independent; same scale as cat type stat.
        final statVal = stat!.value;
        final maxDistance = 4.0;
        final score = maxDistance <= 0
            ? (desiredValue == statVal ? 1.0 : 0.0)
            : (1.0 - (desiredValue - statVal).abs() / maxDistance).clamp(0.0, 1.0);
        sum += score;
      }
      if (count > 0) {
        newPercentMatch[ct.id] = sum / count;
      }
    }

    if (newPercentMatch.isEmpty) return const TopCatTypeResult(null, 0.0);
    final order = List<int>.from(catType.map((c) => c.id));
    order.sort((a, b) {
      final c = (newPercentMatch[b] ?? 0.0).compareTo(newPercentMatch[a] ?? 0.0);
      if (c != 0) return c;
      final nameA = catType.firstWhere((c) => c.id == a).name;
      final nameB = catType.firstWhere((c) => c.id == b).name;
      return nameA.compareTo(nameB);
    });
    final topId = order.first;
    final top = catType.firstWhere((c) => c.id == topId, orElse: () => catType.first);
    final percent = newPercentMatch[topId] ?? 0.0;
    return TopCatTypeResult(top, percent);
  }

  /// Whether search-screen filteringOptions have any personality slider set (value 1–5).
  static bool hasPersonalityPreferenceFromSearchFilters(
    List<filterOption> filteringOptions,
  ) {
    for (final f in filteringOptions) {
      if (f.classification != CatClassification.personality || !f.slider || !f.list) continue;
      if (f.choosenListValues.isEmpty) continue;
      final v = f.choosenListValues.first;
      if (v >= 1 && v <= 5) return true;
    }
    return false;
  }
}
