import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../main.dart' as main;
import '../models/rescuegroups_v5.dart';
import '../utils/cat_result_ranking.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import '/screens/petDetail.dart';
import '/screens/search.dart';
import '../config.dart';
import '../services/description_cat_type_scorer.dart';
import '../services/cat_fit_service.dart';
import '../services/cat_type_filter_mapping.dart';
import '/models/catType.dart';
import 'globals.dart' as globals;

// GOLD UI COMPONENTS
import '../widgets/gold/gold_pet_card.dart';
import '../widgets/gold/gold_zip_button.dart';

import '../theme.dart';
import '../models/searchPageConfig.dart' as searchConfig;
import '../network_utils.dart';
import '../widgets/status_chip_bar.dart';
import 'select_shelters_screen.dart';

/// One distance band to display: optional header label and list of tiles (sorted by score within band).
class _DistanceSection {
  final String? label;
  final List<PetTileData> tiles;
  _DistanceSection(this.label, this.tiles);
}

/// Distance band: max miles (exclusive) and display label.
class _DistanceBand {
  final double maxMiles;
  final String label;
  const _DistanceBand(this.maxMiles, this.label);
}

const List<_DistanceBand> _kDistanceBands = [
  _DistanceBand(10, 'Under 10 miles'),
  _DistanceBand(20, '10 to 20 miles'),
  _DistanceBand(50, '20 to 50 miles'),
  _DistanceBand(double.infinity, '50+ miles'),
];

/// Time/recency band for "sort by recent": label only (order is fixed).
class _TimeBand {
  final String label;
  const _TimeBand(this.label);
}

/// Order: newest first (Today, Past 7 days, Past 30 days, Past year, Over a year ago).
const List<_TimeBand> _kTimeBands = [
  _TimeBand('Today'),
  _TimeBand('Past 7 days'),
  _TimeBand('Past 30 days'),
  _TimeBand('Past year'),
  _TimeBand('Over a year ago'),
];

/// Pinned sticky header delegate for section labels.
class _StickySectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickySectionHeaderDelegate(this.label);

  final String label;
  static const double _headerHeight = 52;
  static const double headerHeight = _headerHeight;

  @override
  double get minExtent => _headerHeight;

  @override
  double get maxExtent => _headerHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.purpleGradient,
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: AppTheme.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySectionHeaderDelegate oldDelegate) {
    return oldDelegate.label != label;
  }
}

/// Reports its height after layout so we can compute which section is at top (single sticky header).
class _MeasureSectionChild extends StatefulWidget {
  const _MeasureSectionChild({
    required this.sectionIndex,
    required this.onHeight,
    required this.child,
  });
  final int sectionIndex;
  final void Function(int sectionIndex, double height) onHeight;
  final Widget child;

  @override
  State<_MeasureSectionChild> createState() => _MeasureSectionChildState();
}

