// ignore_for_file: dead_code

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' as main;
//import '/ExampleCode/RescueGroups.dart';
import '../models/rescuegroups_v5.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import '/screens/petDetail.dart';
import '/screens/search.dart';
import '/screens/recommendations.dart';
import '../config.dart';
import 'globals.dart' as globals;
import 'package:get/get.dart';
import 'package:catapp/models/searchPageConfig.dart';
import '../theme.dart';
import '../widgets/design_system.dart';

class AdoptGrid extends StatefulWidget {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
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
  //bool favorited = false;
  List<Filters> filters = [];
  List<Filters> filters_backup = [];
  String? RescueGroupApi = "";

  @override
  void initState() {
    super.initState();
    controller = ScrollController()..addListener(_scrollListener);
    controller2 = TextEditingController();
    filters.add(Filters(
        fieldName: "species.singular", operation: "equals", criteria: ["cat"]));
    filters_backup.add(Filters(
        fieldName: "species.singular", operation: "equals", criteria: ["cat"]));

    // Set the API key immediately during initialization
    RescueGroupApi = AppConfig.rescueGroupsApiKey;
    print("RescueGroupApi set during initState: '$RescueGroupApi'");

    () async {
      try {
        String user = await server.getUser();
        favorites = await server.getFavorites(user);
        var zip = await _getZip();
        // Temporarily hardcode the API key to test pet search functionality
        print("Using hardcoded API key for testing");

        setState(() {
          main.favoritesSelected = false;
          widget.setFav!(main.favoritesSelected);
          globals.listOfFavorites = favorites;
          userID = user;
          server.zip = zip;
          RescueGroupApi = AppConfig.rescueGroupsApiKey;
          print("RescueGroupApi after assignment: '$RescueGroupApi'");
          getPets();
        });
      } catch (e) {
        print("Error initializing user data: $e");
        // Set fallback values when Firestore fails
        setState(() {
          userID = "demo-user"; // Fallback user ID
          favorites = [];
          server.zip = AppConfig.defaultZipCode; // Default zip code
          RescueGroupApi = AppConfig.rescueGroupsApiKey;
          getPets();
        });
      }
    }();
  }

  Future<String> _getZip() async {
    SharedPreferences prefs = await _prefs;
    String? zipCode = "";
    if (prefs.containsKey('zipCode')) {
      print("got zipCode");
      var zip = prefs.getString('zipCode') ?? "";
      setState(() {
        zipCode = zip;
      });
    }
    if (zipCode!.isEmpty) {
      var zip = await _getGPSZip();
      setState(() {
        zipCode = zip;
        prefs.setString("zipCode", zipCode!);
      });
    }
    if (zipCode == "ERROR") {
      zipCode = await openDialog();
      if (zipCode == null || zipCode!.isEmpty) {
        zipCode = "66952";
      }
      prefs.setString("zipCode", zipCode!);
    }
    print("%%%%%%%%% ZIP CODE = ${zipCode!}");
    return zipCode!;
  }

  late TextEditingController controller2;

