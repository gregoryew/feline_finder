library felinefinderapp.globals;

import 'dart:convert';

import 'package:http/http.dart' as http;

import "package:firebase_auth/firebase_auth.dart";
import 'package:cloud_firestore/cloud_firestore.dart';

class FelineFinderServer {
  late String _userID;

  Future<String> getUser() async {
    print("getUser called");
    // Use Firebase Auth UID instead of UUID
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        // Sign in anonymously if no user
        try {
          print("No auth user, signing in anonymously");
          final userCredential =
              await FirebaseAuth.instance.signInAnonymously();
          _userID = userCredential.user!.uid;
          print("Signed in anonymously with UID: $_userID");
        } catch (e) {
          print("Error signing in anonymously: $e");
          // Return a fallback UID if anonymous sign-in fails
          _userID = "fallback-${DateTime.now().millisecondsSinceEpoch}";
          print("Using fallback UID: $_userID");
        }
      } else {
        _userID = authUser.uid;
        print("Using existing auth user UID: $_userID");
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
      // Return a fallback UID if everything fails
      _userID = "fallback-${DateTime.now().millisecondsSinceEpoch}";
      print("Using fallback UID after error: $_userID");
      return _userID;
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