class _MeasureSectionChildState extends State<_MeasureSectionChild> {
  @override
  void didUpdateWidget(_MeasureSectionChild oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  void _reportHeight() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      widget.onHeight(widget.sectionIndex, box.size.height);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AdoptGrid extends StatefulWidget {
  final ValueChanged<bool>? setFav;
  const AdoptGrid({Key? key, this.setFav}) : super(key: key);

  @override
  AdoptGridState createState() => AdoptGridState();
}

class AdoptGridState extends State<AdoptGrid> {
  List<PetTileData> tiles = [];
  int maxPets = -1;
  String count = "Processing";
  int tilesPerLoad = 25;
  late ScrollController controller;
  List<String> favorites = [];
  String? userID;
  final server = globals.FelineFinderServer.instance;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  /// Video badge: ids that have been seen (first time in view); reset on new search/zip.
  final Set<String> _videoBadgeSeenIds = {};
  /// Video badge: ids currently showing glow; cleared after animation.
  final Set<String> _videoBadgeGlowIds = {};

  /// Section grid heights for scroll-based sticky header (only one header at top).
  List<double> _sectionHeights = [];
  int _currentStickySectionIndex = 0;
  bool _sectionHeightsUpdateScheduled = false;

  /// Prevents multiple getPets() in flight (e.g. scroll firing repeatedly).
  bool _isLoadingPets = false;

  /// Next sequence number when a tile is first added. Reset when tiles are cleared.
  int _nextSequence = 0;
  /// Next batch id for new pages. Reset when tiles are cleared; set all to 1 when user sorts.
  int _nextBatchId = 1;
  /// Total count from API (meta.count). Used to know when no more pages.
  int _totalFromAPI = -1;
  /// Prefs key for sort-help-seen (optional first-time hint).
  static const String _kSortHelpSeenKey = 'adopt_sort_help_seen';

  /// Selected cat type when we last loaded the list; used to requery when user changes type on Fit tab.
  String? _lastSelectedTypeWhenLoaded;

  /// Where the chosen type came from: 'fit' or 'search'. Shown in status chip as "(from Fit)" / "(from Search)".
  String? _chosenCatTypeSource;

  /// Cache: type name (lowercase) -> fit score vs chosen type. Invalid when chosen type changes.
  Map<String, double>? _typeNameToFitScoreCache;
  String? _typeNameToFitScoreChosen;

  /// Map each archetype to its fit score vs the selected type. One score per archetype (from catType trait profiles), not per cat.
  /// Used only for sort order (batch → distance/date → archetype → fit → sequence); per-cat personalityFitScore is never used for ordering.
  Map<String, double> _getTypeNameToFitScore() {
    final chosen = server.selectedPersonalityCatTypeName?.trim();
    if (chosen == null || chosen.isEmpty) return {};
    if (_typeNameToFitScoreCache != null && _typeNameToFitScoreChosen == chosen) {
      return _typeNameToFitScoreCache!;
    }
    CatType? chosenCatType;
    for (final ct in catType) {
      if (ct.name.trim().toLowerCase() == chosen.toLowerCase()) {
        chosenCatType = ct;
        break;
      }
    }
    if (chosenCatType == null) return {};
    final chosenProfile = CatTypeFilterMapping.getTraitProfileForCatType(chosenCatType);
    final map = <String, double>{};
    for (final ct in catType) {
      final profile = CatTypeFilterMapping.getTraitProfileForCatType(ct);
      final score = CatFitService.computeFitScore(profile, chosenProfile);
      map[ct.name.trim().toLowerCase()] = score;
    }
    _typeNameToFitScoreChosen = chosen;
    _typeNameToFitScoreCache = map;
    return map;
  }

  List<Filters> filters = [];
  List<Filters> filters_backup = [];
  String? filterprocessing;
  String? RescueGroupApi = "";

  late TextEditingController controller2;
  
  // Get filtering options from searchPageConfig
  List<searchConfig.filterOption> get filteringOptions {
    // Use persistentFilteringOptions if available, otherwise use the global filteringOptions
    if (searchConfig.persistentFilteringOptions.isNotEmpty) {
      return searchConfig.persistentFilteringOptions;
    }
    // Access the global filteringOptions variable from searchPageConfig
    return searchConfig.filteringOptions;
  }

  @override
  void initState() {
    super.initState();

    controller = ScrollController()..addListener(_scrollListener);
    controller2 = TextEditingController();

    RescueGroupApi = AppConfig.rescueGroupsApiKey;

    () async {
      // Load saved filters from SharedPreferences first
      await _loadFiltersFromPrefs();
      // Load saved cat type so status bar shows it (e.g. "🎯 Lap Legend")
      await _loadSavedCatTypeForStatusBar();

      try {
        String user = await server.getUser();
        favorites = await server.getFavorites(user);
        // Load zip from canonical store (same as main/search/shelters)
        await server.loadZipCodeFromPrefs();

        setState(() {
          main.favoritesSelected = false;
          widget.setFav?.call(false);

          globals.listOfFavorites = favorites;
          userID = user;
          RescueGroupApi = AppConfig.rescueGroupsApiKey;
          if (server.zip.isNotEmpty && server.zip != "?") {
            getPets();
          } else {
            count = "?";
          }
        });
      } catch (e) {
        // Fallback when Firestore/auth fails
        setState(() {
          userID = "demo-user";
          favorites = [];
          RescueGroupApi = AppConfig.rescueGroupsApiKey;
          if (server.zip.isNotEmpty && server.zip != "?") {
            getPets();
          } else {
            count = "?";
          }
        });
        if (mounted && isNetworkError(e)) showNetworkErrorSnackBar(context);
      }
    }();
  }

  /// Build filterProcessing string so that synonym filters (operation "contains", same fieldName)
  /// are combined with OR; other filters and groups are combined with AND.
  /// Returns null if 0 or 1 filter (no processing needed).
  String? _buildFilterProcessingWithSynonymsAsOr(List<Filters> validFilters) {
    if (validFilters.length <= 1) return null;
    final segments = <String>[];
    int i = 0;
    while (i < validFilters.length) {
      final f = validFilters[i];
      if (f.operation == 'contains') {
        final fieldName = f.fieldName;
        final orIndices = <int>[];
        while (i < validFilters.length &&
            validFilters[i].fieldName == fieldName &&
            validFilters[i].operation == 'contains') {
          orIndices.add(i + 1); // 1-based index
          i++;
        }
        if (orIndices.length > 1) {
          segments.add('(${orIndices.join(' OR ')})');
        } else {
          segments.add('${orIndices[0]}');
        }
      } else {
        segments.add('${i + 1}');
        i++;
      }
    }
    return segments.join(' AND ');
  }

  /// Apply loaded Filters (from prefs) to the global filterOption list so the status chip bar shows correctly on first display.
  void _applyLoadedFiltersToFilterOptions() {
    final options = searchConfig.persistentFilteringOptions.isNotEmpty
        ? searchConfig.persistentFilteringOptions
        : searchConfig.filteringOptions;
    for (final f in filters) {
      if (f.fieldName == 'species.singular') continue;
      try {
        searchConfig.filterOption? opt;
        for (final o in options) {
          if (o.fieldName == f.fieldName) { opt = o; break; }
        }
        if (opt == null) continue;
        final c = f.criteria;
        if (opt.list) {
          if (c is List && c.isNotEmpty) {
            opt.choosenListValues = c.map((e) {
              if (e is int) return e;
              return int.tryParse(e.toString()) ?? 0;
            }).toList();
          }
        } else {
          if (c is List && c.isNotEmpty) {
            opt.choosenValue = c.first;
          } else if (c != null) {
            opt.choosenValue = c;
          }
        }
      } catch (_) {}
    }
  }

  static const String _kLastSearchCatTypeKey = 'lastSearchCatType';
  static const String _kChosenCatTypeSourceKey = 'chosen_cat_type_source';
  static const String _kTopFitButtonHintSeenKey = 'top_fit_button_hint_seen';

  /// Load saved cat type and source from SharedPreferences. First launch: set to top type (first archetype), save source 'fit', show message.
  Future<void> _loadSavedCatTypeForStatusBar() async {
    try {
      final prefs = await _prefs;
      final saved = prefs.getString(_kLastSearchCatTypeKey);
      final source = prefs.getString(_kChosenCatTypeSourceKey);

      if (saved == null || saved.isEmpty || saved == 'none') {
        final topName = catType.isNotEmpty ? catType.first.name : null;
        if (topName != null) {
          server.setSelectedPersonalityCatTypeName(topName);
          await prefs.setString(_kLastSearchCatTypeKey, topName);
          await prefs.setString(_kChosenCatTypeSourceKey, 'fit');
          if (mounted) {
            setState(() => _chosenCatTypeSource = 'fit');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Use the Fit screen to personalize your preferred cat type for better sorting.'),
                duration: Duration(seconds: 3),
                backgroundColor: Color(0xFF6B4E9D),
              ),
            );
          }
        } else {
          server.setSelectedPersonalityCatTypeName(null);
          if (mounted) setState(() => _chosenCatTypeSource = null);
        }
        return;
      }
      if (saved == 'my_type') {
        server.setSelectedPersonalityCatTypeName('Custom');
      } else {
        server.setSelectedPersonalityCatTypeName(saved);
      }
      if (mounted) setState(() => _chosenCatTypeSource = source ?? 'fit');
    } catch (_) {}
  }

  /// Load filters and filterProcessing from SharedPreferences
  Future<void> _loadFiltersFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filtersJsonString = prefs.getString('lastSearchFiltersList');
      final savedFilterProcessing = prefs.getString('lastSearchFilterProcessing');

