library felinefinderapp.globals;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/searchPageConfig.dart';
import '../models/zippopotam.dart';
import 'package:get/get.dart';
import '../ExampleCode/RescueGroupsQuery.dart';

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
    final lines = await rootBundle.loadString(assetsFileName);
    Map<String, String> environment = {};
    for (String line in lines.split('\n')) {
      line = line.trim();
      if (line.contains('=') //Set Key Value Pairs on lines separated by =
          &&
          !line.startsWith(RegExp(r'=|#'))) {
        //No need to add emty keys and remove comments
        List<String> contents = line.split('=');
        environment[contents[0]] = contents.sublist(1).join('=');
      }
    }
    return environment;
  }

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

  Future<List<String>> getQueries(String userID) async {
    print("getFavorites called");
    print("https://$serverName/getQueries?userid=$userID");
    var response = await http.get(
        Uri.parse('https://$serverName/getQueries?userid=$userID'),
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
      throw Exception("getQueries returned unknown data");
    } else {
      print("***************getQueries=" + dataList["Queries"].toString());
      if (dataList["Queries"].toString() == "null") {
        return [];
      } else {
        return dataList["Queries"].toString().split(",");
      }
    }
  }

  Future<RescueGroupsQuery?> getQuery(String userID, String filterName) async {
    if (filterName == "New") {
      return RescueGroupsQuery.fromJson(jsonDecode(""));
    }
    print("loadFilter called");
    print("https://$serverName/getQuery?userid=$userID&name=$filterName");
    var response = await http.get(
        (Uri.parse(Uri.encodeFull(
            'https://$serverName/getQuery?userid=$userID&name=$filterName'))),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        });
    int statusCode = response.statusCode;
    if (statusCode != 200) {
      throw Exception("BAD statusCode: $statusCode");
    } else {
      var query = jsonDecode(response.body);
      sortMethod =
          query['sort'] == 0 ? "-animals.updatedDate" : "animals.distance";
      distance = query['distance'];
      updatedSince = query['updated_since'];
      return RescueGroupsQuery.fromJson(jsonDecode(query['Query']));
    }
  }

  Future<bool> saveFilter(
      String userID, String filterName, Object filter) async {
    print("saveFilter called");
    print("https://$serverName/insertQuery/");
    var json = jsonEncode(<String, dynamic>{
      'userid': userID,
      'name': filterName,
      'query': filter,
      'sort': (sortMethod == "animals.distance" ? 1 : 0),
      'distance': distance,
      'updated_since': updatedSince
    });
    var response = await http.post(
      Uri.parse('https://$serverName/insertQuery/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: json,
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> deleteQuery(String userID, String query) async {
    print("deleteQuery called");
    print("https://$serverName/deleteQuery?userid=$userID&name=$query");
    var response = await http.delete(Uri.parse(Uri.encodeFull(
        'https://$serverName/deleteQuery?userid=$userID&name=$query')));
    int statusCode = response.statusCode;
    if (statusCode != 200) {
      throw Exception("BAD statusCode: $statusCode");
    }
    return true;
  }
}
