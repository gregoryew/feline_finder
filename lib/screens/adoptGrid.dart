import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../main.dart' as main;
import '../models/rescuegroups_v5.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import '/screens/petDetail.dart';
import '/screens/search.dart';
import '../config.dart';
import '../services/description_cat_type_scorer.dart';
import 'globals.dart' as globals;

// GOLD UI COMPONENTS
import '../widgets/gold/gold_pet_card.dart';
import '../widgets/gold/gold_zip_button.dart';

import '../theme.dart';
import '../models/searchPageConfig.dart' as searchConfig;
import '../widgets/status_chip_bar.dart';

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
  int loadedPets = 0;
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
        // Only use saved zip from prefs; do not overwrite server.zip with default (main may have left it as "?" when unknown)
        final prefs = await _prefs;
        final savedZip = prefs.getString("zipCode");
        if (savedZip != null && savedZip.isNotEmpty) {
          server.zip = savedZip;
        }

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
        // Fallback when Firestore fails
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

  /// Load saved cat type from SharedPreferences and set server.selectedPersonalityCatTypeName
  /// so the status chip bar shows the cat type (e.g. "🎯 Lap Legend") on first display.
  Future<void> _loadSavedCatTypeForStatusBar() async {
    try {
      final prefs = await _prefs;
      final saved = prefs.getString(_kLastSearchCatTypeKey);
      if (saved == null || saved.isEmpty || saved == 'none') {
        server.setSelectedPersonalityCatTypeName(null);
        return;
      }
      if (saved == 'my_type') {
        server.setSelectedPersonalityCatTypeName('Custom');
        return;
      }
      server.setSelectedPersonalityCatTypeName(saved);
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

@override
Widget build(BuildContext context) {
  String status = main.favoritesSelected ? " Favorites: " : " Cats: ";
  status += (count == "Processing")
      ? "Processing"
      : (tiles.isEmpty ? "0" : count);

  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.purpleGradient,
      ),
      child: Column(
        children: [
          // ZIP BUTTON + CAT COUNT (centered)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 4),
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
          // Status chip bar: active filters + "+N more" (tapping more opens search).
          // When no filters are active, show a single "Set filters" chip so the bar is always visible.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: StatusChipBar(
              onDarkBackground: true,
              chips: () {
                final selectedCatTypeName = server.selectedPersonalityCatTypeName;
                final matchStyle = (selectedCatTypeName != null && selectedCatTypeName.trim().isNotEmpty)
                    ? searchConfig.MatchStyleState.preset(selectedCatTypeName.trim())
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
          // MESSAGE UNDER ZIP / STATUS
          if (count != "Processing" && tiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                (server.zip.isEmpty || server.zip == "?")
                    ? "Can't display cats because we don't know your location. Enter ZIP code above."
                    : main.favoritesSelected
                        ? "You have not chosen any favorites yet."
                        : "No cats to see. Please adjust your search.",
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontSizeM,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // ------------------------------------------------------------
          // EXPANDED GRID OF PET CARDS
          // ------------------------------------------------------------
          Expanded(
            child: MasonryGridView.count(
              controller: controller,
              itemCount: tiles.length,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              crossAxisCount: 2,        // two columns staggered grid
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _navigateAndDisplaySelection(context, index);
                  },
                  child: GoldPetCard(
                    tile: tiles[index],
                    favorites: favorites,
                    onVideoBadgeFirstSeen: _onVideoBadgeFirstSeen,
                    showVideoGlow: _videoBadgeGlowIds.contains(tiles[index].id ?? ''),
                  ),
                );
              },
            ),
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
    BuildContext context, int index) async {
  final countOfFavorites = globals.listOfFavorites.length;

  await Get.to(
    () => petDetail(tiles[index].id!),
    transition: Transition.circularReveal,
    duration: const Duration(seconds: 1),
  );

  // refresh favorites after returning
  if (userID != null) {
    favorites = await server.getFavorites(userID!);
  }

  setState(() {
    globals.listOfFavorites = favorites;

    // if user unfavorited, remove from grid
    if (main.favoritesSelected &&
        globals.listOfFavorites.length < countOfFavorites) {
      tiles.removeAt(index);
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
  SharedPreferences prefs = await _prefs;
  String? savedZip = prefs.getString("zipCode");
  if (savedZip != null && savedZip.isNotEmpty) {
    return savedZip;
  }
  return AppConfig.defaultZipCode;
}

// ----------------------------------------------------------------------
//                         CLEAR ZIP CODE (long-press)
// ----------------------------------------------------------------------
Future<void> _clearZipCode() async {
  final prefs = await _prefs;
  await prefs.remove('zipCode');
  if (!mounted) return;
  setState(() {
    server.zip = '?';
    count = '?';
    tiles = [];
    loadedPets = 0;
    maxPets = -1;
    _videoBadgeSeenIds.clear();
    _videoBadgeGlowIds.clear();
  });
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('ZIP code cleared. Tap the ZIP button to enter a new one.'),
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
      // Valid - update globally
      setState(() {
        server.zip = zipTrimmed;
      });
      SharedPreferences prefs = await _prefs;
      prefs.setString("zipCode", zipTrimmed);
      
      // Reload pets with new zip
      tiles = [];
      loadedPets = 0;
      maxPets = -1;
      _videoBadgeSeenIds.clear();
      _videoBadgeGlowIds.clear();
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
      // Update globally
      server.zip = zip;
      SharedPreferences prefs = await _prefs;
      await prefs.setString("zipCode", zip);
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
  var result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SearchScreen(
        categories: _buildCategories(),
        filteringOptions: filteringOptions,
        userID: userID ?? "demo-user",
      ),
    ),
  );

  if (result != null) {
    setState(() {
      if (result is FilterResult) {
        filters = result.filters;
        filterprocessing = result.filterprocessing;
      } else if (result is List<Filters>) {
        filters = result;
        filterprocessing = null;
      }
      filters_backup = filters;
      tiles = [];
      loadedPets = 0;
      maxPets = -1;
      _videoBadgeSeenIds.clear();
      _videoBadgeGlowIds.clear();
      main.favoritesSelected = false;
      widget.setFav?.call(false);
      getPets();
    });
  }
}

// ----------------------------------------------------------------------
//                           FAVORITES HANDLER
// ----------------------------------------------------------------------
void setFavorites(bool favorited) {
  setState(() {
    main.favoritesSelected = favorited;

    tiles = [];
    loadedPets = 0;
    maxPets = -1;
    _videoBadgeSeenIds.clear();
    _videoBadgeGlowIds.clear();

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
  if (controller.position.extentAfter < 500) {
    if (loadedPets < maxPets) {
      setState(() {
        getPets();
      });
    }
  }
}

// ----------------------------------------------------------------------
//                         RESCUE GROUPS API CALL
// ----------------------------------------------------------------------
void getPets() async {
  int currentPage = ((loadedPets + tilesPerLoad) / tilesPerLoad).floor();
  loadedPets += tilesPerLoad;
  String sortMethod = globals.sortMethod;

  String baseUrl =
      "https://api.rescuegroups.org/v5/public/animals/search/available";
  String url =
      "$baseUrl?fields[animals]=distance,id,ageGroup,sex,sizeGroup,name,breedPrimary,updatedDate,status,descriptionText"
      "&fields[orgs]=id,name,citystate"
      "&include=orgs,pictures,locations,statuses,videos"
      "&sort=$sortMethod&limit=25&page=$currentPage";

  if (main.favoritesSelected) {
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

  // Validate zip code before sending to API
  String zipCode = server.zip;
  if (zipCode.isEmpty || zipCode == "?" || zipCode.length != 5) {
    // Use default zip code if current one is invalid
    zipCode = AppConfig.defaultZipCode;
    print('⚠️ Invalid zip code "$server.zip", using default: $zipCode');
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
    setState(() {
      tiles = [];
      maxPets = 0;
      count = "No Matches";
      _videoBadgeSeenIds.clear();
      _videoBadgeGlowIds.clear();
    });
    return;
  }

  try {
    var jsonMap = jsonDecode(response.body);

    Meta meta = Meta.fromJson(jsonMap["meta"]);
    print('🔗 Animals search: request succeeded (200). meta.count=${meta.count}, countReturned=${jsonMap["meta"]?["countReturned"] ?? "n/a"}');
    pet petDecoded;

    if (meta.count == 0) {
      print('🔗 Animals search: API returned 0 matches (filters/location may exclude all animals)');
      petDecoded = pet(meta: meta, data: [], included: []);
    } else {
      petDecoded = pet.fromJson(jsonMap);
    }

    // set max count on first load
    if (maxPets < 1) {
      setState(() {
        maxPets = petDecoded.meta?.count ?? 0;
        count = maxPets == 0 ? "No Matches" : maxPets.toString();
      });
    }

    // append tiles (build each tile in try/catch so one bad record doesn't clear the list)
    if (petDecoded.data != null && petDecoded.included != null) {
      final included = petDecoded.included!;
      setState(() {
        for (var petData in petDecoded.data!) {
          try {
            final tile = PetTileData(petData, included);
            tile.suggestedCatTypeName =
                DescriptionCatTypeScorer.getTopCatTypeName(tile.descriptionText);
            tiles.add(tile);
          } catch (e) {
            print("Skip pet ${petData.id}: $e");
          }
        }
      });
    }
  } catch (e) {
    print("🔗 Animals search: request succeeded (200) but JSON parse failed: $e");
    setState(() {
      tiles = [];
      maxPets = 0;
      count = "No Matches";
      _videoBadgeSeenIds.clear();
      _videoBadgeGlowIds.clear();
    });
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