      if (filtersJsonString != null && filtersJsonString.isNotEmpty) {
        final filtersJson = jsonDecode(filtersJsonString) as List<dynamic>;
        filters = filtersJson.map((f) => Filters(
          fieldName: f['fieldName'] as String,
          operation: f['operation'] as String,
          criteria: f['criteria'],
        )).toList();

        if (savedFilterProcessing != null && savedFilterProcessing.isNotEmpty) {
          filterprocessing = savedFilterProcessing;
        } else {
          filterprocessing = null;
        }

        // Create backup copy
        filters_backup = filters.map((f) => Filters(
          fieldName: f.fieldName,
          operation: f.operation,
          criteria: f.criteria,
        )).toList();

        // Sync to filterOption list so status chip bar shows chosen options on first display
        _applyLoadedFiltersToFilterOptions();

        print('✅ Loaded ${filters.length} filters and filterProcessing from SharedPreferences');
      } else {
        // Default filter: species = cat (if no saved filters)
        filters.add(Filters(
          fieldName: "species.singular",
          operation: "equal",
          criteria: ["cat"],
        ));
        filters_backup.add(Filters(
          fieldName: "species.singular",
          operation: "equal",
          criteria: ["cat"],
        ));
        print('No saved filters found, using default filter');
      }
    } catch (e) {
      print('Error loading filters from SharedPreferences: $e');
      // Default filter: species = cat (on error)
      filters.add(Filters(
        fieldName: "species.singular",
        operation: "equal",
        criteria: ["cat"],
      ));
      filters_backup.add(Filters(
        fieldName: "species.singular",
        operation: "equal",
        criteria: ["cat"],
      ));
    }
  }

  /// Opens the sort bottom sheet (Nearest / Recently updated). Called from title bar.
  void showSortSheet() {
    _showSortSheet();
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2B1E3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sort by',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'New results load at the bottom until you sort again.',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Nearest', style: TextStyle(color: Colors.white)),
                leading: Radio<String>(
                  value: 'animals.distance',
                  groupValue: globals.sortMethod,
                  onChanged: (v) => _applySortAndClose(ctx, 'animals.distance'),
                  activeColor: AppTheme.goldBase,
                ),
                onTap: () => _applySortAndClose(ctx, 'animals.distance'),
              ),
              ListTile(
                title: const Text('Recently updated', style: TextStyle(color: Colors.white)),
                leading: Radio<String>(
                  value: '-animals.updatedDate',
                  groupValue: globals.sortMethod,
                  onChanged: (v) => _applySortAndClose(ctx, '-animals.updatedDate'),
                  activeColor: AppTheme.goldBase,
                ),
                onTap: () => _applySortAndClose(ctx, '-animals.updatedDate'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.help_outline, size: 20, color: Colors.white70),
                    label: const Text('Help', style: TextStyle(color: Colors.white70)),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showSortHelpDialog();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applySortAndClose(BuildContext sheetContext, String newSort) {
    Navigator.of(sheetContext).pop();
    if (globals.sortMethod == newSort) {
      if (controller.hasClients) {
        controller.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
      return;
    }
    globals.sortMethod = newSort;
    setState(() {
      for (final t in tiles) {
        t.batchOrder = 1;
      }
      _nextBatchId = 2;
    });
    if (controller.hasClients) {
      controller.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _showSortHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How sorting works'),
        content: const SingleChildScrollView(
          child: Text(
            'Results load in batches. New batches are added at the bottom so the list stays stable while you browse.\n\n'
            'When you tap Sort and choose Nearest or Recently updated, the list is reordered and all current results are treated as one batch. New results you load after that will again appear at the bottom until you sort again.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Returns band index 0..3 for distance (null/unknown -> 3 for 50+).
  static int _bandIndexForDistance(double? miles) {
    final d = miles ?? 999.0;
    for (int i = 0; i < _kDistanceBands.length; i++) {
      if (d < _kDistanceBands[i].maxMiles) return i;
    }
    return _kDistanceBands.length - 1;
  }

  /// Days ago from now (0 = today). Returns null if updatedDate is unparseable.
  /// Uses local date for both "today" and updated date so timezone is consistent.
  static int? _daysAgoFromUpdatedDate(String? updatedDate) {
    if (updatedDate == null || updatedDate.isEmpty) return null;
    final dt = DateTime.tryParse(updatedDate);
    if (dt == null) return null;
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updatedDay = DateTime(local.year, local.month, local.day);
    return today.difference(updatedDay).inDays;
  }

  /// Returns time band index 0..4 (0 = Today, 4 = Over a year ago). Null/unknown -> 4.
  /// Future dates (e.g. clock skew) are treated as Today so they appear at top.
  static int _timeBandIndexForTile(PetTileData tile) {
    final days = _daysAgoFromUpdatedDate(tile.updatedDate);
    if (days == null) return _kTimeBands.length - 1;
    if (days < 0) return 0;
    if (days == 0) return 0;
    if (days <= 7) return 1;
    if (days <= 30) return 2;
    if (days <= 365) return 3;
    return 4;
  }

  /// Builds sections for display: sort by batch → distance/date → fit → archetype → seq, then group by distance or time.
  List<_DistanceSection> _getDisplaySections() {
    if (tiles.isEmpty) return [];
    final byDistance = globals.sortMethod == 'animals.distance';
    final byDate = globals.sortMethod == '-animals.updatedDate';
    final typeFit = _getTypeNameToFitScore();
    final sorted = CatResultRanking.sortByBatchDistanceFitTypeSequence(
      tiles,
      typeNameToFitScore: typeFit.isEmpty ? null : typeFit,
      useDateOrder: byDate,
      useDistanceOrder: byDistance,
      chosenTypeName: server.selectedPersonalityCatTypeName,
    );

    if (byDate) {
      final sections = <_DistanceSection>[];
      List<PetTileData> current = [];
      int currentBand = -1;
      void flush() {
        if (current.isEmpty) return;
        sections.add(_DistanceSection(_kTimeBands[currentBand].label, List.from(current)));
        current = [];
      }
      for (final t in sorted) {
        final band = _timeBandIndexForTile(t);
        if (band != currentBand) {
          flush();
          currentBand = band;
        }
        current.add(t);
      }
      flush();
      return sections;
    }

    // Distance grouping (default): group sorted list by distance bands.
    final sections = <_DistanceSection>[];
    List<PetTileData> current = [];
    int currentBand = -1;
    void flush() {
      if (current.isEmpty) return;
      sections.add(_DistanceSection(_kDistanceBands[currentBand].label, List.from(current)));
      current = [];
    }
    for (final t in sorted) {
      final band = _bandIndexForDistance(t.distanceMiles);
      if (band != currentBand) {
        flush();
        currentBand = band;
      }
      current.add(t);
    }
    flush();
    return sections;
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: AppTheme.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGridContent() {
    final sections = _getDisplaySections();
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }
    const padding = EdgeInsets.symmetric(vertical: 20, horizontal: 12);
    const crossAxisCount = 2;
    const mainAxisSpacing = 14.0;
    const crossAxisSpacing = 12.0;

    final showLoadingAtBottom = !main.favoritesSelected && _isLoadingPets &&
        (_totalFromAPI < 0 || tiles.length < _totalFromAPI);

    // Single section: stable-ranked list with visible-region freeze (cards on screen do not reshuffle).
    if (sections.length == 1 && sections[0].label == null) {
      final list = sections[0].tiles;
      final itemCount = list.length + (showLoadingAtBottom ? 1 : 0);
      return MasonryGridView.count(
        controller: controller,
        itemCount: itemCount,
        padding: padding,
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        itemBuilder: (context, index) {
          if (index >= list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppTheme.goldBase)),
            );
          }
          final tile = list[index];
          return VisibilityDetector(
            key: Key('rank_${tile.id ?? index}'),
            onVisibilityChanged: (_) {},
            child: GestureDetector(
              onTap: () => _navigateAndDisplaySelection(context, tile),
              child: GoldPetCard(
                tile: tile,
                favorites: favorites,
                onVideoBadgeFirstSeen: _onVideoBadgeFirstSeen,
                showVideoGlow: _videoBadgeGlowIds.contains(tile.id ?? ''),
              ),
            ),
          );
        },
      );
    }

    // Multiple sections: only ONE sticky header at top (current section label); content is grids only so headers never collect.
    if (_sectionHeights.length != sections.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {
          _sectionHeights = List.filled(sections.length, 0.0);
          _currentStickySectionIndex = 0;
        });
      });
    }
    final safeIndex = _currentStickySectionIndex.clamp(0, sections.length - 1);
    final currentLabel = sections[safeIndex].label ?? '';
    final slivers = <Widget>[
      SliverPersistentHeader(
        pinned: true,
        delegate: _StickySectionHeaderDelegate(currentLabel),
      ),
    ];
    for (int sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      final list = section.tiles;
      slivers.add(
        SliverToBoxAdapter(
          child: _MeasureSectionChild(
            sectionIndex: sectionIndex,
            onHeight: (index, height) {
              if (!mounted) return;
              if (index < 0 || index >= _sectionHeights.length) return;
              if (_sectionHeights[index] == height) return;
              _sectionHeights[index] = height;
              if (_sectionHeightsUpdateScheduled) return;
              _sectionHeightsUpdateScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _sectionHeightsUpdateScheduled = false;
                if (!mounted) return;
                setState(() {});
                _updateStickySectionFromScroll();
              });
            },
            child: MasonryGridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              padding: sectionIndex == 0
                  ? padding
                  : const EdgeInsets.fromLTRB(12, 0, 12, 12),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              itemBuilder: (context, index) {
                final tile = list[index];
                return GestureDetector(
                  onTap: () => _navigateAndDisplaySelection(context, tile),
                  child: GoldPetCard(
                    tile: tile,
                    favorites: favorites,
                    onVideoBadgeFirstSeen: _onVideoBadgeFirstSeen,
                    showVideoGlow: _videoBadgeGlowIds.contains(tile.id ?? ''),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    return CustomScrollView(
      controller: controller,
      slivers: [
        ...slivers,
        if (showLoadingAtBottom)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppTheme.goldBase)),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

@override
Widget build(BuildContext context) {
  String status = main.favoritesSelected ? " Favorites: " : " Cats: ";
  final bool awaitingFirstPage = (count == "Processing" || count == "Processing...");
  status += awaitingFirstPage
      ? "Processing..."
      : (tiles.isEmpty ? "0" : count);

  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.purpleGradient,
      ),
      child: Column(
        children: [
          // ZIP BUTTON + CAT COUNT + SORT (when not Favorites)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GoldZipButton(
                        zip: server.zip,
                        onTap: askForZip,
                        onLongPress: _clearZipCode,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.fontSizeM,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Status chip bar: active filters + "+N more" (tapping more opens search).
          // When no filters are active, show a single "Set filters" chip so the bar is always visible.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: StatusChipBar(
              onDarkBackground: true,
              chips: () {
                final selectedCatTypeName = server.selectedPersonalityCatTypeName;
                final String sourceLabel = _chosenCatTypeSource == null
                    ? ''
                    : ' (from ${_chosenCatTypeSource == 'search' ? 'Search' : 'Fit'})';
                final matchStyle = (selectedCatTypeName != null && selectedCatTypeName.trim().isNotEmpty)
                    ? searchConfig.MatchStyleState.preset(selectedCatTypeName.trim() + sourceLabel)
                    : searchConfig.MatchStyleState.notSet;
                final chips = searchConfig.buildStatusChips(
                  filters: filteringOptions,
                  matchStyle: matchStyle,
                  maxChips: 4,
                  onMoreTap: search,
                );
                if (chips.isEmpty) {
                  return [
                    searchConfig.ChipModel(
                      label: '🔍 Set filters',
                      priority: 0,
                      onTap: search,
                    ),
                  ];
                }
                return chips;
              }(),
            ),
          ),
          // MESSAGE UNDER CHIPS: loading text until first page count is set, then no-cats message when done and empty
          if (awaitingFirstPage || (tiles.isEmpty && !_isLoadingPets))
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                awaitingFirstPage
                    ? "Please wait, the cats are loading..."
                    : (server.zip.isEmpty || server.zip == "?")
                        ? "Can't display cats because we don't know your location. Enter ZIP code above."
                        : main.favoritesSelected
                            ? "You have not chosen any favorites yet."
                            : "Sorry I could not find any cat like that. Please broaden your search.",
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontSizeM,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // ------------------------------------------------------------
          // EXPANDED GRID OF PET CARDS (with distance section headers when sorted by distance)
          // ------------------------------------------------------------
          Expanded(
            child: _buildGridContent(),
          ),
        ],
      ),
    ),
  );
}
// ----------------------------------------------------------------------
//     NAVIGATE TO DETAIL + REMOVE UNFAVORITED FROM FAVORITES LIST
// ----------------------------------------------------------------------
Future<void> _navigateAndDisplaySelection(
    BuildContext context, PetTileData tile) async {
  final tileId = tile.id;
  if (tileId == null || tileId.isEmpty) return;
  final countOfFavorites = globals.listOfFavorites.length;

  await Get.to(
    () => petDetail(tileId),
    transition: Transition.circularReveal,
    duration: const Duration(seconds: 1),
  );

  // refresh favorites after returning
  if (userID != null) {
    favorites = await server.getFavorites(userID!);
  }

  setState(() {
    globals.listOfFavorites = favorites;

    // if user unfavorited, remove that tile from grid
    if (main.favoritesSelected &&
        globals.listOfFavorites.length < countOfFavorites) {
      tiles.removeWhere((t) => t.id == tileId);
    }
  });
}

// ----------------------------------------------------------------------
//                         OPEN ZIP CODE INPUT
// ----------------------------------------------------------------------
Future<String?> openDialog() => showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Zip Code"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: "Zip Code"),
          controller: controller2,
          keyboardType: server.getCountryISOCode() == "US"
              ? TextInputType.number
              : TextInputType.text,
          onSubmitted: (_) => Navigator.of(context).pop(controller2.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller2.text),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

// ----------------------------------------------------------------------
//                         GET ZIP CODE
// ----------------------------------------------------------------------
Future<String> _getZip() async {
  await server.loadZipCodeFromPrefs();
  return (server.zip.isNotEmpty && server.zip != "?")
      ? server.zip
      : AppConfig.defaultZipCode;
}

// ----------------------------------------------------------------------
//                    REFRESH ZIP FROM CANONICAL STORE
// ----------------------------------------------------------------------
/// Call when switching to Adopt tab so the zip button shows the current value from prefs.
Future<void> refreshZipFromCanonical() async {
  await server.loadZipCodeFromPrefs();
  if (!mounted) return;
  setState(() {});
}

/// Call when switching to Adopt tab. If the user changed the selected cat type on the Fit tab, requery the adoption list.
void requeryIfSelectedTypeChanged() {
  final current = server.selectedPersonalityCatTypeName?.trim();
  final last = _lastSelectedTypeWhenLoaded?.trim();
  if (current == last) return;
  _lastSelectedTypeWhenLoaded = server.selectedPersonalityCatTypeName;
  if (server.zip.isEmpty || server.zip == '?') return;
  setState(() {
    tiles = [];
    maxPets = -1;
    _totalFromAPI = -1;
    _nextSequence = 0;
    _nextBatchId = 1;
    _videoBadgeSeenIds.clear();
    _videoBadgeGlowIds.clear();
    count = 'Processing';
  });
  getPets();
}

// ----------------------------------------------------------------------
//                         CLEAR ZIP CODE (long-press)
// ----------------------------------------------------------------------
Future<void> _clearZipCode() async {
  await server.clearZipCode();
  await globals.onClearFitOnboarding?.call();
  if (!mounted) return;
  setState(() {
    count = '?';
    tiles = [];
    maxPets = -1;
    _totalFromAPI = -1;
    _nextSequence = 0;
    _nextBatchId = 1;
    _videoBadgeSeenIds.clear();
    _videoBadgeGlowIds.clear();
  });
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('ZIP code and Fit onboarding cleared. Tap the ZIP button to enter a new location.'),
    ),
  );
}

