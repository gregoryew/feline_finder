import '../models/catType.dart';
import '../models/question_cat_types.dart';
import '../screens/globals.dart' as globals;

/// Computes personality fit scores for all cat types from the current slider values.
/// Used at app start (after loading sliders) and can be used by the Personality Fit screen.
class PersonalityFitScorer {
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

  /// Returns map of cat type id -> percent match (0.0–1.0) using server's saved slider values.
  static Map<int, double> computeScores(globals.FelineFinderServer server) {
    final desired = <Map<String, dynamic>>[];
    for (var q in Question_Cat_Types.questions) {
      final sliderVal = server.getPersonalityFitSliderValue(q.id);
      if (sliderVal > 0 && sliderVal < q.choices.length) {
        final choice = q.choices[sliderVal];
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
            final statName = _questionToStatName[questionName] ?? questionName;
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

          final statVal = stat!.name == 'Independence'
              ? independenceStatValueMapped(stat.value)
              : stat.value;
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
      if (desired.isEmpty) {
        newPercentMatch[ct.id] = 1.0;
      } else {
        newPercentMatch[ct.id] =
            ((sum / desired.length) * 100).floorToDouble() / 100;
      }
    }
    return newPercentMatch;
  }
}
