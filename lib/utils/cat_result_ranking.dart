import '../ExampleCode/petTileData.dart';

/// Stable ranking for cat adoption results: distance category, then archetype
/// (type) bucket so same type = same score, then sequence. Keeps the list calm
/// and avoids reshuffling when continuous fit scores change.
class CatResultRanking {
  CatResultRanking._();

  // ---------------------------------------------------------------------------
  // Distance categories (0 = nearest, 3 = 50+). Single place to adjust.
  // ---------------------------------------------------------------------------
  static const double kDistanceUnder10 = 10.0;
  static const double kDistanceUnder20 = 20.0;
  static const double kDistanceUnder50 = 50.0;

  /// Sentinel so null/unknown type sorts last.
  static const String _kUnknownTypeKey = '\uFFFF';

  /// Returns distance category: 0 = under 10 mi, 1 = 10–20, 2 = 20–50, 3 = 50+.
  /// Null/unknown distance is treated as 3 so those sort last.
  static int getDistanceCategory(double? miles) {
    final d = miles ?? 999.0;
    if (d < kDistanceUnder10) return 0;
    if (d < kDistanceUnder20) return 1;
    if (d < kDistanceUnder50) return 2;
    return 3;
  }

  /// Sort key for archetype when not using fit scores: same type => same key; chosen first, then alphabetical.
  static String getArchetypeSortKey(String? suggestedCatTypeName, [String? chosenTypeName]) {
    final s = suggestedCatTypeName?.trim();
    if (s == null || s.isEmpty) return _kUnknownTypeKey;
    final key = s.toLowerCase();
    final chosen = chosenTypeName?.trim().toLowerCase();
    if (chosen != null && chosen.isNotEmpty && key == chosen) {
      return '0$key';
    }
    return '1$key';
  }

  /// Fit score for an archetype (type name) from [typeNameToFitScore]. One score per archetype, not per cat; unknown => -1.
  static double _fitScoreForType(String? suggestedCatTypeName, Map<String, double>? typeNameToFitScore) {
    if (typeNameToFitScore == null || typeNameToFitScore.isEmpty) return -1;
    final key = suggestedCatTypeName?.trim().toLowerCase();
    if (key == null || key.isEmpty) return -1;
    return typeNameToFitScore[key] ?? -1;
  }

  /// Days ago from today (0 = today, 1 = yesterday). Used for date sort; null/unparseable => 999999 so they sort last.
  static int _dateSortKey(String? updatedDate) {
    if (updatedDate == null || updatedDate.isEmpty) return 999999;
    final dt = DateTime.tryParse(updatedDate);
    if (dt == null) return 999999;
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updatedDay = DateTime(local.year, local.month, local.day);
    final days = today.difference(updatedDay).inDays;
    if (days < 0) return 0;
    return days;
  }

  /// Within a distance or date section: sort by type fit score (higher = closer to chosen), then archetype name (A–Z), then sequence.
  /// When [typeNameToFitScore] is provided, types are ordered by how well they match the chosen type (same type = same score).
  static void sortByTypeThenSequence(List<PetTileData> list, {
    String? chosenTypeName,
    Map<String, double>? typeNameToFitScore,
  }) {
    list.sort((a, b) {
      if (typeNameToFitScore != null && typeNameToFitScore.isNotEmpty) {
        final sa = _fitScoreForType(a.suggestedCatTypeName, typeNameToFitScore);
        final sb = _fitScoreForType(b.suggestedCatTypeName, typeNameToFitScore);
        if (sa != sb) return sb.compareTo(sa); // higher fit first
      } else {
        final ta = getArchetypeSortKey(a.suggestedCatTypeName, chosenTypeName);
        final tb = getArchetypeSortKey(b.suggestedCatTypeName, chosenTypeName);
        if (ta != tb) return ta.compareTo(tb);
      }
      final nameA = (a.suggestedCatTypeName ?? _kUnknownTypeKey).toLowerCase();
      final nameB = (b.suggestedCatTypeName ?? _kUnknownTypeKey).toLowerCase();
      if (nameA != nameB) return nameA.compareTo(nameB);
      final seqA = a.sequenceNumber ?? 999999;
      final seqB = b.sequenceNumber ?? 999999;
      return seqA.compareTo(seqB);
    });
  }

  /// Sort for adopt list. When [useDistanceOrder] or [useDateOrder] is true, that is the primary key so
  /// distance/date bands stay contiguous (no "Under 10, 10–20, Under 10, 10–20" from batches).
  /// Otherwise: batch first, then fit → distance/date → archetype → sequence.
  /// Tiebreakers: batch, then fit (by archetype), then archetype name, then sequence.
  static List<PetTileData> sortByBatchDistanceFitTypeSequence(
    List<PetTileData> items, {
    Map<String, double>? typeNameToFitScore,
    bool useDateOrder = false,
    bool useDistanceOrder = false,
    String? chosenTypeName,
  }) {
    final list = List<PetTileData>.from(items);
    list.sort((a, b) {
      // Primary: date or distance when that's the active sort (date first so "Recently Updated" always wins).
      if (useDateOrder) {
        final dateA = _dateSortKey(a.updatedDate);
        final dateB = _dateSortKey(b.updatedDate);
        if (dateA != dateB) return dateA.compareTo(dateB);
      }
      if (useDistanceOrder) {
        final da = a.distanceMiles ?? 999.0;
        final db = b.distanceMiles ?? 999.0;
        if (da != db) return da.compareTo(db);
      }

      final batchA = a.batchOrder ?? 999999;
      final batchB = b.batchOrder ?? 999999;
      if (batchA != batchB) return batchA.compareTo(batchB);

      if (typeNameToFitScore != null && typeNameToFitScore.isNotEmpty) {
        final sa = _fitScoreForType(a.suggestedCatTypeName, typeNameToFitScore);
        final sb = _fitScoreForType(b.suggestedCatTypeName, typeNameToFitScore);
        if (sa != sb) return sb.compareTo(sa);
      }

      // When neither distance nor date is primary, still tie-break by distance then date
      if (!useDistanceOrder && !useDateOrder) {
        final da = a.distanceMiles ?? 999.0;
        final db = b.distanceMiles ?? 999.0;
        if (da != db) return da.compareTo(db);
        final dateA = _dateSortKey(a.updatedDate);
        final dateB = _dateSortKey(b.updatedDate);
        if (dateA != dateB) return dateA.compareTo(dateB);
      }

      final keyA = getArchetypeSortKey(a.suggestedCatTypeName, chosenTypeName);
      final keyB = getArchetypeSortKey(b.suggestedCatTypeName, chosenTypeName);
      if (keyA != keyB) return keyA.compareTo(keyB);

      // Within same cat type, sort by per-cat fit score (higher first)
      final fitA = a.personalityFitScore ?? -1.0;
      final fitB = b.personalityFitScore ?? -1.0;
      if (fitA != fitB) return fitB.compareTo(fitA);

      final seqA = a.sequenceNumber ?? 999999;
      final seqB = b.sequenceNumber ?? 999999;
      return seqA.compareTo(seqB);
    });
    return list;
  }
}