// ----------------------------------------------------------------------
//                         ASK FOR ZIP CODE
// ----------------------------------------------------------------------
Future<void> askForZip() async {
  var zip = await openDialog();
  if (zip == null || zip.isEmpty) {
    // If blank, try to get from adopter's location
    zip = await _getZipFromLocation();
    if (zip.isEmpty) {
      zip = AppConfig.defaultZipCode;
    }
  }
  
  final zipTrimmed = zip.trim();
  
  // Validate zip code (same validation as search screen)
  if (zipTrimmed.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ZIP code cannot be blank. Please enter a valid ZIP code.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  if (zipTrimmed.length < 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ZIP code must be 5 digits.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  if (zipTrimmed.length != 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ZIP code must be exactly 5 digits.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Validate with server (same as search screen)
  try {
    final isValid = await server.isZipCodeValid(zipTrimmed);
    
    if (isValid == true) {
      // If zip changed, clear chosen shelter so results match the new area
      final currentZip = (server.zip ?? '').trim();
      if (zipTrimmed != currentZip) {
        if (mounted) {
          setState(() {
            filters = filters.where((f) => f.fieldName != 'orgs.id').toList();
            filters_backup = filters_backup.where((f) => f.fieldName != 'orgs.id').toList();
            filterprocessing = null;
          });
        }
      }
      // Valid - save to canonical store
      await server.setZipCode(zipTrimmed);
      if (!mounted) return;
      setState(() {});

      // Reload pets with new zip
      setState(() {
        tiles = [];
        maxPets = -1;
        _nextSequence = 0;
        _videoBadgeSeenIds.clear();
        _videoBadgeGlowIds.clear();
        count = 'Processing';
      });
      getPets();
    } else if (isValid == null) {
      // Network error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Network error. Please check your internet connection and try again.',
                  maxLines: 2,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      // Invalid zip code
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('ZIP code "$zipTrimmed" is not valid. Please enter a valid US ZIP code.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error validating ZIP code: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// ----------------------------------------------------------------------
//                         GET ZIP CODE FROM LOCATION
// ----------------------------------------------------------------------
Future<String> _getZipFromLocation() async {
  try {
    // Get current location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return AppConfig.defaultZipCode;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return AppConfig.defaultZipCode;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    // Get placemark from coordinates
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty &&
        placemarks.first.postalCode != null) {
      final zip = placemarks.first.postalCode!;
      await server.setZipCode(zip);
      return zip;
    }
  } catch (e) {
    print('Error getting zip code from location: $e');
  }
  return AppConfig.defaultZipCode;
}

// ----------------------------------------------------------------------
//                         BUILD CATEGORIES
// ----------------------------------------------------------------------
Map<searchConfig.CatClassification, List<searchConfig.filterOption>> _buildCategories() {
  Map<searchConfig.CatClassification, List<searchConfig.filterOption>> categories = {};
  for (var classification in searchConfig.CatClassification.values) {
    categories[classification] = filteringOptions
        .where((filter) => filter.classification == classification)
        .toList();
  }
  return categories;
}

// ----------------------------------------------------------------------
//                             SEARCH SCREEN
// ----------------------------------------------------------------------
void search() async {
  final orgId = globals.lastShelterFromSheltersTabOrgId;
  final orgName = globals.lastShelterFromSheltersTabName;
  if (orgId != null && orgId.isNotEmpty) {
    globals.lastShelterFromSheltersTabOrgId = null;
    globals.lastShelterFromSheltersTabName = null;
  }
  var result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SearchScreen(
        categories: _buildCategories(),
        filteringOptions: filteringOptions,
        userID: userID ?? "demo-user",
        initialShelterOrgIds: (orgId != null && orgId.isNotEmpty) ? [orgId] : null,
        initialShelterNames: (orgName != null && orgName.isNotEmpty) ? [orgName] : null,
      ),
    ),
  );

  if (result != null) {
    setState(() {
      applySearchResult(result);
    });
  }
}

  /// Returns a route for SearchScreen with the given shelter pre-selected. Used when opening from Shelters tab "Select" so the push can be done from HomeScreen's context and the result received reliably.
  MaterialPageRoute routeForSearchWithShelter(String orgId, String orgName) {
    return MaterialPageRoute(
      builder: (context) => SearchScreen(
        categories: _buildCategories(),
        filteringOptions: filteringOptions,
        userID: userID ?? "demo-user",
        initialShelterOrgIds: [orgId],
        initialShelterNames: [orgName],
      ),
    );
  }

  /// Open SearchScreen with a single shelter pre-selected (e.g. from Shelters tab "Select").
  void openSearchWithShelter(String orgId, String orgName) async {
    var result = await Navigator.push(
      context,
      routeForSearchWithShelter(orgId, orgName),
    );
    if (result != null && mounted) {
      setState(() {
        applySearchResult(result);
      });
    }
  }

  /// Apply personality (Fit tab sliders) to current filter options and run search. Called when user taps Adopt from Fit and confirms "Search by your cat personality?".
  Future<void> applyPersonalityAndSearch() async {
    final top = CatTypeFilterMapping.getTopPersonalityCatType(server);
    if (top == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Set your cat type on the Fit tab first (e.g. ${catType.take(3).map((t) => t.name).join(', ')}).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    CatTypeFilterMapping.applyCatTypeToFilterOptions(top, filteringOptions, server: server);
    server.setSelectedPersonalityCatTypeName(top.name);
    await _saveCatTypeToPrefsForSort(top.name, 'fit');
    final result = SearchScreenState.generateFiltersFromOptions(filteringOptions);
    if (mounted) setState(() => applySearchResult(result));
  }

  /// Call when ZIP was just set elsewhere (e.g. main's _ensureZipCode). Loads pets if ZIP is now valid so the list populates without needing to open Search.
  void reloadPetsIfZipAvailable() {
    if (!mounted) return;
    final server = globals.FelineFinderServer.instance;
    if (server.zip.isEmpty || server.zip == '?') return;
    setState(() {
      count = 'Processing'; // must match build()'s awaitingFirstPage check
      tiles = [];
      maxPets = -1;
      _totalFromAPI = -1;
      _nextSequence = 0;
      _nextBatchId = 1;
      _videoBadgeSeenIds.clear();
      _videoBadgeGlowIds.clear();
    });
    getPets();
  }

  /// Apply a search result (FilterResult or List<Filters>) and run getPets. Used when returning from SearchScreen or when switching from Shelters + Find Cats.
  void applySearchResult(dynamic result) {
    if (result is FilterResult) {
      filters = result.filters;
      filterprocessing = result.filterprocessing;
      if (result.selectedCatTypeName != null) {
        server.setSelectedPersonalityCatTypeName(result.selectedCatTypeName);
        _saveCatTypeToPrefsForSort(result.selectedCatTypeName!, 'search');
      }
      print("=== AdoptionGrid: applied FilterResult, ${filters.length} filters, calling getPets ===");
    } else if (result is List<Filters>) {
      filters = result;
      filterprocessing = null;
      print("=== AdoptionGrid: applied List<Filters>, ${filters.length} filters, calling getPets ===");
    } else {
      print("=== AdoptionGrid: applySearchResult skipped - result type is ${result.runtimeType} (not FilterResult or List<Filters>) ===");
      return;
    }
    filters_backup = filters;
    tiles = [];
    maxPets = -1;
    _totalFromAPI = -1;
    _nextSequence = 0;
    _nextBatchId = 1;
    _videoBadgeSeenIds.clear();
    _videoBadgeGlowIds.clear();
    main.favoritesSelected = false;
    widget.setFav?.call(false);
    getPets();
  }

  /// Persist selected cat type name and source ('fit' or 'search') so list shows "(from Fit)" / "(from Search)".
  Future<void> _saveCatTypeToPrefsForSort(String name, String source) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_kLastSearchCatTypeKey, name);
      await prefs.setString(_kChosenCatTypeSourceKey, source);
      if (mounted) setState(() => _chosenCatTypeSource = source);
    } catch (_) {}
  }

  /// Set the chosen cat type for the adoption list from the Fit screen (last-changed type from Fit).
  Future<void> setChosenCatTypeFromFit(String name) async {
    server.setSelectedPersonalityCatTypeName(name);
    await _saveCatTypeToPrefsForSort(name, 'fit');
    if (mounted) setState(() {});
  }

  /// Show SnackBar hint to tap 🎯 to use top fit, until user has tapped the target button (persisted).
  Future<void> maybeShowTopFitHint() async {
    try {
      final prefs = await _prefs;
      if (prefs.getBool(_kTopFitButtonHintSeenKey) == true) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap 🎯 to sort by your top Fit match.'),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF6B4E9D),
        ),
      );
    } catch (_) {}
  }

  /// Called when user taps the 🎯 button: set selected cat type to top fit, save to prefs, stop showing hint.
  Future<void> applyTopFitFromButton() async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(_kTopFitButtonHintSeenKey, true);
    } catch (_) {}
    final top = CatTypeFilterMapping.getTopPersonalityCatType(server);
    if (top == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set your cat type on the Fit tab first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    await setChosenCatTypeFromFit(top.name);
    requeryIfSelectedTypeChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set the selected cat type to ${top.name}.'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF6B4E9D),
        ),
      );
    }
  }

