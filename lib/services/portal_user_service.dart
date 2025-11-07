import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import "package:firebase_auth/firebase_auth.dart";
import 'package:cloud_firestore/cloud_firestore.dart';

class PortalUserService {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  late String _userID;

  Future<String> getUser() async {
    print("PortalUserService.getUser called");
    final SharedPreferences prefs = await _prefs;
    if (prefs.containsKey('uuid')) {
      print("got userid");
      _userID = (prefs.getString('uuid') ?? "");
    } else {
      print("created userid");
      var userID = FirebaseAuth.instance.currentUser?.uid ?? "";
      prefs.setString("uuid", userID);
      createUser(userID, "portal_user", "portal_password");
    }
    return _userID;
  }

  void createUser(String userID, String userName, String password) async {
    // Use shelter_people collection for portal users
    final CollectionReference users =
        FirebaseFirestore.instance.collection("shelter_people");
    await users.add({
      "UID": userID,
      "Created": DateTime.now(),
      "LastLoggedIn": DateTime.now(),
      "userType": "portal_user"
    });
  }

  void favoritePet(String userID, String petID) async {
    print("PortalUserService.favoritePet called");
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
    print("PortalUserService.isFavorite called");
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
    print("PortalUserService.unfavorite pet called");
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
