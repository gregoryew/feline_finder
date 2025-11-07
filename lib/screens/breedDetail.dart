import 'dart:convert';
//import 'dart:html';
import 'package:catapp/models/rescuegroups_v5.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catapp/screens/petDetail.dart';
import '/models/breed.dart';
import '/models/question.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import '/models/playlist.dart';
import '/widgets/playlist-row.dart';
import '/utils/constants.dart';
import '/models/wikipediaExtract.dart';
import '../config.dart';
import 'globals.dart' as globals;
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import 'package:get/get.dart';
import 'package:outlined_text/outlined_text.dart';
import 'package:linkfy_text/linkfy_text.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _BreedDetailState extends State<BreedDetail> {
  WidgetMarker selectedWidgetMarker = WidgetMarker.info;
  late String BreedDescription = "";
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
    () async {
      setState(() {
        rescueGroupApi = AppConfig.rescueGroupsApiKey;
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

    print("***********BreedID = $breedID");

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
      throw Exception('Failed to load pet ${response.body}');
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
      print("response.statusCode = ${response.statusCode}");
      throw Exception(
          'Failed to load wikipedia breed description ${response.body}');
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

  Future<void> _onOpen(String link) async {
    var l = Uri.parse((!link.startsWith("http") ? "http://" : "") + link);
    if (await canLaunchUrl(l)) {
      await launchUrl(l);
    } else {
      throw 'Could not launch $link';
    }
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
              // 4 - Breed Image with modern styling
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image(
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitHeight,
                    image: AssetImage(
                        'assets/Full/${widget.breed.fullSizedPicture.replaceAll(' ', '_')}.jpg'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Breed name with modern card styling matching petDetail
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pets,
                        color: Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.breed.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Button grid with modern styling
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
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
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: index == hilightedCell
                              ? const Color(0xFF2196F3).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: index == hilightedCell
                              ? Border.all(
                                  color: const Color(0xFF2196F3),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Image(
                              width: 30,
                              fit: BoxFit.fitWidth,
                              image:
                                  AssetImage("assets/Icons/${icons[index]}")),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Cats subpage with modern styling
              Visibility(
                visible: selectedWidgetMarker == WidgetMarker.adopt,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: (tiles.isEmpty)
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "No Cats Returned.",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 3 / 4,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12),
                          itemCount: tiles.length,
                          itemBuilder: (BuildContext context, int index) {
                            return GestureDetector(
                              onTap: () => {
                                Get.to(() =>
                                    petDetail(tiles[index].id.toString())),
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image(
                                        image: NetworkImage(
                                            tiles[index].picture ?? ""),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Icon(Icons.pets,
                                                size: 50,
                                                color: Colors.grey[600]),
                                          );
                                        },
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.7),
                                              ],
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: OutlinedText(
                                            text: Text(
                                              tiles[index].name ??
                                                  "Unknown Name",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            strokes: [
                                              OutlinedTextStroke(
                                                  color: Colors.black,
                                                  width: 4),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              // YouTube videos subpage with modern styling
              Visibility(
                visible: selectedWidgetMarker == WidgetMarker.videos,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: (playlists.isEmpty)
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "No Cat Videos Available.",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            separatorBuilder: (context, index) => Divider(
                              thickness: 1.0,
                              color: Colors.grey[200],
                            ),
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: PlaylistRow(
                                  displayDescription: false,
                                  playlist: playlists[index],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
              // Fit/Stats subwindow with modern styling
              Visibility(
                visible: selectedWidgetMarker == WidgetMarker.stats,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics_outlined,
                              color: Color(0xFF2196F3),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "Breed Traits & Fit",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2196F3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          "🟢 User Pref 🔵 Cat Trait  🎯 Bullseye",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        separatorBuilder: (context, index) => Divider(
                          thickness: 1.0,
                          color: Colors.grey[200],
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
                                  child: Text(statPrecentage ==
                                              userPreference &&
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
                  ),
                ),
              ),
              // Wikipedia info subpage with modern styling
              Visibility(
                visible: selectedWidgetMarker == WidgetMarker.info,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: textBox(widget.breed.name, BreedDescription),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget textBox(String title, String textBlock) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFF2196F3),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinkifyText(
                    textBlock.isEmpty
                        ? "Loading breed information..."
                        : textBlock,
                    textAlign: TextAlign.left,
                    textStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    linkTypes: const [LinkType.email, LinkType.url],
                    linkStyle: const TextStyle(
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    onTap: (link) => _onOpen(link.value!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
