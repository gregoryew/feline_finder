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

  /// Fit score for a type name from [typeNameToFitScore] (keys lowercase); unknown => -1.
  static double _fitScoreForType(String? suggestedCatTypeName, Map<String, double>? typeNameToFitScore) {
    if (typeNameToFitScore == null || typeNameToFitScore.isEmpty) return -1;
    final key = suggestedCatTypeName?.trim().toLowerCase();
    if (key == null || key.isEmpty) return -1;
    return typeNameToFitScore[key] ?? -1;
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

  /// Sort: distance category asc, then type by fit to chosen (higher fit first; same type = same score), then archetype name A–Z, then sequence asc.
  static List<PetTileData> sortStableResults(List<PetTileData> items, {
    String? chosenTypeName,
    Map<String, double>? typeNameToFitScore,
  }) {
    final list = List<PetTileData>.from(items);
    list.sort((a, b) {
      final dcA = getDistanceCategory(a.distanceMiles);
      final dcB = getDistanceCategory(b.distanceMiles);
      if (dcA != dcB) return dcA.compareTo(dcB);

      if (typeNameToFitScore != null && typeNameToFitScore.isNotEmpty) {
        final sa = _fitScoreForType(a.suggestedCatTypeName, typeNameToFitScore);
        final sb = _fitScoreForType(b.suggestedCatTypeName, typeNameToFitScore);
        if (sa != sb) return sb.compareTo(sa);
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
    return list;
  }

  /// Visible items stay in [currentDisplayList] order; offscreen from [fullRanked].
  /// When visible items are not contiguous in fullRanked (e.g. after new items load
  /// and rank between them), we emit the frozen block once at the first visible
  /// and skip the rest so we never drop items or corrupt the list.
  static List<PetTileData> applyRankingWithFrozenVisibleItems({
    required List<PetTileData> currentDisplayList,
    required Set<String> visibleIds,
    required List<PetTileData> fullRanked,
  }) {
    if (visibleIds.isEmpty) return List.from(fullRanked);
    final frozenVisible = currentDisplayList
        .where((t) => t.id != null && t.id!.isNotEmpty && visibleIds.contains(t.id!))
        .where((t) => fullRanked.any((r) => r.id == t.id))
        .toList();
    if (frozenVisible.isEmpty) return List.from(fullRanked);
    final result = <PetTileData>[];
    var frozenEmitted = false;
    for (final item in fullRanked) {
      final id = item.id;
      if (id == null || id.isEmpty || !visibleIds.contains(id)) {
        result.add(item);
      } else {
        if (!frozenEmitted) {
          result.addAll(frozenVisible);
          frozenEmitted = true;
        }
      }
    }
    return result;
  }
}
