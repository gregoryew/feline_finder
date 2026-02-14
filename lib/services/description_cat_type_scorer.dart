import 'package:catapp/models/catType.dart';
import 'package:catapp/models/searchPageConfig.dart';
import 'package:catapp/screens/globals.dart' as globals;

/// Infers a suggested cat type from an adoptable cat's description text
/// by matching filter synonyms to traits, then scoring against cat types (trait >= 4).
class DescriptionCatTypeScorer {
  DescriptionCatTypeScorer._();

  /// Filter name (personality, with synonyms) -> stat name(s) on CatType.
  static const Map<String, List<String>> _filterToStat = {
    'Activity Level': ['Energy Level'],
    'Energy level': ['Energy Level'],
    'Playful': ['Playfulness'],
    'Likes toys': ['Playfulness'],
    'Affectionate': ['Affection Level'],
    'Lap Cat': ['Affection Level'],
    'Independent/aloof': ['Independence'],
    'outgoing': ['Sociability'],
    'Likes to vocalize': ['Vocality'],
    'Gentleness': ['Sensitivity'],
    'curious': ['Adaptability', 'Intelligence'],
  };

  /// Returns the set of stat names implied by [descriptionText] (lowercased)
  /// using personality filter synonyms. Empty or null description returns empty set.
  static Set<String> _traitsFromDescription(String? descriptionText) {
    if (descriptionText == null || descriptionText.trim().isEmpty) {
      return {};
    }
    final lower = descriptionText.toLowerCase();
    final Set<String> statNames = {};
    for (final option in filteringOptions) {
      if (option.classification != CatClassification.personality) continue;
      final stats = _filterToStat[option.name];
      if (stats == null) continue;
      final synonyms = option.synonyms;
      for (final s in synonyms) {
        if (s.trim().isEmpty) continue;
        if (lower.contains(s.toLowerCase())) {
          statNames.addAll(stats);
          break;
        }
      }
    }
    return statNames;
  }

  /// Score for one cat type: (number of its high traits that appear in description) / (number of its high traits).
  /// High trait = stat with value >= 4.
  static double _scoreCatType(CatType type, Set<String> descriptionTraits) {
    final highTraits = <String>[];
    for (final stat in type.stats) {
      if (stat.value >= 4) highTraits.add(stat.name);
    }
    if (highTraits.isEmpty) return 0.0;
    final matched = highTraits.where((t) => descriptionTraits.contains(t)).length;
    return matched / highTraits.length;
  }

  /// Number of high traits (value >= 4) for [type].
  static int _highTraitCount(CatType type) {
    int n = 0;
    for (final stat in type.stats) {
      if (stat.value >= 4) n++;
    }
    return n;
  }

  /// "Above great" = same threshold as Personality Fit "Great" label: >= 85%.
  static const double _aboveGreatThreshold = 0.85;

  /// Returns the name of the top-matching cat type for [descriptionText], or null if no match.
  /// If the user has chosen a personality type on the search screen and this cat scores >= 85%
  /// for that type, returns that type. Otherwise returns the top-scoring type from description.
  static String? getTopCatTypeName(String? descriptionText) {
    final descriptionTraits = _traitsFromDescription(descriptionText);
    if (descriptionTraits.isEmpty) return null;

    final selectedName = globals.FelineFinderServer.instance.selectedPersonalityCatTypeName;
    if (selectedName != null && selectedName.isNotEmpty) {
      try {
        final selectedType = catType.firstWhere((t) => t.name == selectedName);
        final score = _scoreCatType(selectedType, descriptionTraits);
        if (score >= _aboveGreatThreshold) {
          return selectedName;
        }
      } catch (_) {
        // Selected type not in list, fall through to normal logic
      }
    }

    // Prefer types with 2+ high traits so one common word doesn't dominate.
    CatType? best;
    double bestScore = 0.0;
    for (final type in catType) {
      if (_highTraitCount(type) < 2) continue;
      final score = _scoreCatType(type, descriptionTraits);
      if (score > bestScore) {
        bestScore = score;
        best = type;
      } else if (score == bestScore && best != null) {
        final nameCompare = type.name.compareTo(best!.name);
        if (nameCompare < 0) best = type;
      }
    }
    if (best != null && bestScore > 0) return best!.name;

    // If no type with 2+ traits matched, use the type that matches the single trait.
    best = null;
    bestScore = 0.0;
    for (final type in catType) {
      final score = _scoreCatType(type, descriptionTraits);
      if (score > bestScore) {
        bestScore = score;
        best = type;
      } else if (score == bestScore && best != null) {
        final nameCompare = type.name.compareTo(best!.name);
        if (nameCompare < 0) best = type;
      }
    }
    return bestScore > 0 ? best?.name : null;
  }
}