// ----------------------------------------------------------------------
//                           FAVORITES HANDLER
// ----------------------------------------------------------------------
void setFavorites(bool favorited) {
  setState(() {
    main.favoritesSelected = favorited;

    tiles = [];
    maxPets = -1;
    _totalFromAPI = -1;
    _nextSequence = 0;
    _nextBatchId = 1;
    _videoBadgeSeenIds.clear();
    _videoBadgeGlowIds.clear();
    count = 'Processing';

    getPets();
  });
}

// ----------------------------------------------------------------------
//                    VIDEO BADGE FIRST-SEEN GLOW
// ----------------------------------------------------------------------
void _onVideoBadgeFirstSeen(String id) {
  if (id.isEmpty || _videoBadgeSeenIds.contains(id)) return;
  _videoBadgeSeenIds.add(id);
  _videoBadgeGlowIds.add(id);
  if (mounted) setState(() {});
  Future.delayed(const Duration(seconds: 2), () {
    if (mounted) setState(() => _videoBadgeGlowIds.remove(id));
  });
}

// ----------------------------------------------------------------------
//                       SCROLL LISTENER FOR INFINITE LOAD
// ----------------------------------------------------------------------
void _scrollListener() {
  if (!mounted || !controller.hasClients) return;
  if (controller.position.extentAfter < 500) {
    final isFavorites = main.favoritesSelected;
    final hasMore = isFavorites ? false : (_totalFromAPI < 0 || tiles.length < _totalFromAPI);
    if (!_isLoadingPets && hasMore) {
      setState(() { getPets(); });
    }
  }
  _updateStickySectionFromScroll();
}

