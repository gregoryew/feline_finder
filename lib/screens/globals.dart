library felinefinderapp.globals;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import '../models/searchPageConfig.dart';
import '../models/zippopotam.dart';
import 'package:get/get.dart';
import '../ExampleCode/RescueGroupsQuery.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const serverName = "stingray-app-uadxu.ondigitalocean.app";
const double petDetailImageHeight = 300;
const double petDetailImageWidth = 330;
String sortMethod = "animals.distance";
int distance = 1000;
int updatedSince = 4;
List<String> listOfFavorites = [];

class FelineFinderServer {
  static final FelineFinderServer _instance = FelineFinderServer._();

  String zip = "?";

  FelineFinderServer._();

  static FelineFinderServer get instance => _instance;

  final _sliderValue = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  List<int> get sliderValue => _sliderValue;

  /// PersonalityFit screen uses its own slider storage so it doesn't conflict with Fit.
  final Map<int, int> _personalityFitSliderValue = {};
  int getPersonalityFitSliderValue(int questionId) =>
      _personalityFitSliderValue[questionId] ?? 0;
  void setPersonalityFitSliderValue(int questionId, int value) {
    _personalityFitSliderValue[questionId] = value;
  }

  /// User's selected personality cat type on search screen (e.g. "Lap Legend").
  /// When set, adoption list shows this type for cats that score "above great" (>= 85%) for it.
  String? _selectedPersonalityCatTypeName;
  String? get selectedPersonalityCatTypeName => _selectedPersonalityCatTypeName;
  void setSelectedPersonalityCatTypeName(String? name) {
    _selectedPersonalityCatTypeName = name;
  }

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
    // Use Firebase Auth UID with persistent storage
    try {
      // First, check for stored persistent UID
      final prefs = await SharedPreferences.getInstance();
      var storedUID = prefs.getString('anonymous_user_uid');

      final authUser = FirebaseAuth.instance.currentUser;

      // Clear any fallback UIDs from storage
      if (storedUID != null && storedUID.startsWith('fallback-')) {
        print('⚠️ Found invalid fallback UID in storage, clearing it');
        await prefs.remove('anonymous_user_uid');
        storedUID = null;
      }

      if (authUser == null) {
        // No current user - try to sign in anonymously
        print("No auth user, signing in anonymously");
        try {
          final userCredential =
              await FirebaseAuth.instance.signInAnonymously();
          _userID = userCredential.user!.uid;
          await prefs.setString('anonymous_user_uid', _userID);
          print(
              "Signed in anonymously with UID: $_userID (stored for persistence)");
        } catch (e) {
          print("Error signing in anonymously: $e");
          // If stored UID exists and is valid (not fallback), use it temporarily
          if (storedUID != null && !storedUID.startsWith('fallback-')) {
            print("⚠️ Using stored UID temporarily: $storedUID");
            _userID = storedUID;
          } else {
            throw Exception(
                'Unable to authenticate. Please restart the app. Error: $e');
          }
        }
      } else {
        // User exists - use their UID and ensure it's stored
        _userID = authUser.uid;
        if (storedUID != _userID) {
          await prefs.setString('anonymous_user_uid', _userID);
          print("Updated stored UID to match current auth: $_userID");
        } else {
          print("Using existing auth user UID: $_userID (already stored)");
        }
      }
    } catch (e) {
      print("Error in getUser(): $e");
      // Try to use stored UID if it's valid (not fallback)
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedUID = prefs.getString('anonymous_user_uid');
        if (storedUID != null &&
            storedUID.isNotEmpty &&
            !storedUID.startsWith('fallback-')) {
          _userID = storedUID;
          print("Using stored UID after error: $_userID");
          return _userID;
        }
      } catch (prefsError) {
        print("Error accessing SharedPreferences: $prefsError");
      }
      // If we can't get a valid UID, throw an error
      throw Exception(
          'Unable to get authenticated user ID. Please restart the app. Error: $e');
    }

    final docRef =
        FirebaseFirestore.instance.collection('adopters').doc(_userID);

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
    // Pre-validate: reject obviously invalid ZIP codes
    final zip = zipCode.trim();

    // Reject all zeros (00000)
    if (zip == "00000" || RegExp(r'^0+$').hasMatch(zip)) {
      print("=== ZIP CODE VALIDATION START ===");
      print("ZIP Code to validate: $zip");
      print("ZIP code validation result: false (all zeros)");
      print("=== ZIP CODE VALIDATION END ===");
      return false;
    }

    // Reject invalid ranges
    final zipNum = int.tryParse(zip);
    if (zipNum != null) {
      // US ZIP codes range from 00501 to 99950
      if (zipNum < 501 || zipNum > 99950) {
        print("=== ZIP CODE VALIDATION START ===");
        print("ZIP Code to validate: $zip");
        print(
            "ZIP code validation result: false (out of valid range: $zipNum)");
        print("=== ZIP CODE VALIDATION END ===");
        return false;
      }
    }

    var url = "https://api.zippopotam.us/us/$zip";

    print("=== ZIP CODE VALIDATION START ===");
    print("URL = $url");
    print("ZIP Code to validate: $zip");

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
      
      // Check if it's a network connectivity error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') || 
          errorString.contains('clientexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('network is unreachable') ||
          errorString.contains('connection refused') ||
          errorString.contains('connection timed out')) {
        print("Network error detected during ZIP validation");
        // Return null to indicate network error (vs false for invalid zip)
        return null;
      }
      
      // For other errors, assume invalid zip code
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

    var userID0 = await getUser();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection("Filters")
        .where("name", isEqualTo: filterName)
        .where("created_by", isEqualTo: userID0)
        .get();

    if (snapshot.docs.isEmpty) {
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
    var userID0 = await getUser();

    var json = {
      'created_by': userID0,
      'name': filterName,
      'query': filter,
      'sort': (sortMethod == "animals.distance" ? 1 : 0),
      'distance': distance,
      'updated_since': updatedSince
    };

    try {
      await deleteQuery(userID0, filterName);
      await FirebaseFirestore.instance.collection('Filters').add(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteQuery(String userID, String filterName) async {
    var userID0 = await getUser();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection("Filters")
        .where("name", isEqualTo: filterName)
        .where("created_by", isEqualTo: userID0)
        .get();

    if (snapshot.docs.isEmpty) {
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
