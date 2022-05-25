library felinefinderapp.globals;
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class FelineFinderServer {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  late Future<Uuid> _userID;
  Future<Uuid> getUser() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.containsKey('uuid')) { 
      _userID = Uuid.parse((prefs.getString('uuid') ?? "")) as Future<Uuid>;
    } else {
      var userID = const Uuid();
      _userID = userID.v1() as Future<Uuid>;
      prefs.setString("uuid", _userID.toString());
      createUser(_userID.toString(), "greg5", "password5");
    }
    return _userID;
  }

  Future<http.Response> createUser(String userID, String userName, String password) {
  return http.post(
    Uri.parse('https://localhost:3000/addUser/'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'userid': userID,
      'username': userName,
      'password': password
    }),
  );
  }

  Future<http.Response> favoritePet(String userID, String petID) {
    return http.post(
    Uri.parse('https://localhost:3000/favoritePet/'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'userid': userID,
      'petid': petID
    }),
  );
  }

  Future<bool> isFavorite(String userID, String petID) async {
    var response = await http.post(
    Uri.parse('https://localhost:3000/isFavorite/'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'userid': userID,
      'petid': petID
    }));
    int statusCode = response.statusCode;
    if (statusCode != 200) {throw Exception("BAD statusCode: $statusCode");}
    String responseBody = response.body;
    final List<dynamic> dataList = jsonDecode(responseBody);
    if (dataList.isEmpty) {
      throw Exception("isFavorite returned unknown data");
    } else {
      return dataList[0]["isFavorite"];
    }
  }

  Future<http.Response> unfavoritePet(String userID, String petID) {
    return http.post(
    Uri.parse('https://localhost:3000/unfavoritePet/'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'userid': userID,
      'petid': petID
    }),
  );
  }
}



