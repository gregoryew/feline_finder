import 'dart:convert';
//import 'dart:html';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:recipes/screens/petDetail.dart';
import 'package:transparent_image/transparent_image.dart';
import '/models/breed.dart';
import '/models/question.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import '/models/playlist.dart';
import '/widgets/playlist-row.dart';
import '/utils/constants.dart';
import '/models/wikipediaExtract.dart';
import 'globals.dart' as globals;
import '/ExampleCode/RescueGroups.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import 'package:get/get.dart';
import 'package:outlined_text/outlined_text.dart';

enum WidgetMarker { adopt, videos, stats, info }

class BreedDetail extends StatefulWidget {
  final Breed breed;

  const BreedDetail({
    Key? key,
    required this.breed,
  }) : super(key: key);

  @override
  _BreedDetailState createState() {
    return _BreedDetailState();
  }
}

enum BarType { traitBar, percentageBar, backgroundBar }

class _BreedDetailState extends State<BreedDetail>
    with SingleTickerProviderStateMixin<BreedDetail> {
  WidgetMarker selectedWidgetMarker = WidgetMarker.info;
  late String BreedDescription = "";
  late AnimationController _controller;
  late Animation<double> _animation;
  List<Playlist> playlists = [];
  final maxValues = [5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 11, 6, 3, 12];

  String url = "";
  double progress = 0;

  int maxPets = -1;
  int loadedPets = 0;
  int tilesPerLoad = 100;

  List<PetTileData> tiles = [];

  String? rescueGroupApi = "";

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller);
    Map<String, String>? mapKeys;
    () async {
      mapKeys = await globals.FelineFinderServer.instance
          .parseStringToMap(assetsFileName: '.env');
      setState(() {
        rescueGroupApi = mapKeys!["RescueGroupsAPIKey"];
        getPlaylists();
        getBreedDescription(widget.breed.htmlUrl);
        getPets(widget.breed.rid.toString());
      });
    }();
  }

  void getPets(String breedID) async {
    print('Getting Pets');

    int currentPage = ((loadedPets + tilesPerLoad) / tilesPerLoad).floor();
    loadedPets += tilesPerLoad;
    var url =
        "https://api.rescuegroups.org/v5/public/animals/search/available/haspic?fields[animals]=sizeGroup,ageGroup,sex,distance,id,name,breedPrimary,updatedDate,status,descriptionHtml,descriptionText&limit=100&page=$currentPage";

    print("***********BreedID = " + breedID);

    Map<String, dynamic> data = {
      "data": {
        "filterRadius": {"miles": 1000, "postalcode": "94043"},
        "filters": [
          {
            "fieldName": "species.singular",
            "operation": "equal",
            "criteria": "cat"
          },
          {
            "fieldName": "animals.breedPrimaryId",
            "operation": "equal",
            "criteria": breedID
          }
        ]
      }
    };

    var data2 = RescueGroupsQuery.fromJson(data);

    var response = await http.post(Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': rescueGroupApi!
        },
        body: json.encode(data2.toJson()));

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");
      var json = jsonDecode(response.body);
      var meta = Meta.fromJson(json["meta"]);
      if (meta.count == 0) {
        maxPets = 0;
        tiles = [];
        return;
      }
      pet petDecoded = petFromJson(response.body);
      if (maxPets == -1) {
        maxPets = (petDecoded.meta?.count ?? 0);
      }
      setState(() {
        petDecoded.data?.forEach((petData) {
          tiles.add(PetTileData(petData, petDecoded.included!));
        });
      });
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load pet ' + response.body);
    }
  }

  Future<void> getBreedDescription(String breedName) async {
    var url =
        "https://en.wikipedia.org/w/api.php?action=query&prop=extracts&explaintext&format=json&titles=$breedName";

    print("URL = $url");

    var response = await http.get(Uri.parse(url), headers: {
      'Content-Type': 'application/json;charset=UTF-8',
      'Charset': 'utf-8'
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");
      var json = convert.jsonDecode(response.body);
      var BreedDescriptionObj = WikipediaTextExtract.fromJson(json);
      setState(() {
        BreedDescription =
            BreedDescriptionObj.query!.pages!.page?.extract ?? "";
      });
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      print("response.statusCode = " + response.statusCode.toString());
      throw Exception(
          'Failed to load wikipedia breed description ' + response.body);
    }
  }

  Future<void> getPlaylists() async {
    final String url =
        'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=49&playlistId=${widget.breed.playListID}&key=${Constants.YOU_TUBE_API_KEY}';
    Uri u = Uri.parse(url);
    var response = await http.get(u);
    if (response.statusCode == 200) {
      var jsonResponse = convert.jsonDecode(response.body);
      setState(() {
        playlists = jsonResponse['items'].map<Playlist>((item) {
          return Playlist.fromJson(item);
        }).toList();
        playlists.removeWhere((x) => x.title == "Private video");
      });
    } else {
      print('I should handle this error better: ${response.statusCode}.');
    }
  }

  List<String> icons = [
    "adopt_icon.png",
    "youtube_icon.png",
    "stats_icon.png",
    "info_icon.png"
  ];
  int hilightedCell = 3;
  List<WidgetMarker> selectedIcon = [
    WidgetMarker.adopt,
    WidgetMarker.videos,
    WidgetMarker.stats,
    WidgetMarker.info
  ];

  Widget bar(double percentage, BarType barType) {
    List<Color> barColors = [];
    switch (barType) {
      case BarType.backgroundBar:
        barColors.add(Colors.grey[500]!);
        barColors.add(Colors.grey[500]!);
        break;
      case BarType.traitBar:
        barColors.add(const Color.fromARGB(255, 181, 234, 73));
        barColors.add(const Color.fromARGB(255, 134, 209, 63));
        break;
      case BarType.percentageBar:
        barColors.add(const Color.fromARGB(255, 108, 195, 245));
        barColors.add(const Color.fromARGB(255, 73, 147, 235));
        break;
    }
    return Container(
      width: MediaQuery.of(context).size.width * percentage,
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: barColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [
              0.1,
              0.5,
            ],
          ),
          borderRadius: BorderRadius.circular(20)),
      child: const SizedBox(
        height: 40.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.breed.name),
      ),
      // 2
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: <Widget>[
              // 4
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image(
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitHeight,
                    image: AssetImage(
                        'assets/Full/${widget.breed.fullSizedPicture.replaceAll(' ', '_')}.jpg'),
                  )),
              const SizedBox(
                height: 4,
              ),
              // 6
              const SizedBox(height: 30),
              SizedBox(
                height: 70,
                width: MediaQuery.of(context).size.width,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromARGB(184, 111, 97, 97)),
                      color: const Color.fromARGB(255, 225, 215, 215),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(20))),
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    widget.breed.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // 5
              const SizedBox(height: 30),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, childAspectRatio: 4 / 3),
                itemCount: 4,
                itemBuilder: (BuildContext context, int index) {
                  return GestureDetector(
                    onTap: () => {
                      setState(
                        () {
                          hilightedCell = index;
                          selectedWidgetMarker = selectedIcon[index];
                        },
                      ),
                    },
                    child: Card(
                      color: index == hilightedCell
                          ? Color.fromARGB(255, 220, 219, 219)
                          : Colors.white,
                      child: Center(
                        child: Image(
                            width: 30,
                            fit: BoxFit.fitWidth,
                            image: AssetImage("assets/Icons/${icons[index]}")),
                      ),
                    ),
                  );
                },
              ),
              Visibility(
                visible: selectedWidgetMarker == WidgetMarker.adopt,
                child: (tiles.isEmpty)
                    ? const Center(child: Text("No Cats Returned."))
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, childAspectRatio: 3 / 4),
                        itemCount: tiles.length,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () => {
                              Get.to(
                                  () => petDetail(tiles[index].id.toString())),
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                  image: DecorationImage(
                                      image: NetworkImage(
                                          tiles[index].picture ?? ""),
                                      fit: BoxFit.fill)),
                              child: Align(
                                child: OutlinedText(
                                  text: Text(
                                    tiles[index].name ?? "Unknown Name",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  strokes: [
                                    OutlinedTextStroke(
                                        color: Colors.black, width: 4),
                                  ],
                                ),
                                alignment: Alignment.bottomCenter,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Visibility(
                visible: selectedWidgetMarker == WidgetMarker.videos,
                child: (playlists.isEmpty)
                    ? const Center(child: Text("No Cat Vidoes Available."))
                    : ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        separatorBuilder: (context, index) => Divider(
                          thickness: 2.0,
                        ),
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          return PlaylistRow(
                            displayDescription: false,
                            playlist: playlists[index],
                          );
                        },
                      ),
              ),
              Visibility(
                visible: selectedWidgetMarker == WidgetMarker.stats,
                child: (Column(
                  children: [
                    const Center(
                        child: Text("🟢 User Pref 🔵 Cat Trait  🎯 Bullseye",
                            textAlign: TextAlign.center)),
                    const SizedBox(height: 20),
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      separatorBuilder: (context, index) => const Divider(
                        thickness: 2.0,
                        color: Colors.white,
                      ),
                      itemCount: widget.breed.stats.length,
                      itemBuilder: (context, index) {
                        var statPrecentage =
                            (widget.breed.stats[index].isPercent)
                                ? widget.breed.stats[index].value.toDouble() /
                                    maxValues[index].toDouble()
                                : 1.0;
                        var userPreference =
                            (widget.breed.stats[index].isPercent)
                                ? globals.FelineFinderServer.instance
                                        .sliderValue[index] /
                                    maxValues[index].toDouble()
                                : 1.0;
                        if (statPrecentage < userPreference) {
                          return Stack(
                            //alignment:new Alignment(x, y)
                            children: <Widget>[
                              bar(1, BarType.backgroundBar),
                              bar(userPreference, BarType.percentageBar),
                              Positioned(
                                child: bar(statPrecentage, BarType.traitBar),
                              ),
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    "         " +
                                        widget.breed.stats[index].name +
                                        ': ' +
                                        Question
                                            .questions[index]
                                            .choices[widget
                                                .breed.stats[index].value
                                                .toInt()]
                                            .name,
                                    style: const TextStyle(
                                        fontSize: 16.0,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Stack(
                            children: <Widget>[
                              bar(100, BarType.backgroundBar),
                              bar(statPrecentage, BarType.percentageBar),
                              Positioned(
                                child: bar(userPreference, BarType.traitBar),
                              ),
                              Positioned(
                                left: 13,
                                top: 4,
                                child: Text(statPrecentage == userPreference &&
                                        (widget.breed.stats[index].isPercent)
                                    ? "🎯"
                                    : ""),
                              ),
                              Positioned.fill(
                                child: Row(
                                  children: <Widget>[
                                    Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "         " +
                                            widget.breed.stats[index].name +
                                            ': ' +
                                            Question
                                                .questions[index]
                                                .choices[widget
                                                    .breed.stats[index].value
                                                    .toInt()]
                                                .name,
                                        style: const TextStyle(
                                            fontSize: 16.0,
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                )),
              ),
              Visibility(
                  visible: selectedWidgetMarker == WidgetMarker.info,
                  child: Container(
                      child: textBox(widget.breed.name, BreedDescription))),
            ],
          ),
        ),
      ),
    );
  }

  Widget textBox(String title, String textBlock) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(184, 111, 97, 97)),
            color: const Color.fromARGB(255, 225, 215, 215),
            borderRadius: const BorderRadius.all(Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey),
              textAlign: TextAlign.left,
            ),
            Divider(
              thickness: 1,
              color: Colors.grey[100],
            ),
            Text(textBlock),
          ],
        ),
      ),
    );
  }
}
