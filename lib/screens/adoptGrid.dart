// ignore_for_file: dead_code

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

import '/ExampleCode/RescueGroups.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import '/screens/petDetail.dart';
import '/screens/search.dart';
import 'globals.dart' as globals;
import 'package:get/get.dart';

class AdoptGrid extends StatefulWidget {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  const AdoptGrid({Key? key}) : super(key: key);

  @override
  AdoptGridState createState() => AdoptGridState();
}

class AdoptGridState extends State<AdoptGrid> {
  List<PetTileData> tiles = [];
  int maxPets = -1;
  int loadedPets = 0;
  int tilesPerLoad = 25;
  late ScrollController controller;
  List<String> favorites = [];
  late String userID;
  List<String> listOfFavorites = [];
  final server = globals.FelineFinderServer.instance;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  bool favorited = false;
  List<Filters> filters = [];
  List<Filters> filters_backup = [];

  @override
  void initState() {
    super.initState();
    controller = ScrollController()..addListener(_scrollListener);
    controller2 = TextEditingController();
    filters.add(Filters(
        fieldName: "species.singular", operation: "equals", criteria: ["cat"]));
    () async {
      String user = await server.getUser();
      favorites = await server.getFavorites(user);
      var _zip = await _getZip();
      setState(() {
        listOfFavorites = favorites;
        userID = user;
        server.zip = _zip;
        getPets();
      });
    }();
  }

  Future<String> _getZip() async {
    SharedPreferences prefs = await _prefs;
    String? zipCode = "";
    if (prefs.containsKey('zipCode')) {
      print("got zipCode");
      var _zip = prefs.getString('zipCode') ?? "";
      setState(() {
        zipCode = _zip;
      });
    }
    if (zipCode!.isEmpty) {
      var _zip = await _getGPSZip();
      setState(() {
        zipCode = _zip;
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
    print("%%%%%%%%% ZIP CODE = " + zipCode!);
    return zipCode!;
  }

  late TextEditingController controller2;

  Future<String?> openDialog() => showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text("Enter Zip Code"),
              content: TextField(
                keyboardType: TextInputType.number,
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
        desiredAccuracy: LocationAccuracy.high);

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

  void search() async {
    final result = await Navigator.push(
      context,
      // Create the SelectionScreen in the next step.
      MaterialPageRoute(builder: (context) => searchScreen()),
    );
    if (result.length > 0) {
      setState(
        () {
          filters = result;
          filters_backup = filters;
          tiles = [];
          loadedPets = 0;
          maxPets = -1;
          getPets();
        },
      );
    }
  }

  void whileYourAwaySearch() {
    print("While Your Away");
  }

  void setFavorites(bool favorited) {
    this.favorited = favorited;
    print("Favorites pressed. ${(favorited) ? "Favorited" : "Unfavorited"}");
    setState(() {
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
    var url =
        "https://api.rescuegroups.org/v5/public/animals/search/available?fields[animals]=distance,id,ageGroup,sex,sizeGroup,name,breedPrimary,updatedDate,status&sort=animals.distance&limit=25&page=$currentPage";

    print("&&&&&& zip = " + server.zip);

    if (favorited) {
      filters = [
        Filters(
            fieldName: "animals.id",
            operation: "equal",
            criteria: listOfFavorites)
      ];
    } else {
      filters = filters_backup;
    }

    List<Map<dynamic, dynamic>> filtersJson = [];
    for (var element in filters) {
      filtersJson.add({
        "fieldName": element.fieldName,
        "operation": "equal",
        "criteria": element.criteria
      });
    }

    Map<dynamic, dynamic> data = {
      "data": {
        "filterRadius": {"miles": 1000, "postalcode": server.zip},
        "filters": filtersJson,
      }
    };

    var data2 = RescueGroupsQuery.fromJson(data);

    var response = await http.post(Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': '0doJkmYU'
        },
        body: json.encode(data2.toJson()));

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");
      var petDecoded = pet.fromJson(jsonDecode(response.body));
      if (maxPets == -1) {
        maxPets = (petDecoded.meta?.count ?? 0);
      }
      setState(() {
        petDecoded.data?.forEach((petData) {
          tiles.add(PetTileData(petData, petDecoded.included!));
        });
      });
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load pet ' + response.body);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    controller2.dispose();
    super.dispose();
  }

  Future<void> askForZip() async {
    late String? _zip;
    late bool? valid = false;
    late bool canceled = false;
    do {
      _zip = await openDialog();
      if (_zip != null && _zip.isNotEmpty) {
        var _valid = await server.isZipCodeValid(_zip);
        setState(() {
          valid = _valid;
        });
      }
      if (!valid!) {
        await Get.defaultDialog(
            title: "Invalid Zip Code",
            middleText: "Please enter a valid zip code.",
            backgroundColor: Colors.red,
            titleStyle: TextStyle(color: Colors.white),
            middleTextStyle: TextStyle(color: Colors.white),
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
    } while (valid! == false);

    if (canceled == false) {
      setState(() {
        server.zip = _zip!;
      });
      SharedPreferences prefs = await _prefs;
      prefs.setString("zipCode", _zip!);
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
    String? zipCode;
    return Scaffold(
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  child: Text("Zip: ${server.zip}"),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(130, 25),
                      maximumSize: const Size(130, 25)),
                  onPressed: () => {askForZip()}),
              Text(
                (favorited ? " Favorites: " : " Cats: ") + maxPets.toString(),
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
    );
  }

  Future<void> _navigateAndDisplaySelection(
      BuildContext context, int index) async {
    // Navigator.push returns a Future that completes after calling
    // Navigator.pop on the Selection Screen.
    final result = await Navigator.push(
      context,
      // Create the SelectionScreen in the next step.
      MaterialPageRoute(builder: (context) => petDetail(tiles[index].id!)),
    );

    favorites = await server.getFavorites(userID);
    setState(() {
      listOfFavorites = favorites;
      if (favorited) {
        tiles = [];
        loadedPets = 0;
        maxPets = -1;
        getPets();
      }
    });
  }

  Widget petCard(PetTileData tile) {
    return Card(
        elevation: 5,
        shadowColor: Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            20,
          ),
        ),
        margin: EdgeInsets.all(5),
        child: Container(
          height: (tile.resolutionY == 0 ? 100 : tile.resolutionY!) + 300,
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      10,
                    ),
                    topRight: Radius.circular(
                      10,
                    ),
                  ),
                  child: FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: tile.picture ?? "",
                    fit: BoxFit.fitWidth,
                    imageErrorBuilder: (context, error, stackTrace) {
                      return Image.asset("assets/Icons/No_Cat_Image.png",
                          width: 200, height: 500);
                    },
                  ),
                  //(tile == null || tile.picture == null || tile.picture == "") ? Image(image: AssetImage("assets/Icons/No_Cat_Image.png"), width: 200, fit: BoxFit.fitWidth) : Image(image: NetworkImage(tile.picture ?? ""), width: 200, fit: BoxFit.fitWidth),
                ),
              ),
              Container(
                height: 2,
                color: Colors.black,
              ),
              Container(
                //height: 130,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ((tile.name ?? "No Name") +
                          (tile.hasVideos! ? " ▶️" : "") +
                          ((listOfFavorites.contains(tile.id)) ? " ❤️" : "")),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(
                      height: 5,
                    ),
                    Text(
                      tile.primaryBreed ?? "",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(
                      height: 5,
                    ),
                    getStats(tile)
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget getStats(PetTileData tile) {
    if (tile == null) {
      return const SizedBox.shrink();
    }

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
      stats.add("📌" + (tile.cityState ?? "Unknown"));
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
