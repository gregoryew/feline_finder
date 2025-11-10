library felinefinderapp.globals;

import 'dart:convert';

import 'package:http/http.dart' as http;

import "package:firebase_auth/firebase_auth.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FelineFinderServer {
  late String _userID;

  Future<String> getUser() async {
    print("getUser called");
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

      // Create or update adopter document using UID as document ID
      try {
        await createUser(_userID);
      } catch (e) {
        print("Error creating user document: $e");
        // Continue even if Firestore fails
      }
      return _userID;
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
  }

  Future<void> createUser(String userID) async {
    // Use UID as document ID instead of adding to collection
    final docRef =
        FirebaseFirestore.instance.collection("adopters").doc(userID);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      // Update last login
      await docRef.update({"LastLoggedIn": DateTime.now()});
    } else {
      // Create new adopter document
      await docRef.set({
        "UID": userID,
        "Created": DateTime.now(),
        "LastLoggedIn": DateTime.now()
      });
    }
  }

  void favoritePet(String userID, String petID) async {
    print("favoritePet called");
    var response2 = await http.post(
      Uri.parse('https://octopus-app-s7q5v.ondigitalocean.app/favoritePet/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{'userid': userID, 'petid': petID}),
    );
    print(response2.statusCode);
    print(response2.body);
    print(userID);
    print(petID);
    if (response2.statusCode == 200) {
      print("favoritePet success");
    } else {
      print(response2.toString());
      print("favoritePet failed");
    }
  }

  Future<bool> isFavorite(String userID, String petID) async {
    print("isFavorite called");
    var response = await http.post(
        Uri.parse('https://octopus-app-s7q5v.ondigitalocean.app/isFavorite/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{'userid': userID, 'petid': petID}));
    int statusCode = response.statusCode;
    if (statusCode != 200) {
      throw Exception("BAD statusCode: $statusCode");
    }
    String responseBody = response.body;
    final List<dynamic> dataList = jsonDecode(responseBody);
    if (dataList.isEmpty) {
      throw Exception("isFavorite returned unknown data");
    } else {
      return dataList[0]["isFavorite"];
    }
  }

  void unfavoritePet(String userID, String petID) async {
    print("unfavorite pet called");
    var response = await http.post(
      Uri.parse('https://octopus-app-s7q5v.ondigitalocean.app/unfavoritePet/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{'userid': userID, 'petid': petID}),
    );
    if (response.statusCode == 200) {
      print("favoritePet success");
    } else {
      print(response.toString());
      print("favoritePet failed");
    }
  }
}
