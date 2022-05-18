import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/ExampleCode/RescueGroups.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import '/screens/petDetail.dart';
import 'package:transparent_image/transparent_image.dart';

class AdoptGrid extends StatefulWidget {

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  @override
  AdoptGridState createState() {
    return AdoptGridState();
  }
}

class AdoptGridState extends State<AdoptGrid> {
  List<PetTileData> tiles = [];
  int maxPets = -1;
  int loadedPets = 0;
  int tilesPerLoad = 25;
  late ScrollController controller;

@override
void initState() {
  super.initState();
  controller = ScrollController()..addListener(_scrollListener);
  getPets();
}

  void _scrollListener() {
    if (controller.position.extentAfter < 500) {
      setState(() {
        if (loadedPets < maxPets) {getPets();}
      });
    }
  }

   void getPets() async {
    print('Getting Pets');

    int currentPage = ((loadedPets+tilesPerLoad)/tilesPerLoad).floor();
    loadedPets += tilesPerLoad;
    var url = "https://api.rescuegroups.org/v5/public/animals/search/available/haspic?fields[animals]=distance,id,ageGroup,sex,sizeGroup,name,breedPrimary,updatedDate,status&limit=25&page=$currentPage";

    Map<String, dynamic> data = {
    "data": {
      "filterRadius": {
        "miles": 1000,
        "postalcode": "94043"
      },
      "filters":
        [
          {
            "fieldName" : "species.singular",
            "operation" : "equal",
            "criteria" : "cat"
          }
        ]
    }
  };

  var data2 = RescueGroupsQuery.fromJson(data);

  var response = await http.post(Uri.parse(url),
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': '0doJkmYU'
    },
    body: json.encode(data2.toJson())
  );

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    print("status 200");
    var petDecoded = pet.fromJson(jsonDecode(response.body));
    if (maxPets == -1) {maxPets = (petDecoded.meta?.count ?? 0);}
    setState(() {
      petDecoded.data?.forEach((petData) {
        tiles.add(PetTileData(petData, petDecoded.included!));
      });
    });
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load pet ' + response.body );
  }
   }

 @override
  void dispose() {
    controller.removeListener(_scrollListener);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MasonryGridView.count(
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
  return  GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => petDetail(tiles[index].id!)));
                            }, child: petCard(tiles[index])
                          );
                        }
                      )
                    );
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
    height: (tile.resolutionY == 0 ? 100 : tile.resolutionY!) + 176,
    width: 200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            child:ClipRRect(
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
                )
              //(tile == null || tile.picture == null || tile.picture == "") ? Image(image: AssetImage("assets/Icons/No_Cat_Image.png"), width: 200, fit: BoxFit.fitWidth) : Image(image: NetworkImage(tile.picture ?? ""), width: 200, fit: BoxFit.fitWidth),
              ),
            ),
          ),
        Container(
          height: 2,
          color: Colors.black,
        ),
        Container(
          height: 130,
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
                tile.name ?? "No Name",
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
              Text(
                (tile.status ?? "") + " | " + (tile.age ?? "") + " | " + (tile.sex ?? "") + " | " + (tile.size ?? "") + " | " + (tile.cityState ?? ""),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  )
  );
}
}