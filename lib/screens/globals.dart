library felinefinderapp.globals;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import '../models/searchPageConfig.dart';
import '../models/zippopotam.dart';
import 'package:get/get.dart';
import '../ExampleCode/RescueGroupsQuery.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

const serverName = "stingray-app-uadxu.ondigitalocean.app";
const double? petDetailImageHeight = 300;
const double? petDetailImageWidth = 330;
String sortMethod = "animals.distance";
int distance = 1000;
int updatedSince = 4;
List<String> listOfFavorites = [];

class FelineFinderServer {
  static FelineFinderServer _instance = FelineFinderServer._();

  String zip = "?";

  FelineFinderServer._();

  static FelineFinderServer get instance => _instance;

  final _sliderValue = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  List<int> get sliderValue => _sliderValue;

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  String _userID = "";

  CatClassification? whichCategory = CatClassification.basic;

  String currentFilterName = "";

  Future<Map<String, String>> parseStringToMap(
      {String assetsFileName = '.env'}) async {
    print("=== LOADING .ENV FILE ===");
    print("Assets file name: $assetsFileName");

    try {
      final lines = await rootBundle.loadString(assetsFileName);
      print("Raw .env content: $lines");

      Map<String, String> environment = {};
      for (String line in lines.split('\n')) {
        line = line.trim();
        print("Processing line: '$line'");

        if (line.contains('=') //Set Key Value Pairs on lines separated by =
            &&
            !line.startsWith(RegExp(r'=|#'))) {
          //No need to add emty keys and remove comments
          List<String> contents = line.split('=');
          String key = contents[0];
          String value = contents.sublist(1).join('=');
          environment[key] = value;
          print("Added to environment: '$key' = '$value'");
        }
      }

      print("Final environment map: $environment");
      print("=== END LOADING .ENV FILE ===");
      return environment;
    } catch (e) {
      print("Error loading .env file: $e");
      return {};
    }
  }

  var loggedIn = false;

