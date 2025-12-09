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
import '../models/searchPageConfig.dart';

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
  String? RescueGroupApi = "";

  late TextEditingController controller2;

  @override
  void initState() {
    super.initState();

    controller = ScrollController()..addListener(_scrollListener);
    controller2 = TextEditingController();

    // Default filter: species = cat
    filters.add(Filters(
      fieldName: "species.singular",
      operation: "equals",
      criteria: ["cat"],
    ));
    filters_backup.add(Filters(
      fieldName: "species.singular",
      operation: "equals",
      criteria: ["cat"],
    ));

    RescueGroupApi = AppConfig.rescueGroupsApiKey;

    () async {
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
          // NEXT ROW: ZIP BUTTON + CAT COUNT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
    zip = AppConfig.defaultZipCode;
  }
  setState(() {
    server.zip = zip!;
  });
  SharedPreferences prefs = await _prefs;
  prefs.setString("zipCode", zip);
  // Reload pets with new zip
  tiles = [];
  loadedPets = 0;
  maxPets = -1;
  getPets();
}

// ----------------------------------------------------------------------
//                         BUILD CATEGORIES
// ----------------------------------------------------------------------
Map<CatClassification, List<filterOption>> _buildCategories() {
  Map<CatClassification, List<filterOption>> categories = {};
  for (var classification in CatClassification.values) {
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

  if (result != null && result.isNotEmpty) {
    setState(() {
      filters = result;
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
  } else {
    if (filters.isEmpty ||
        (filters.length == 1 &&
            filters[0].fieldName == "species.singular")) {
      filters = [
        Filters(
          fieldName: "species.singular",
          operation: "equals",
          criteria: ["cat"],
        ),
      ];
      filters_backup = filters;
    }
  }

  List<Map> filtersJson = filters
      .map((f) => {
            "fieldName": f.fieldName,
            "operation": f.operation,
            "criteria": f.criteria
          })
      .toList();

  Map<String, dynamic> data = {
    "data": {
      "filterRadius": {
        "miles": globals.distance,
        "postalcode": server.zip,
      },
      "filters": filtersJson,
    }
  };

  var requestBody = json.encode(RescueGroupsQuery.fromJson(data).toJson());

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