  Future<String?> openDialog() => showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text("Enter Zip Code"),
              content: TextField(
                keyboardType: server.getCountryISOCode() == "US"
                    ? TextInputType.number
                    : TextInputType.text,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Zip Code"),
                controller: controller2,
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(onPressed: submit, child: const Text("Submit"))
              ]));

  void submit() {
    Navigator.of(context).pop(controller2.text);
    controller2.clear();
  }

  Future<String> _getGPSZip() async {
    bool serviceEnabled;
    LocationPermission permission;
    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return "ERROR";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return "ERROR";
    }

    Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ));

    print('location: ${position.latitude}');
    List<Placemark> addresses =
        await placemarkFromCoordinates(position.latitude, position.longitude);

    var first = addresses.first;
    print("${first.name} : ${first..administrativeArea}");
    if (first.postalCode == null) {
      return "ERROR";
    } else {
      return first.postalCode!;
    }
  }

  void _scrollListener() {
    if (controller.position.extentAfter < 500) {
      setState(() {
        if (loadedPets < maxPets) {
          getPets();
        }
      });
    }
  }

  void recommendations() async {
    await Get.to(() => const CatRecommendationScreen(),
        transition: Transition.fadeIn, duration: const Duration(seconds: 1));
  }

  Map<CatClassification, List<filterOption>> _buildCategories() {
    Map<CatClassification, List<filterOption>> categories = {};

    for (var filter in filteringOptions) {
      if (!categories.containsKey(filter.classification)) {
        categories[filter.classification] = [];
      }
      categories[filter.classification]!.add(filter);
    }

    // Sort filters within each category by sequence number
    categories.forEach((key, value) {
      value.sort((a, b) => a.sequence.compareTo(b.sequence));
    });

    return categories;
  }

  void search() async {
    print("=== OPENING SEARCH SCREEN ===");
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
    print("=== SEARCH RESULT RECEIVED ===");
    print("Result: $result");
    print("Result length: ${result?.length}");

    if (result != null && result.length > 0) {
      print("Applying search filters...");
      print("Filters before: ${filters.length}");
      setState(
        () {
          filters = result;
          filters_backup = filters;
          tiles = [];
          loadedPets = 0;
          maxPets = -1;
          main.favoritesSelected = false;
          widget.setFav!(main.favoritesSelected);
          print("Filters after: ${filters.length}");
          for (var filter in filters) {
            print(
                "Applied filter: ${filter.fieldName} ${filter.operation} ${filter.criteria}");
          }
          getPets();
        },
      );
    } else {
      print("No search results to apply");
    }
  }

  void whileYourAwaySearch() {
    print("While Your Away");
  }

  void setFavorites(bool favorited) {
    print(
        "Favorites pressed. ${(main.favoritesSelected) ? "Favorited" : "Unfavorited"}");
    setState(() {
      main.favoritesSelected = favorited;
      tiles = [];
      loadedPets = 0;
      maxPets = -1;
      getPets();
    });
  }

  void getPets() async {
    print('Getting Pets');

    int currentPage = ((loadedPets + tilesPerLoad) / tilesPerLoad).floor();
    loadedPets += tilesPerLoad;
    String sortMethod = globals.sortMethod;
    var url =
        "https://api.rescuegroups.org/v5/public/animals/search/available?fields[animals]=distance,id,ageGroup,sex,sizeGroup,name,breedPrimary,updatedDate,status&sort=$sortMethod&limit=25&page=$currentPage";

    print("&&&&&& zip = ${server.zip}");

    if (main.favoritesSelected) {
      filters = [
        Filters(
            fieldName: "animals.id",
            operation: "equal",
            criteria: globals.listOfFavorites)
      ];
    } else {
      // Only reset filters if they haven't been set by search
      if (filters.isEmpty ||
          (filters.length == 1 && filters[0].fieldName == "species.singular")) {
        // Add default filters for cats
        filters = [
          Filters(
              fieldName: "species.singular",
              operation: "equals",
              criteria: ["cat"])
        ];
        filters_backup = filters;
      }
    }

    List<Map<dynamic, dynamic>> filtersJson = [];
    for (var element in filters) {
      filtersJson.add({
        "fieldName": element.fieldName,
        "operation": element.operation,
        "criteria": element.criteria
      });
    }

    Map<dynamic, dynamic> data = {
      "data": {
        "filterRadius": {"miles": globals.distance, "postalcode": server.zip},
        "filters": filtersJson,
      }
    };

    var data2 = RescueGroupsQuery.fromJson(data);

    print("RescueGroupApi value: '$RescueGroupApi'");
    print("RescueGroupApi is null: ${RescueGroupApi == null}");
    print("RescueGroupApi is empty: ${RescueGroupApi?.isEmpty ?? true}");
    print("Zip code: '${server.zip}'");
    print("Distance: ${globals.distance}");
    print("Filters count: ${filters.length}");
    print("Filters: $filtersJson");
    print("Request body: ${json.encode(data2.toJson())}");

    // Print curl command for debugging
    final requestBody = json.encode(data2.toJson());
    final escapedBody = requestBody.replaceAll("'", "'\\''");

    // URL-encode square brackets for iOS compatibility in curl command
    final curlUrl = url.replaceAll('[', '%5B').replaceAll(']', '%5D');
    final curlCommand = "curl -X POST '$curlUrl' \\\n"
        "  -H 'Content-Type: application/json; charset=UTF-8' \\\n"
        "  -H 'Authorization: $RescueGroupApi' \\\n"
        "  -d '$escapedBody'";

    print("\n\n\n\n\n");
    print("THIS IS THE QUERY WE ARE RUNNING");
    print("\n");
    print(curlCommand);
    print("\n\n\n");

    // Uri.parse handles encoding automatically, but ensure brackets are encoded for iOS
    final encodedUrl = url.replaceAll('[', '%5B').replaceAll(']', '%5D');
    var response = await http.post(Uri.parse(encodedUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': '$RescueGroupApi',
        },
        body: json.encode(data2.toJson()));

    print("API Key being sent: $RescueGroupApi");
    print("Response status: ${response.statusCode}");
    print("Response headers: ${response.headers}");

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");

      // Check if response body is empty or null
      if (response.body.isEmpty) {
        print("Empty response body");
        setState(() {
          tiles = [];
          maxPets = 0;
          count = "No Matches";
        });
        return;
      }

      try {
        var json = jsonDecode(response.body);
        late pet petDecoded;
        var meta = Meta.fromJson(json["meta"]);
        if (meta.count == 0) {
          petDecoded = pet(meta: meta, data: [], included: []);
        } else {
          petDecoded = pet.fromJson(json);
          if (maxPets < 1) {
            setState(() {
              maxPets = (petDecoded.meta?.count ?? 0);
              count = (maxPets == 0 ? "No Matches" : maxPets.toString());
            });
          }
          setState(() {
            petDecoded.data?.forEach((petData) {
              tiles.add(PetTileData(petData, petDecoded.included!));
            });
          });
        }
        return;
      } catch (e) {
        print("JSON parsing error: $e");
        print("Response body: ${response.body}");
        setState(() {
          tiles = [];
          maxPets = 0;
          count = "No Matches";
        });
        return;
      }
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load pet ${response.body}');
    }
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    controller2.dispose();
    super.dispose();
  }

  Future<void> askForZip() async {
    late String? zip;
    bool? valid; // Initialize as null instead of false
    late bool canceled = false;
    do {
      zip = await openDialog();
      if (zip != null && zip.isNotEmpty) {
        var valid0 = await server.isZipCodeValid(zip);
        print("ZIP validation result for $zip: $valid0");
        setState(() {
          valid = valid0;
        });
      }
      if (valid == false) {
        // Check for false instead of !valid!
        await Get.defaultDialog(
            title: "Invalid Zip Code",
            middleText: "Please enter a valid zip code.",
            backgroundColor: Colors.red,
            titleStyle: const TextStyle(color: Colors.white),
            middleTextStyle: const TextStyle(color: Colors.white),
            textConfirm: "OK",
            confirmTextColor: Colors.white,
            onConfirm: () {
              valid = false;
              canceled = false;
              Get.back();
            },
            textCancel: "Cancel",
            cancelTextColor: Colors.white,
            onCancel: () {
              valid = true;
              canceled = true;
              Get.back();
            },
            buttonColor: Colors.black,
            barrierDismissible: false,
            radius: 30);
      }
    } while (valid == false);

    if (canceled == false) {
      setState(() {
        server.zip = zip!;
      });
      SharedPreferences prefs = await _prefs;
      prefs.setString("zipCode", zip!);
      setState(() {
        tiles = [];
        loadedPets = 0;
        maxPets = -1;
        getPets();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String status = "";

    if (main.favoritesSelected) {
      status = " Favorites: ";
    } else {
      status = " Cats: ";
    }
    if (count == "Processing") {
      status += "Processing";
    } else if (tiles.isEmpty) {
      status += "0";
    } else {
      status += count;
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GoldenButton(
                    text: "Zip: ${server.zip}",
                    onPressed: () => {askForZip()},
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    )),
                Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              ],
            ),
            Row(
              children: [
                Center(
                  child: Text(
                    (count != "Processing" && tiles.isEmpty)
                        ? (main.favoritesSelected
                            ? "     You have not chosen any favorites yet."
                            : "     No cats to see.  Please change your search.")
                        : "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: MasonryGridView.count(
                controller: controller,
                itemCount: tiles.isNotEmpty ? tiles.length : 0,
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                // the number of columns
                crossAxisCount: 2,
                // vertical gap between two items
                mainAxisSpacing: 10,
                // horizontal gap between two items
                crossAxisSpacing: 10,
                itemBuilder: (context, index) {
                  // display each item with a card
                  return GestureDetector(
                      onTap: () {
                        _navigateAndDisplaySelection(context, index);
                      },
                      child: petCard(tiles[index]));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateAndDisplaySelection(
      BuildContext context, int index) async {
    final countOfFavorites = globals.listOfFavorites.length;
    await Get.to(() => petDetail(tiles[index].id!),
        transition: Transition.circularReveal,
        duration: const Duration(seconds: 1));

    if (userID != null) {
      favorites = await server.getFavorites(userID!);
    }
    setState(() {
      globals.listOfFavorites = favorites;
      if (main.favoritesSelected &&
          globals.listOfFavorites.length < countOfFavorites) {
        tiles.removeAt(index);
      }
    });
  }

  Widget petCard(PetTileData tile) {
    return GoldenCard(
        margin: const EdgeInsets.all(5),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: SizedBox(
              height: (tile.smallPictureResolutionY == 0
                      ? 100
                      : tile.smallPictureResolutionY!) +
                  300,
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                //crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                          AppTheme.cardBorderRadius,
                        ),
                        topRight: Radius.circular(
                          AppTheme.cardBorderRadius,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                image: NetworkImage(tile.smallPicture ??
                                    "https://upload.wikimedia.org/wikipedia/commons/6/65/No-Image-Placeholder.svg"),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter)),
                        child: Stack(
                          children: [
                            Align(
                                alignment: const Alignment(-0.9, -0.9),
                                child: Visibility(
                                    visible: favorites.contains(tile.id),
                                    child: Image.asset(
                                        "assets/Icons/favorited_icon_resized.png"))),
                            Align(
                                alignment: const Alignment(0.9, -0.9),
                                child: Visibility(
                                    visible: tile.hasVideos!,
                                    child: Image.asset(
                                        "assets/Icons/video_icon_resized.png"))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    color: AppTheme.goldBase,
                  ),
                  Container(
                    //height: 130,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppTheme.traitCardBackground,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(AppTheme.cardBorderRadius),
                        bottomRight: Radius.circular(AppTheme.cardBorderRadius),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            tile.name ?? "No Name",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: AppTheme.fontSizeS,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Center(
                          child: Text(
                            tile.primaryBreed ?? "",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: AppTheme.fontSizeXS,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        getStats(tile)
                      ],
                    ),
                  ),
                ],
              ),
            )));
  }

  Widget getStats(PetTileData tile) {
    List<String> stats = [];
    if (tile.status != null) {
      stats.add(tile.status ?? "");
    }
    if (tile.age != null) {
      stats.add(tile.age ?? "");
    }
    if (tile.sex != null) {
      stats.add(tile.sex ?? "");
    }
    if (tile.size != null) {
      stats.add(tile.size ?? "");
    }
    if (tile.cityState != null) {
      stats.add("📌${tile.cityState ?? "Unknown"}");
    }
    List<Color> foreground = [
      const Color.fromRGBO(101, 164, 43, 1),
      const Color.fromRGBO(3, 122, 254, 1),
      const Color.fromRGBO(245, 76, 10, 1.0),
      Colors.deepPurple,
      Colors.deepOrange
    ];
    List<Color> background = [
      const Color.fromRGBO(222, 234, 209, 1),
      const Color.fromRGBO(209, 224, 239, 1),
      const Color.fromARGB(255, 246, 193, 167),
      Colors.purpleAccent.shade100,
      Colors.orangeAccent
    ];
    return Center(
        child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 10,
                runSpacing: 10,
                direction: Axis.horizontal,
                children: stats.map((item) {
                  return Container(
                      width: 100,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: foreground[stats.indexOf(item)]),
                          color: background[stats.indexOf(item)],
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5))),
                      child: Text(stats[stats.indexOf(item)].trim(),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: foreground[stats.indexOf(item)]),
                          textAlign: TextAlign.center));
                }).toList())));
  }
}