void _updateStickySectionFromScroll() {
  if (!mounted) return;
  if (!controller.hasClients) return;
  if (_sectionHeights.isEmpty || _sectionHeights.every((h) => h == 0)) return;
  const headerHeight = _StickySectionHeaderDelegate.headerHeight;
  final starts = <double>[0.0];
  for (var i = 0; i < _sectionHeights.length; i++) {
    starts.add(starts.last + (i == 0 ? headerHeight : 0) + _sectionHeights[i]);
  }
  if (starts.length < 2) return;
  final offset = controller.offset;
  var index = 0;
  for (var i = 0; i < starts.length - 1; i++) {
    if (offset >= starts[i]) index = i;
  }
  if (index != _currentStickySectionIndex && mounted) {
    setState(() => _currentStickySectionIndex = index);
  }
}

// ----------------------------------------------------------------------
//                    PERSONALITY FIT (HIVE / FIRESTORE / CALLABLE)
// ----------------------------------------------------------------------
// High-volume Gemini path: one getFitForAnimal per tile without cached fit.
// Protected by Hive → Firestore → callable: same animal never hits Gemini twice.
static const int _fitBatchSize = 10;

Future<void> _resolvePersonalityFitForTiles() async {
  if (tiles.isEmpty || !mounted) return;
  // When a cat type is selected (e.g. Puzzle Pro), score by type-to-type match so Toy Addict ranks above Lap Legend.
  final selectedName = server.selectedPersonalityCatTypeName;
  CatType? selectedType;
  Map<String, int> userProfile;
  if (selectedName != null &&
      selectedName.trim().isNotEmpty &&
      selectedName != 'Custom') {
    final nameLower = selectedName.trim().toLowerCase();
    for (final ct in catType) {
      if (ct.name.toLowerCase() == nameLower) {
        selectedType = ct;
        break;
      }
    }
    userProfile = selectedType != null
        ? CatTypeFilterMapping.getTraitProfileForCatType(selectedType!)
        : CatFitService.userTraitProfileFromFilterOptions(filteringOptions);
  } else {
    userProfile = CatFitService.userTraitProfileFromFilterOptions(filteringOptions);
  }
  // So pet detail bar chart can show "My Type" from current search/fit filters
  server.setLastSearchUserTraitProfile(userProfile);
  final selectedTypeProfile = selectedType != null ? userProfile : null;
  final list = List<PetTileData>.from(tiles);
  for (var i = 0; i < list.length; i += _fitBatchSize) {
    if (!mounted) return;
    final batch = list.skip(i).take(_fitBatchSize).toList();
    await _resolvePersonalityFitForBatch(batch, userProfile, selectedTypeProfile);
    if (mounted) setState(() {});
  }
}

