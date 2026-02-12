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
import '/screens/recommendations.dart';
import '../config.dart';
import 'globals.dart' as globals;

// GOLD UI COMPONENTS
import '../widgets/gold/gold_pet_card.dart';
import '../widgets/gold/gold_circle_icon_button.dart';
import '../widgets/gold/gold_trait_pill.dart';
import '../widgets/gold/gold_zip_button.dart';

import '../theme.dart';
import '../widgets/design_system.dart';
import '../models/searchPageConfig.dart' as searchConfig;

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
      
      try {
        String user = await server.getUser();
        favorites = await server.getFavorites(user);
        var zip = await _getZip();

        setState(() {
          main.favoritesSelected = false;
          widget.setFav?.call(false);

          globals.listOfFavorites = favorites;
          userID = user;
          server.zip = zip;

          RescueGroupApi = AppConfig.rescueGroupsApiKey;
          getPets();
        });
      } catch (e) {
        // Fallback when Firestore fails
        setState(() {
          userID = "demo-user";
          favorites = [];
          server.zip = AppConfig.defaultZipCode;

          RescueGroupApi = AppConfig.rescueGroupsApiKey;
          getPets();
        });
      }
    }();
  }

  /// Load filters from SharedPreferences
  Future<void> _loadFiltersFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filtersJsonString = prefs.getString('lastSearchFiltersList');
      
      if (filtersJsonString != null && filtersJsonString.isNotEmpty) {
        final filtersJson = jsonDecode(filtersJsonString) as List<dynamic>;
        filters = filtersJson.map((f) => Filters(
          fieldName: f['fieldName'] as String,
          operation: f['operation'] as String,
          criteria: f['criteria'],
        )).toList();
        
        // Create backup copy
        filters_backup = filters.map((f) => Filters(
          fieldName: f.fieldName,
          operation: f.operation,
          criteria: f.criteria,
        )).toList();
        
        print('✅ Loaded ${filters.length} filters from SharedPreferences');
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
          // MESSAGE UNDER ZIP / STATUS
          if (count != "Processing" && tiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                main.favoritesSelected
                    ? "You have not chosen any favorites yet."
                    : "No cats to see. Please adjust your search.",
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontSizeM,
                ),
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
//                         ASK FOR ZIP CODE
// ----------------------------------------------------------------------
Future<void> askForZip() async {
  var zip = await openDialog();
  if (zip == null || zip.isEmpty) {
    // If blank, try to get from adopter's location
    zip = await _getZipFromLocation();
    if (zip == null || zip.isEmpty) {
      zip = AppConfig.defaultZipCode;
    }
  }
  
  final zipTrimmed = zip!.trim();
  
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

    getPets();
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
      "$baseUrl?fields[animals]=distance,id,ageGroup,sex,sizeGroup,name,breedPrimary,updatedDate,status"
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
  List<Map> filtersJson = filters
      .where((f) => 
          f.fieldName != null && 
          f.fieldName!.isNotEmpty &&
          f.operation != null &&
          f.operation!.isNotEmpty &&
          f.criteria != null)
      .map((f) => {
            "fieldName": f.fieldName,
            "operation": f.operation,
            "criteria": f.criteria
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

  // Use state filterProcessing, or default to "1 AND 2 AND ... AND n" when we have multiple filters
  String? effectiveFilterProcessing = (filterprocessing != null && filterprocessing!.isNotEmpty)
      ? filterprocessing
      : (filtersJson.length > 1
          ? List.generate(filtersJson.length, (i) => (i + 1).toString()).join(' AND ')
          : null);

  Map<String, dynamic> data = {
    "data": {
      "filterRadius": {
        "miles": globals.distance,
        "postalcode": zipCode,
      },
      "filters": filtersJson,
    }
  };
  if (effectiveFilterProcessing != null && effectiveFilterProcessing.isNotEmpty) {
    data["data"]["filterProcessing"] = effectiveFilterProcessing;
  }

  print('📤 Sending request with zip code: $zipCode, filters: ${filtersJson.length}${effectiveFilterProcessing != null ? ", filterProcessing: $effectiveFilterProcessing" : ""}');

  // Convert to RescueGroupsQuery to ensure proper structure
  var query = RescueGroupsQuery.fromJson(data);
  var requestBody = json.encode(query.toJson());

  // Pretty-print the cats-for-adoption rescue groups query JSON to terminal
  final prettyJson = const JsonEncoder.withIndent('  ').convert(query.toJson());
  print('🐱 Cats for adoption rescue groups query (pretty JSON):\n$prettyJson');

  // Debug: Print the actual request body being sent
  print('📦 Request body: $requestBody');
  print('📦 Request structure check:');
  print('  - FilterRadius: miles=${query.data.filterRadius.miles}, postalcode=${query.data.filterRadius.postalcode}');
  print('  - Filters count: ${query.data.filters.length}');
  print('  - filterProcessing in body: ${query.data.filterProcessing != null ? "yes (${query.data.filterProcessing})" : "no"}');
  for (var filter in query.data.filters) {
    print('  - Filter: ${filter.fieldName} ${filter.operation} ${filter.criteria}');
  }

  final encodedUrl = url.replaceAll('[', '%5B').replaceAll(']', '%5D');

  var response = await http.post(
    Uri.parse(encodedUrl),
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
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
    setState(() {
      tiles = [];
      maxPets = 0;
      count = "No Matches";
    });
    return;
  }

  try {
    var jsonMap = jsonDecode(response.body);

    Meta meta = Meta.fromJson(jsonMap["meta"]);
    pet petDecoded;

    if (meta.count == 0) {
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

    // append tiles
    if (petDecoded.data != null) {
      setState(() {
        for (var petData in petDecoded.data!) {
          tiles.add(PetTileData(petData, petDecoded.included!));
        }
      });
    }
  } catch (e) {
    print("JSON error: $e");
    setState(() {
      tiles = [];
      maxPets = 0;
      count = "No Matches";
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
