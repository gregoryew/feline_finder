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
/// When SearchScreen was opened from Shelters and user taps Find Cats, call this with the FilterResult so the app switches to Adopt tab and applies the search. Set by HomeScreen.
void Function(dynamic searchResult)? onApplySearchAndSwitchToAdopt;
/// When called with a BuildContext (e.g. from SearchScreen), pop that route and switch to Shelters tab. Set by HomeScreen.
void Function(BuildContext)? onNavigateToSheltersTab;
/// True when user opened Shelters tab from the search screen (Shelters button). Used to show "Select" and return to search with shelter selected.
bool sheltersOpenedFromSearch = false;
/// When user taps "Select" on a shelter (from search flow): switch to Adopt tab and open SearchScreen with this shelter selected. Set by HomeScreen.
void Function(String orgId, String orgName)? onSelectShelterAndOpenSearch;
/// When user taps "View Cats" on a shelter (Shelters tab), store org so next time Search screen opens it pre-selects this shelter. Cleared when search() passes it.
String? lastShelterFromSheltersTabOrgId;
String? lastShelterFromSheltersTabName;
/// When user long-presses zip on adoption list to clear it, call this to also reset Fit/Personality Fit onboarding. Set by HomeScreen.
Future<void> Function()? onClearFitOnboarding;
int distance = 1000;
int updatedSince = 4;
List<String> listOfFavorites = [];

class FelineFinderServer {
  static final FelineFinderServer _instance = FelineFinderServer._();

  /// Canonical zip code (in-memory). Load via [loadZipCodeFromPrefs], set via [setZipCode].
  String zip = "?";

  FelineFinderServer._();

  static FelineFinderServer get instance => _instance;

  /// SharedPreferences key for zip code. All zip reads/writes go through this server.
  static const String zipCodePrefsKey = 'zipCode';

  /// Load zip from SharedPreferences into [zip]. Call at app start or when screen needs current value.
  Future<void> loadZipCodeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(zipCodePrefsKey);
      if (saved != null && saved.trim().isNotEmpty && saved.trim().length == 5) {
        zip = saved.trim();
      }
    } catch (e) {
      // ignore: avoid_print
      print('loadZipCodeFromPrefs failed: $e');
    }
  }

  /// Save zip to memory and SharedPreferences. Use this for all zip code writes.
  Future<void> setZipCode(String newZip) async {
    final z = newZip.trim();
    if (z.isEmpty) return;
    zip = z.length > 5 ? z.substring(0, 5) : z;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(zipCodePrefsKey, zip);
    } catch (e) {
      // ignore: avoid_print
      print('setZipCode failed: $e');
    }
  }

  /// Clear stored zip (memory and SharedPreferences). Use when user explicitly clears location.
  Future<void> clearZipCode() async {
    zip = '?';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(zipCodePrefsKey);
    } catch (e) {
      // ignore: avoid_print
      print('clearZipCode failed: $e');
    }
  }

  final _sliderValue = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  List<int> get sliderValue => _sliderValue;

  /// PersonalityFit screen uses its own slider storage so it doesn't conflict with Fit.
  /// Persisted to SharedPreferences when set; loaded at app start.
  static const String _kPersonalityFitSlidersKey = 'personality_fit_slider_values';
  final Map<int, int> _personalityFitSliderValue = {};

  int getPersonalityFitSliderValue(int questionId) =>
      _personalityFitSliderValue[questionId] ?? 0;

  void setPersonalityFitSliderValue(int questionId, int value) {
    _personalityFitSliderValue[questionId] = value;
    _persistPersonalityFitSliders();
  }

  /// Persist current fit-screen slider values to SharedPreferences (call when user leaves fit screen).
  void savePersonalityFitSlidersToPrefs() => _persistPersonalityFitSliders();

  /// Load saved fit-screen slider values from SharedPreferences (call at app start).
  Future<void> loadPersonalityFitSlidersFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kPersonalityFitSlidersKey);
      if (json == null || json.isEmpty) return;
      final decoded = jsonDecode(json) as Map<String, dynamic>?;
      if (decoded == null) return;
      for (final e in decoded.entries) {
        final id = int.tryParse(e.key);
        if (id != null && e.value is int) {
          _personalityFitSliderValue[id] = e.value as int;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('loadPersonalityFitSlidersFromPrefs failed: $e');
    }
  }

  void _persistPersonalityFitSliders() {
    Future<void> _save() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final map = <String, dynamic>{
          for (final e in _personalityFitSliderValue.entries) e.key.toString(): e.value,
        };
        await prefs.setString(_kPersonalityFitSlidersKey, jsonEncode(map));
      } catch (e) {
        // ignore: avoid_print
        print('_persistPersonalityFitSliders failed: $e');
      }
    }
    _save();
  }

  /// User's selected personality cat type on search screen (e.g. "Lap Legend").
  /// When set, adoption list shows this type for cats that score "above great" (>= 85%) for it.
  String? _selectedPersonalityCatTypeName;
  String? get selectedPersonalityCatTypeName => _selectedPersonalityCatTypeName;
  void setSelectedPersonalityCatTypeName(String? name) {
    _selectedPersonalityCatTypeName = name;
  }

  /// Last user trait profile used for fit scoring on the adoption list (from search sliders or selected cat type).
  /// Pet detail page uses this for the "My Type" bar chart so the graph reflects the search filters.
  Map<String, int>? _lastSearchUserTraitProfile;
  Map<String, int>? get lastSearchUserTraitProfile => _lastSearchUserTraitProfile;
  void setLastSearchUserTraitProfile(Map<String, int>? profile) {
    _lastSearchUserTraitProfile = profile != null && profile.isNotEmpty ? Map.from(profile) : null;
  }

  /// Personality fit scores (cat type id -> percent match) computed at app start after loading sliders.
  /// Used by Personality Fit screen to show cat type cards with correct order and match %.
  Map<int, double>? _lastPersonalityFitScores;
  Map<int, double>? get lastPersonalityFitScores => _lastPersonalityFitScores;
  void setLastPersonalityFitScores(Map<int, double>? scores) {
    _lastPersonalityFitScores = scores != null ? Map<int, double>.from(scores) : null;
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

  Future<void> favoritePet(String userID, String petID) async {
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
      rethrow;
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
      // Support both 'PetIDs' (current) and 'favorites' (legacy) and null-safe
      final raw = myMap['PetIDs'] ?? myMap['favorites'];
      List<String> currentArray =
          raw != null ? List<String>.from(raw as List) : [];
      return currentArray;
    } catch (e) {
      print("Error getting favorites: $e");
      return [];
    }
  }

  Future<void> unfavoritePet(String userID, String petID) async {
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
      rethrow;
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