/// Scores a single batch of tiles (no setState). Used so we can append only after scoring.
Future<void> _resolvePersonalityFitForBatch(
  List<PetTileData> batch,
  Map<String, int> userProfile,
  Map<String, int>? selectedTypeProfile,
) async {
  for (var i = 0; i < batch.length; i += _fitBatchSize) {
    if (!mounted) return;
    final chunk = batch.skip(i).take(_fitBatchSize).toList();
    await Future.wait(chunk.map((tile) async {
      if (tile.id == null || tile.id!.isEmpty) return;
      if (tile.personalityFitTraits != null && tile.personalityFitTraits!.isNotEmpty) return;
      try {
        final record = await CatFitService.instance.getFitForAnimal(
          tile.id!,
          description: tile.descriptionText,
          name: tile.name,
          shelterName: tile.organizationName,
          updatedDate: tile.updatedDate,
        );
        if (record != null && mounted) {
          tile.personalityFitTraits = record.traitScores;
          tile.suggestedCatTypeName = record.suggestedCatTypeName != null &&
                  record.suggestedCatTypeName!.trim().isNotEmpty
              ? record.suggestedCatTypeName
              : null;
          if (selectedTypeProfile != null &&
              record.suggestedCatTypeName != null &&
              record.suggestedCatTypeName!.trim().isNotEmpty) {
            CatType? suggestedType;
            final suggestedLower = record.suggestedCatTypeName!.trim().toLowerCase();
            for (final ct in catType) {
              if (ct.name.toLowerCase() == suggestedLower) {
                suggestedType = ct;
                break;
              }
            }
            if (suggestedType != null) {
              final suggestedProfile = CatTypeFilterMapping.getTraitProfileForCatType(suggestedType);
              tile.personalityFitScore = CatFitService.computeFitScore(suggestedProfile, selectedTypeProfile);
            } else {
              tile.personalityFitScore = CatFitService.computeFitScore(record.traitScores, userProfile);
            }
          } else {
            tile.personalityFitScore = CatFitService.computeFitScore(record.traitScores, userProfile);
          }
        }
      } catch (e) {
        print('Personality fit for ${tile.id}: $e');
      }
    }));
  }
}