  Future<String> getUser() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.containsKey('uuid')) {
      _userID = (prefs.getString('uuid') ?? "");
    } else {
      var userID = const Uuid();
      _userID = userID.v1();
      prefs.setString("uuid", _userID);
    }

    final docRef = FirebaseFirestore.instance.collection('Users').doc(_userID);

    if (loggedIn) return _userID;

    loggedIn = true;

    try {
      await docRef.get().then((docSnapshot) {
        if (docSnapshot.exists) {
          int logins = docSnapshot.data()!['logins'] ?? 0;
          docRef.set({'lastLogin': DateTime.now(), 'logins': logins + 1},
              SetOptions(merge: true));
        } else {
          TargetPlatform platform = defaultTargetPlatform;
          docRef.set({
            'createdDate': DateTime.now(),
            'lastLogin': DateTime.now(),
            'logins': 1,
            'platform': platform.toString()
          });
        }
      });
    } catch (e) {
      print("Error initializing user data: $e");
      // Continue without Firestore if it fails
    }

    return _userID;
  }

  void favoritePet(String userID, String petID) async {
    try {
      List<String> currentArray = await getFavorites(userID);
      if (!currentArray.contains(petID)) {
        currentArray.add(petID);
        await FirebaseFirestore.instance
            .collection('Favorites')
            .doc(userID)
            .set({'PetIDs': currentArray});
      }
    } catch (e) {
      print("Error favoriting pet: $e");
    }
  }

  Future<bool> isFavorite(String userID, String petID) async {
    List<String> currentArray = await getFavorites(userID);
    return currentArray.contains(petID);
  }

  Future<List<String>> getFavorites(String userID) async {
    try {
      _userID = await getUser();
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('Favorites')
          .doc(_userID)
          .get();
      final data = documentSnapshot.data();
      Map<String, dynamic> myMap;
      if (data == null) {
        myMap = {"PetIDs": []};
      } else {
        myMap = data as Map<String, dynamic>;
      }
      List<String> currentArray = List<String>.from(myMap['PetIDs']);
      return currentArray;
    } catch (e) {
      print("Error getting favorites: $e");
      return [];
    }
  }

  void unfavoritePet(String userID, String petID) async {
    try {
      List<String> currentArray = await getFavorites(userID);
      if (currentArray.contains(petID)) {
        currentArray.remove(petID);
        await FirebaseFirestore.instance
            .collection('Favorites')
            .doc(userID)
            .set({'PetIDs': currentArray});
      }
    } catch (e) {
      print("Error unfavoriting pet: $e");
    }
  }

  Future<bool?> isZipCodeValid(String zipCode) async {
    var url = "https://api.zippopotam.us/us/${zipCode}";

    print("=== ZIP CODE VALIDATION START ===");
    print("URL = $url");
    print("ZIP Code to validate: $zipCode");

    try {
      var response = await http.get(Uri.parse(url));
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);

        // Check if response is empty (invalid ZIP)
        if (jsonData.isEmpty) {
          print("ZIP code validation result: false (empty response)");
          return false;
        }

        var places = Zippopotam.fromJson(jsonData);

        // Check if we have valid places data
        bool isValid = places.places.isNotEmpty &&
            places.country.isNotEmpty &&
            places.postCode.isNotEmpty;

        print("ZIP code validation result: $isValid");
        print("=== ZIP CODE VALIDATION END ===");
        return isValid;
      } else {
        print("HTTP error: ${response.statusCode}");
        if (response.statusCode != 404) {
          await Get.dialog(
            AlertDialog(
              title: const Text("Server Error"),
              content: Text(
                  "There was a server error while validating zip code.  The error code is ${response.statusCode}"),
              actions: <Widget>[
                ElevatedButton(
                  child: const Text("CLOSE"),
                  onPressed: () {
                    Get.back(result: true);
                  },
                ),
              ],
            ),
          );
        }
        return false;
      }
    } catch (e) {
      print("Exception during ZIP validation: $e");
      return false;
    }
  }

  String getCountryISOCode() {
    try {
      final List<Locale> systemLocales =
          WidgetsBinding.instance.platformDispatcher.locales;
      if (systemLocales.isNotEmpty) {
        String? isoCountryCode = systemLocales.first.countryCode;
        if (isoCountryCode != null && isoCountryCode.isNotEmpty) {
          return isoCountryCode;
        }
      }
      // Fallback to US if no country code is available
      return 'US';
    } catch (e) {
      // Fallback to US if any error occurs
      return 'US';
    }
  }

  Future<List<String>> getQueries(String userID) async {
    _userID = await getUser();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection("Filters")
        .where("created_by", isEqualTo: _userID)
        .get();

    final List<String> filteredNames =
        snapshot.docs.map((doc) => doc.data()['name'] as String).toList();

    return filteredNames;
  }

  Future<RescueGroupsQuery?> getQuery(String userID, String filterName) async {
    if (filterName == "New") {
      return RescueGroupsQuery.fromJson(jsonDecode(""));
    }

    var _userID = await getUser();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection("Filters")
        .where("name", isEqualTo: filterName)
        .where("created_by", isEqualTo: _userID)
        .get();

    if (snapshot.docs.length == 0) {
      return null;
    }

    var query = snapshot.docs[0].data();
    sortMethod =
        query['sort'] == 0 ? "-animals.updatedDate" : "animals.distance";
    distance = query['distance'];
    updatedSince = query['updated_since'];
    Map<dynamic, dynamic> q = query['query'] as Map<dynamic, dynamic>;
    return RescueGroupsQuery.fromJson(q);
  }

  Future<bool> saveFilter(
      String userID, String filterName, Object filter) async {
    var _userID = await getUser();

    var json = {
      'created_by': _userID,
      'name': filterName,
      'query': filter,
      'sort': (sortMethod == "animals.distance" ? 1 : 0),
      'distance': distance,
      'updated_since': updatedSince
    };

    try {
      await deleteQuery(_userID, filterName);
      await FirebaseFirestore.instance.collection('Filters').add(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteQuery(String userID, String filterName) async {
    var _userID = await getUser();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection("Filters")
        .where("name", isEqualTo: filterName)
        .where("created_by", isEqualTo: _userID)
        .get();

    if (snapshot.docs.length == 0) {
      return true;
    }

    final String documentId = snapshot.docs[0].id;
    await FirebaseFirestore.instance
        .collection("Filters")
        .doc(documentId)
        .delete();
    return true;
  }
}
