import 'package:catapp/models/catType.dart';
import 'package:catapp/models/question_cat_types.dart';
import 'package:catapp/models/searchPageConfig.dart';
import 'package:catapp/screens/globals.dart' as globals;

/// Maps cat types to search-screen personality filters.
/// If a trait on the cat type is >= 4, that cat type is considered to have that filter.
/// Only personality filters are mapped.
class CatTypeFilterMapping {
  CatTypeFilterMapping._();

  /// Stat name (on CatType) -> list of (filter option name, value to set).
  /// Value is either String (for choosenValue) or List<int> (for choosenListValues).
  static const Map<String, List<MapEntry<String, dynamic>>> _statToFilters = {
    'Energy Level': [
      MapEntry('Activity Level', [3]), // High (Highly Active)
      MapEntry('Energy level', [2]),   // High
    ],
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
    'Vocality': [
      MapEntry('Likes to vocalize', [2]), // Lots
    ],
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
  static void setPersonalityFiltersToAny(List<filterOption> filteringOptions) {
    final personalityFilters = filteringOptions
        .where((f) => f.classification == CatClassification.personality)
        .toList();

    for (final filter in personalityFilters) {
      if (filter.fieldName == 'zipCode') continue;

      if (filter.list) {
        if (filter.options.isNotEmpty) {
          final anyOption = filter.options.last;
          filter.choosenListValues = [anyOption.value];
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

  /// Applies a cat type's personality filters to [filteringOptions].
  /// Call [setPersonalityFiltersToAny] first so only the mapped filters are set.
  /// Only updates filters with [CatClassification.personality] and matching name.
  /// List filters: sets [choosenListValues] to the single value in a list.
  /// Single filters: sets [choosenValue] to the string (e.g. "Yes").
  static void applyCatTypeToFilterOptions(
    CatType type,
    List<filterOption> filteringOptions,
  ) {
    setPersonalityFiltersToAny(filteringOptions);

    final updates = getPersonalityFiltersForCatType(type);
    final personalityFilters = filteringOptions
        .where((f) => f.classification == CatClassification.personality)
        .toList();

    for (final filter in personalityFilters) {
      final value = updates[filter.name];
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
  }

  /// Whether the user has set any personality slider away from "Doesn't Matter" (0).
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
          if (stat.isPercent) {
            sum += 1.0 -
                (desiredValue - stat.value).abs() / (q.choices.length - 1);
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
                ? (desiredValue == stat.value ? 1.0 : 0.0)
                : (1.0 - (desiredValue - stat.value).abs() / maxDistance)
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
}