// ----------------------------------------------------------------------
//                         RESCUE GROUPS API CALL
// ----------------------------------------------------------------------
void getPets() async {
  if (_isLoadingPets) return;
  _isLoadingPets = true;
  final isFavorites = main.favoritesSelected;
  final nextPage = isFavorites ? 1 : ((tiles.length / tilesPerLoad).floor() + 1);
  if (!isFavorites && _totalFromAPI > 0 && tiles.length >= _totalFromAPI) {
    _isLoadingPets = false;
    return;
  }
  String sortMethod = globals.sortMethod;

  String baseUrl =
      "https://api.rescuegroups.org/v5/public/animals/search/available";
  String url =
      "$baseUrl?fields[animals]=distance,id,ageGroup,sex,sizeGroup,name,breedPrimary,updatedDate,status,descriptionText"
      "&fields[orgs]=id,name,citystate"
      "&include=orgs,pictures,locations,statuses,videos"
      "&sort=$sortMethod&limit=${tilesPerLoad}&page=$nextPage";

  if (isFavorites) {
    filters = [
      Filters(
        fieldName: "animals.id",
        operation: "equal",
        criteria: globals.listOfFavorites,
      ),
    ];
    filterprocessing = null;
  } else {
    if (filters.isEmpty ||
        (filters.length == 1 &&
            filters[0].fieldName == "species.singular")) {
      filters = [
        Filters(
          fieldName: "species.singular",
          operation: "equal",
          criteria: ["cat"],
        ),
      ];
      filters_backup = filters;
    }
  }

  // Filter out any invalid filters before sending to API
  List<Filters> validFilters = filters
      .where((f) =>
          f.fieldName.isNotEmpty &&
          f.operation.isNotEmpty &&
          f.criteria != null)
      .toList();

  // Validate zip code before sending to API (and before filtering orgs by zip)
  String zipCode = server.zip;
  if (zipCode.isEmpty || zipCode == "?" || zipCode.length != 5) {
    zipCode = AppConfig.defaultZipCode;
    print('⚠️ Invalid zip code "$server.zip", using default: $zipCode');
  } else {
    zipCode = zipCode.trim();
    if (zipCode.length > 5) zipCode = zipCode.substring(0, 5);
  }

  // If a shelter filter is set, keep only org IDs that are within the global zip's radius
  final orgFilterIndex = validFilters.indexWhere((f) => f.fieldName == 'orgs.id');
  if (orgFilterIndex >= 0 && zipCode.length >= 5) {
    dynamic rawCriteria = validFilters[orgFilterIndex].criteria;
    List<String> orgIds = [];
    if (rawCriteria is List) {
      for (final e in rawCriteria) {
        final id = e?.toString().trim();
        if (id != null && id.isNotEmpty) orgIds.add(id);
      }
    } else if (rawCriteria != null) {
      final id = rawCriteria.toString().trim();
      if (id.isNotEmpty) orgIds.add(id);
    }
    if (orgIds.isNotEmpty) {
      try {
        final nearOrgs = await searchOrganizationsByDistanceSingle(
          postalcode: zipCode,
          miles: globals.distance,
        );
        final nearOrgIds = nearOrgs.map((r) => r.orgId).toSet();
        final kept = orgIds.where((id) => nearOrgIds.contains(id)).toList();
        if (kept.length < orgIds.length) {
          if (kept.isEmpty) {
            validFilters = List<Filters>.from(validFilters)..removeAt(orgFilterIndex);
            if (mounted) {
              setState(() {
                filters = filters.where((f) => f.fieldName != 'orgs.id').toList();
                filters_backup = List<Filters>.from(filters);
              });
            }
          } else {
            final newOrgFilter = Filters(
              fieldName: 'orgs.id',
              operation: validFilters[orgFilterIndex].operation,
              criteria: kept,
            );
            validFilters = List<Filters>.from(validFilters)..[orgFilterIndex] = newOrgFilter;
            if (mounted) {
              setState(() {
                filters = [
                  ...filters.where((f) => f.fieldName != 'orgs.id'),
                  newOrgFilter,
                ];
                filters_backup = List<Filters>.from(filters);
              });
            }
          }
        }
      } catch (e) {
        print('Org-by-distance check failed (keeping shelter filter): $e');
      }
    }
  }

  // RescueGroups "contains" expects criteria as a string; normalize single-element list to string
  List<Map> filtersJson = validFilters
      .map((f) {
        dynamic criteria = f.criteria;
        if (f.operation == 'contains' &&
            criteria is List &&
            criteria.length == 1) {
          criteria = criteria.first;
        }
        return {
          "fieldName": f.fieldName,
          "operation": f.operation,
          "criteria": criteria,
        };
      })
      .toList();

  print('📋 Prepared ${filtersJson.length} filters for API');
  for (var filter in filtersJson) {
    print('  Filter: ${filter['fieldName']} ${filter['operation']} ${filter['criteria']}');
  }

  // Use saved filterProcessing, or build one so synonym "contains" filters are OR'd (never all AND)
  String? effectiveFilterProcessing = (filterprocessing != null && filterprocessing!.isNotEmpty)
      ? filterprocessing
      : _buildFilterProcessingWithSynonymsAsOr(validFilters);
  if (effectiveFilterProcessing != null && (filterprocessing == null || filterprocessing!.isEmpty)) {
    print('📋 Reconstructed filterProcessing (synonyms as OR): $effectiveFilterProcessing');
  }

  // Build request body directly so filterProcessing and criteria are preserved (no round-trip loss)
  final Map<String, dynamic> requestData = {
    "filterRadius": {
      "miles": globals.distance,
      "postalcode": zipCode,
    },
    "filters": filtersJson,
  };
  if (effectiveFilterProcessing != null && effectiveFilterProcessing.isNotEmpty) {
    requestData["filterProcessing"] = effectiveFilterProcessing;
  }
  final Map<String, dynamic> envelope = {"data": requestData};

  print('📤 Sending request with zip code: $zipCode, filters: ${filtersJson.length}${effectiveFilterProcessing != null ? ", filterProcessing: $effectiveFilterProcessing" : ""}');

  final requestBody = json.encode(envelope);

  // Pretty-print the cats-for-adoption rescue groups query JSON to terminal
  final prettyJson = const JsonEncoder.withIndent('  ').convert(envelope);
  print('🐱 Cats for adoption rescue groups query (pretty JSON):\n$prettyJson');

  // Debug: Request structure check
  print('📦 Request structure check:');
  print('  - FilterRadius: miles=${requestData["filterRadius"]?["miles"]}, postalcode=${requestData["filterRadius"]?["postalcode"]}');
  print('  - Filters count: ${filtersJson.length}');
  print('  - filterProcessing in body: ${requestData["filterProcessing"] != null ? "yes (${requestData["filterProcessing"]})" : "no"}');
  for (var filter in filtersJson) {
    print('  - Filter: ${filter["fieldName"]} ${filter["operation"]} ${filter["criteria"]}');
  }

  final encodedUrl = url.replaceAll('[', '%5B').replaceAll(']', '%5D');

  print('🔗 Find animals search URL: $encodedUrl');

  try {
  // RescueGroups API requires application/vnd.api+json; using application/json can cause filters to be ignored
  var response = await http.post(
    Uri.parse(encodedUrl),
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Authorization': "$RescueGroupApi",
    },
    body: requestBody,
  );

  if (response.statusCode != 200) {
    print('❌ API Error: Status ${response.statusCode}');
    print('Response body: ${response.body}');
    print('Request zip code: $zipCode');
    print('Request filters: ${filtersJson.length}');
    
    // Show user-friendly error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading pets. Please try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    throw Exception("Failed to load pets: ${response.body}");
  }

  if (response.body.isEmpty) {
    print('🔗 Animals search: request succeeded (200) but response body is empty');
    _isLoadingPets = false;
    if (mounted) setState(() {
      tiles = [];
      maxPets = 0;
      count = "No Matches";
      _totalFromAPI = -1;
      _nextSequence = 0;
      _nextBatchId = 1;
      _videoBadgeSeenIds.clear();
      _videoBadgeGlowIds.clear();
    });
    return;
  }

  try {
    var jsonMap = jsonDecode(response.body);

    Meta meta = Meta.fromJson(jsonMap["meta"] ?? {});
    print('🔗 Animals search: request succeeded (200). meta.count=${meta.count}, countReturned=${jsonMap["meta"]?["countReturned"] ?? "n/a"}');
    pet petDecoded;

    if (meta.count == 0) {
      print('🔗 Animals search: API returned 0 matches (filters/location may exclude all animals)');
      petDecoded = pet(meta: meta, data: [], included: []);
    } else {
      petDecoded = pet.fromJson(jsonMap);
    }

    // Always set total count and update UI for first page so header and loading message update even if data/included are null
    final totalCount = meta.count ?? petDecoded.meta?.count ?? 0;
    if (nextPage == 1) {
      _totalFromAPI = totalCount;
      if (mounted) setState(() {
        maxPets = totalCount;
        count = totalCount == 0 ? "No Matches" : totalCount.toString();
      });
    }

    if (petDecoded.data != null && petDecoded.included != null) {
      final included = petDecoded.included!;

      if (isFavorites) {
        _isLoadingPets = false;
        if (mounted) {
          setState(() {
            for (var petData in petDecoded.data!) {
              try {
                final tile = PetTileData(petData, included);
                tile.sequenceNumber = _nextSequence++;
                tile.batchOrder = 1;
                tile.suggestedCatTypeName =
                    DescriptionCatTypeScorer.getTopCatTypeName(tile.descriptionText);
                tiles.add(tile);
              } catch (e) {
                print("Skip pet ${petData.id}: $e");
              }
            }
            _lastSelectedTypeWhenLoaded = server.selectedPersonalityCatTypeName;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _resolvePersonalityFitForTiles();
          });
        }
      } else {
        final newTiles = <PetTileData>[];
        for (var petData in petDecoded.data!) {
          try {
            final tile = PetTileData(petData, included);
            tile.sequenceNumber = _nextSequence++;
            tile.batchOrder = _nextBatchId;
            tile.suggestedCatTypeName =
                DescriptionCatTypeScorer.getTopCatTypeName(tile.descriptionText);
            newTiles.add(tile);
          } catch (e) {
            print("Skip pet ${petData.id}: $e");
          }
        }
        if (newTiles.isEmpty) {
          _isLoadingPets = false;
          if (mounted) setState(() {});
          return;
        }
        _nextBatchId++;
        final selectedName = server.selectedPersonalityCatTypeName;
        CatType? selectedType;
        Map<String, int> userProfile;
        if (selectedName != null && selectedName.trim().isNotEmpty && selectedName != 'Custom') {
          final nameLower = selectedName.trim().toLowerCase();
          for (final ct in catType) {
            if (ct.name.toLowerCase() == nameLower) {
              selectedType = ct;
              break;
            }
          }
          userProfile = selectedType != null
              ? CatTypeFilterMapping.getTraitProfileForCatType(selectedType!)
              : CatFitService.userTraitProfileFromFilterOptions(filteringOptions);
        } else {
          userProfile = CatFitService.userTraitProfileFromFilterOptions(filteringOptions);
        }
        server.setLastSearchUserTraitProfile(userProfile);
        final selectedTypeProfile = selectedType != null ? userProfile : null;
        await _resolvePersonalityFitForBatch(newTiles, userProfile, selectedTypeProfile);
        if (mounted) {
          setState(() {
            tiles.addAll(newTiles);
            _lastSelectedTypeWhenLoaded = server.selectedPersonalityCatTypeName;
          });
        }
        _isLoadingPets = false;
      }
    } else {
      _isLoadingPets = false;
    }
  } catch (e) {
    print("🔗 Animals search: request succeeded (200) but JSON parse failed: $e");
    _isLoadingPets = false;
    if (mounted) setState(() {
      tiles = [];
      maxPets = 0;
      _totalFromAPI = -1;
      _nextSequence = 0;
      _nextBatchId = 1;
      count = "?";
      _videoBadgeSeenIds.clear();
      _videoBadgeGlowIds.clear();
    });
  }
  } catch (e) {
    _isLoadingPets = false;
    if (mounted) {
      setState(() {
        if (tiles.isEmpty) {
          count = "No Matches";
        }
      });
      if (isNetworkError(e)) {
        showNetworkErrorSnackBar(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    print('🔗 Animals search failed: $e');
  }
  }

  // ----------------------------------------------------------------------
  //                              DISPOSE
  // ----------------------------------------------------------------------
  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    controller.dispose();
    controller2.dispose();
    super.dispose();
  }
}
