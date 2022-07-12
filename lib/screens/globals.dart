library felinefinderapp.globals;

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/searchPageConfig.dart';
import '../models/zippopotam.dart';
import 'package:get/get.dart';

const serverName = "stingray-app-uadxu.ondigitalocean.app";

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

  Future<String> getUser() async {
    print("getUser called");
    final SharedPreferences prefs = await _prefs;
    if (prefs.containsKey('uuid')) {
      print("got userid");
      _userID = (prefs.getString('uuid') ?? "");
    } else {
      print("created userid");
      var userID = const Uuid();
      _userID = userID.v1();
      prefs.setString("uuid", _userID);
      createUser(_userID, "greg5", "password5");
    }
    return _userID;
  }

  void createUser(String userID, String userName, String password) async {
    print("createUser called");
    print("https://$serverName/addUser/");
    var response = await http.post(
      Uri.parse('https://$serverName/addUser/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'userid': userID,
        'username': userName,
        'password': password
      }),
    );
    if (response.statusCode == 200) {
      print("addUser success");
    } else {
      print(response.toString());
      print("addUser failed");
    }
  }

  void favoritePet(String userID, String petID) async {
    print("favoritePet called");
    print("-------------https://${serverName}/favorite/");
    var response2 = await http.post(
      Uri.parse('https://${serverName}/favorite/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{'userid': userID, 'petid': petID}),
    );
    print(response2.statusCode);
    if (response2.statusCode == 200) {
      print("favorite SUCCESS");
    } else {
      print(response2.toString());
      print("favoritePet FAILED");
    }
  }

  Future<bool> isFavorite(String userID, String petID) async {
    print("isFavorite called");
    print("https://$serverName/isFavorite/");
    var response = await http.post(Uri.parse('https://$serverName/isFavorite/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{'userid': userID, 'petid': petID}));
    int statusCode = response.statusCode;
    if (statusCode != 200) {
      throw Exception("BAD statusCode: $statusCode");
    }
    String responseBody = response.body;
    var dataList = jsonDecode(responseBody);
    if (dataList.isEmpty) {
      throw Exception("isFavorite returned unknown data");
    } else {
      print("***************isFavorite=" + dataList["IsFavorite"].toString());
      return dataList["IsFavorite"];
    }
  }

  Future<List<String>> getFavorites(String userID) async {
    print("getFavorites called");
    print("https://$serverName/getFavorites?userid=$userID");
    var response = await http.get(
        Uri.parse('https://$serverName/getFavorites?userid=$userID'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        });
    int statusCode = response.statusCode;
    if (statusCode != 200) {
      throw Exception("BAD statusCode: $statusCode");
    }
    String responseBody = response.body;
    var dataList = jsonDecode(responseBody);
    if (dataList.isEmpty) {
      throw Exception("isFavorite returned unknown data");
    } else {
      print("***************isFavorite=" + dataList["Favorites"].toString());
      return dataList["Favorites"].toString().split(",");
    }
  }

  void unfavoritePet(String userID, String petID) async {
    print("unfavorite pet called");
    print("https://$serverName/unfavorite/");
    var response = await http.post(
      Uri.parse("https://$serverName/unfavorite/"),
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

  Future<bool?> isZipCodeValid(String zipCode) async {
    var url = "https://api.zippopotam.us/us/${zipCode}";

    print("URL = $url");

    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var places = Zippopotam.fromJson(jsonDecode(response.body));
        return places.toString() != "{}";
      } else {
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
        //throw Exception('Failed to validate zip code ' + response.body);
      }
    } catch (e) {
      return false;
    }
  }
}
