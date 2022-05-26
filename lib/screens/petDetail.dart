import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:like_button/like_button.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../widgets/toolbar.dart';
import '/ExampleCode/RescueGroups.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petDetailData.dart';
import '/models/shelter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../globals.dart';

class petDetail extends StatefulWidget {
  final String petID;
  String userID = "";
  //final server = FelineFinderServer();
  bool isFavorite = false;

  petDetail(this.petID, {Key? key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  @override
  petDetailState createState() {
    return petDetailState();
  }
}

class petDetailState extends State<petDetail> with RouteAware {
  PetDetailData? petDetailInstance;
  Shelter? shelterDetailInstance;
  bool isLiked = false;
  int selectedImage = 0;
  double _height = 20.0;
  late WebViewController _webViewController;

  @override
  void initState() {
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    });
    getPetDetail(widget.petID);
    super.initState();
  }

  @override
  void didPush() {
    print("********* DID PUSH");
    //widget.userID = widget.server.getUser().toString();
    //widget.isFavorite =
    //    widget.server.isFavorite(widget.userID, widget.petID) as bool;

    print('HomePage: Called didPush');
    super.didPush();
  }

  @override
  void didPop() {
    print("******** DID POP");
    //if (widget.isFavorite) {
    //  widget.server.favoritePet(widget.userID, widget.petID);
    //} else {
    //  widget.server.unfavoritePet(widget.userID, widget.petID);
    //}
    print('HomePage: Called didPop');
    super.didPop();
  }

  @override
  void didPopNext() {
    print('HomePage: Called didPopNext');
    super.didPopNext();
  }

  @override
  void didPushNext() {
    print('HomePage: Called didPushNext');
    super.didPushNext();
  }

  void getShelterDetail(String orgID) async {
    var url = "https://api.rescuegroups.org/v5/public/orgs/${orgID}";

    print("URL = $url");

    var response = await http.get(Uri.parse(url), headers: {
      'Content-Type': 'application/json', //; charset=UTF-8',
      'Authorization': '0doJkmYU'
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");
      setState(() {
        shelterDetailInstance = Shelter.fromJson(jsonDecode(response.body));
        loadAsset();
      });
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      print("response.statusCode = " + response.statusCode.toString());
      throw Exception('Failed to load pet ' + response.body);
    }
  }

  void getPetDetail(String petID) async {
    print('Getting Pet Detail');

    String id2 = widget.petID;

    print("id = ${id2}");

    var url =
        "https://api.rescuegroups.org/v5/public/animals/${id2}?fields[animals]=sizeGroup,ageGroup,sex,distance,id,name,breedPrimary,updatedDate,status,descriptionHtml,descriptionText&limit=1&page=1";

    print("URL = $url");

    Map<String, dynamic> data = {
      "data": {
        "filterRadius": {"miles": 1000, "postalcode": "94043"},
        "filters": [
          {
            "fieldName": "species.singular",
            "operation": "equal",
            "criteria": "cat"
          }
        ]
      }
    };

    var data2 = RescueGroupsQuery.fromJson(data);

    var response = await http.get(Uri.parse(url), headers: {
      'Content-Type': 'application/json', //; charset=UTF-8',
      'Authorization': '0doJkmYU'
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");
      var petDecoded = pet.fromJson(jsonDecode(response.body));
      setState(() {
        petDetailInstance = PetDetailData(
            petDecoded.data![0],
            petDecoded.included!,
            petDecoded.data![0].relationships!.values.toList());
        getShelterDetail(petDetailInstance!.organizationID!);
        loadAsset();
      });
      print("********DD = ${petDetailInstance?.smallPictures}");
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      print("response.statusCode = " + response.statusCode.toString());
      throw Exception('Failed to load pet ' + response.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(petDetailInstance?.name ?? ""), actions: <Widget>[
        Padding(
            padding: EdgeInsets.only(right: 10.0),
            child: GestureDetector(
              onTap: () {
                widget.isFavorite = !widget.isFavorite;
              },
              child: LikeButton(
                  size: 40,
                  isLiked: widget.isFavorite,
                  likeBuilder: (isLiked) {
                    final color =
                        widget.isFavorite ? Colors.red : Colors.blueGrey;
                    return Icon(Icons.favorite, color: color, size: 40);
                  }),
            ))
      ]),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Stack(children: <Widget>[
                Align(
                    alignment: FractionalOffset.center,
                    child: getImage(petDetailInstance)),
                Positioned(
                  bottom: 10,
                  left: 0,
                  height: 80,
                  width: MediaQuery.of(context).size.width,
                  child: SizedBox(
                    height: 100,
                    child: Center(
                        child: MasonryGridView.count(
                            scrollDirection: Axis.horizontal,
                            itemCount: petDetailInstance == null
                                ? 0
                                : (petDetailInstance!.smallPictures.length +
                                    petDetailInstance!.videos!.length),
                            padding: const EdgeInsets.symmetric(
                                vertical: 1, horizontal: 3),
                            // the number of columns
                            crossAxisCount: 1,
                            // vertical gap between two items
                            mainAxisSpacing: 7,
                            // horizontal gap between two items
                            crossAxisSpacing: 0,
                            itemBuilder: (context, index) {
                              if (index <
                                  petDetailInstance!.smallPictures.length) {
                                return getSmallImage(petDetailInstance, index);
                              } else {
                                return getVideoImage(petDetailInstance, index);
                              }
                            })),
                  ),
                )
              ]),
              const SizedBox(
                height: 20,
              ),
              Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromARGB(184, 111, 97, 97)),
                      color: Color.fromARGB(255, 225, 215, 215),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(20))),
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Center(
                        child: Text(
                            petDetailInstance == null
                                ? ""
                                : petDetailInstance!.name ?? "",
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                    const Divider(
                      thickness: 1,
                      indent: 30,
                      endIndent: 30,
                    ),
                    Center(
                        child: Text(
                            petDetailInstance == null
                                ? ""
                                : petDetailInstance!.primaryBreed ?? "",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                    const SizedBox(height: 20),
                    getStats(),
                  ])),
              const SizedBox(
                height: 20,
              ),
              Center(
                  child: SizedBox(
                      height: 100,
                      child:
                          Center(child: ToolBar(detail: petDetailInstance)))),
              Container(
                height: _height < 100.0 ? 100.0 : _height,
                color: Colors.deepOrange,
                child: WebView(
                  initialUrl: '',
                  onPageFinished: (some) async {
                    double height = double.parse(
                        await _webViewController.evaluateJavascript(
                            "document.documentElement.scrollHeight;"));
                    setState(() {
                      _height = height;
                    });
                  },
                  javascriptMode: JavascriptMode.unrestricted,
                  onWebViewCreated: (WebViewController webViewController) {
                    _webViewController = webViewController;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getStats() {
    if (petDetailInstance == null) {
      return const SizedBox.shrink();
    }

    List<String> stats = [];
    if (petDetailInstance!.status != null) {
      stats.add(petDetailInstance!.status ?? "");
    }
    if (petDetailInstance!.ageGroup != null) {
      stats.add(petDetailInstance!.ageGroup ?? "");
    }
    if (petDetailInstance!.sex != null) {
      stats.add(petDetailInstance!.sex ?? "");
    }
    if (petDetailInstance!.sizeGroup != null) {
      stats.add(petDetailInstance!.sizeGroup ?? "");
    }
    List<Color> foreground = [
      const Color.fromRGBO(101, 164, 43, 1),
      const Color.fromRGBO(3, 122, 254, 1),
      const Color.fromRGBO(245, 76, 10, 1.0),
      Colors.deepPurple
    ];
    List<Color> background = [
      const Color.fromRGBO(222, 234, 209, 1),
      const Color.fromRGBO(209, 224, 239, 1),
      const Color.fromARGB(255, 246, 193, 167),
      Colors.purpleAccent.shade100
    ];
    return Center(
        child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 10,
                runSpacing: 10,
                direction: Axis.horizontal,
                children: stats.map((item) {
                  return Container(
                      width: 100,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: foreground[stats.indexOf(item)]),
                          color: background[stats.indexOf(item)],
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5))),
                      child: Text(stats[stats.indexOf(item)].trim(),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: foreground[stats.indexOf(item)]),
                          textAlign: TextAlign.center));
                }).toList())));
  }

  void loadAsset() async {
    String addressString = "";
    addressString = "<table>";
    if (petDetailInstance?.organizationName != "") {
      addressString =
          "$addressString<tr><td><b>${petDetailInstance?.organizationName ?? ""}</b></td></tr>";
    }
    if (petDetailInstance?.street != "") {
      addressString =
          "$addressString<tr><td><b>${petDetailInstance?.street ?? ""}</b></td></tr>";
    }
    if (petDetailInstance?.cityState != "") {
      addressString =
          "$addressString<tr><td><b>${petDetailInstance?.cityState ?? ""} ${petDetailInstance?.postalCode ?? ""}</b></td></tr></table>";
    }

    final String description = petDetailInstance?.description ?? "";

    String serveAreas = "Please contact shelter for details.";
    String about = "Please contact shelter for details.";
    String services = "Please contact shelter for details.";
    String adoptionProcess = "Please contact shelter for details.";
    String meetPets = "Please contact shelter for details.";
    String adoptionUrl = "Not Available.";
    String donationUrl = "Not Available.";
    String sponsorshipUrl = "Not Available.";
    String facebookUrl = "Not Available.";
    String rescueOrgID = "?";
    String animalID = "?";

    if (shelterDetailInstance != null &&
        shelterDetailInstance!.data != null &&
        shelterDetailInstance!.data!.isNotEmpty &&
        shelterDetailInstance!.data![0].attributes != null) {
      Attributes detail = shelterDetailInstance!.data![0].attributes!;
      animalID = petDetailInstance?.id ?? "?";
      rescueOrgID = shelterDetailInstance!.data![0].id ?? "?";
      serveAreas = detail.serveAreas ?? "Please contact shelter for details.";
      about = detail.about ?? "Please contact shelter for details.";
      services = detail.services ?? "Please contact shelter for details.";
      adoptionProcess =
          detail.adoptionProcess ?? "Please contact shelter for details.";
      meetPets = detail.meetPets ?? "Please contact shelter for details.";
      facebookUrl = (detail.facebookUrl != null)
          ? "<a href='${detail.facebookUrl}'>${detail.facebookUrl}</a>"
          : "Not Available.";
      adoptionUrl = (detail.adoptionUrl != null)
          ? "<a href='${detail.adoptionUrl}'>${detail.adoptionUrl}</a>"
          : "Not Available.";
      donationUrl = (detail.donationUrl != null)
          ? "<a href='${detail.donationUrl}'>${detail.donationUrl}</a>"
          : "Not Available.";
      sponsorshipUrl = (detail.sponsorshipUrl != null)
          ? "<a href='${detail.sponsorshipUrl}'>${detail.sponsorshipUrl}</a>"
          : "Not Available.";
    }

    String htmlString = '''<html>
                <head>
                      <meta name="viewport" content="width=device-width, initial-scale=1.0">
                      <style>
                          @media {
                              body {
                                  font-size: 5px;
                                  max-width: 520px;
                                  margin: 20px auto;
                              }
                              h1 {color: black;
                                  FONT-FAMILY:Arial,Helvetica,sans-serif;
                                  font-size: 18px;
                              }
                              h2 {color: blue;
                                  FONT-FAMILY:Arial,Helvetica,sans-serif;
                                  font-size: 18px;
                              }
                              h3 {color: blue;
                                  FONT-FAMILY:Arial,Helvetica,sans-serif;
                                  font-size: 18px;}
                              h4 {color: black;
                                  FONT-FAMILY:Arial,Helvetica,sans-serif;
                                  font-size: 12px;}
                              a { color: blue}
                              a.visited {color: grey;}
                          }
                      </style>
                </head>
                <body>
                    <center>
                        <table>
                            <tr>
                                <td width="100%">
                                    <table width="100%">
                                        <tr>
                                            <td>
                                                <center>
                                                    <b>
                                                        <h2><b>GENERAL INFORMATION</h2>
                                                    </b>
                                                </center>
                                            </td>
                                        </tr>
                                    </table>
                                    <table>
                                        <tr>
                                            <td>
                                                <center>
                                                    <h2>CONTACT</h2>
                                                </center>
                                                <h1>
                                                $addressString
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        DESCRIPTION
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        $description
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        IDs
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        <table>
                                                        <tr>
                                                        <td>
                                                        <b>
                                                        Rescue Org ID:
                                                        </b> 
                                                        </td>
                                                        <td align="right">
                                                        <b>
                                                        $rescueOrgID
                                                        </b>
                                                        </td>
                                                        </tr>
                                                        <tr>
                                                        <td>
                                                        <b>
                                                        Animal ID:
                                                        </b>
                                                        </td>
                                                        <td  align="right">
                                                        <b>
                                                        $animalID
                                                        </b>
                                                        </td>
                                                        </tr>
                                                        </table>
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        SERVICE AREAS
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        $serveAreas
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        SERVICES
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        $services
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        ADOPTION PROCESS
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        $adoptionProcess
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        MEET PETS
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        $meetPets
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        ABOUT RESCUE ORGANIZATION
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        $about
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>
                                                        IMPORTANT URLS
                                                    </center>
                                                </h2>
                                                <h1>
                                                    <p style="word-wrap: break-word;">
                                                        <table>
                                                        <tr>
                                                        <td><b>Adoption URL:</b></td><td>$adoptionUrl</td>
                                                        </tr>
                                                        <tr>
                                                        <td><b>Donation URL:</b></td><td>$donationUrl</td>
                                                        </tr>
                                                        <tr>
                                                        <td><b>Sponsorship URL:</b></td><td>$sponsorshipUrl</td>
                                                        </tr>
                                                        <tr>
                                                        <td><b>FaceBook URL:</b></td><td>$facebookUrl</td>
                                                        </tr>
                                                        </table>
                                                    </p>
                                                </h1>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td></td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <h2>
                                                    <center>DISCLAIMER</center>
                                                </h2>
                                                <h4>PLEASE READ: Information regarding adoptable pets is provided by the adoption organization and is neither checked for accuracy or completeness nor guaranteed to be accurate or complete.  The health or status and behavior of any pet found, adopted through, or listed on the Feline Finder app are the sole responsibility of the adoption organization listing the same and/or the adopting party, and by using this service, the adopting party releases Feline Finder and Gregory Edward Williams, from any and all liability arising out of or in any way connected with the adoption of a pet listed on the Feline Finder app.
                                                </h4>
                                            </td>
                                        </tr>
                                    </table>
                                </center>
                            </body>
                    </html>
                ''';
    _webViewController.loadUrl(Uri.dataFromString(htmlString,
            mimeType: 'text/html', encoding: Encoding.getByName('utf-8'))
        .toString());
  }

  double calculateRatio(Large pd, double width) {
    return (pd.resolutionY! / pd.resolutionX!) * width;
  }

  Widget getImage(PetDetailData? pd) {
    if (pd == null) {
      return const CircularProgressIndicator();
    } else {
      return CachedNetworkImage(
        placeholder: (BuildContext context, String url) => Container(
            width: MediaQuery.of(context).size.width,
            height: calculateRatio(pd.mainPictures[selectedImage],
                MediaQuery.of(context).size.width),
            color: Colors.grey),
        imageUrl: pd.mainPictures[selectedImage].url ?? "",
      );
    }
  }

  Widget getVideoImage(PetDetailData? pd, int index) {
    if (pd == null || index > pd.videos!.length + pd.smallPictures.length) {
      return const CircularProgressIndicator();
    } else {
      return GestureDetector(
          onTap: () {
            setState(() {
              selectedImage = index;
            });
          },
          child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                      Colors.black
                          .withOpacity(selectedImage == index ? 0.0 : 0.4),
                      BlendMode.srcOver),
                  child: Image.network(
                      pd.smallPictures[index].url ??
                          'https://cdn.pixabay.com/photo/2022/03/27/11/23/cat-7094808__340.jpg',
                      height: 50,
                      fit: BoxFit.fitHeight))));
    }
  }

  Widget getSmallImage(PetDetailData? pd, int index) {
    if (pd == null || pd.smallPictures.length < index) {
      return const CircularProgressIndicator();
    } else {
      return GestureDetector(
          onTap: () {
            setState(() {
              selectedImage = index;
            });
          },
          child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                      Colors.black
                          .withOpacity(selectedImage == index ? 0.0 : 0.4),
                      BlendMode.srcOver),
                  child: CachedNetworkImage(
                      imageUrl: pd.smallPictures[index].url ??
                          'https://cdn.pixabay.com/photo/2022/03/27/11/23/cat-7094808__340.jpg',
                      height: 50,
                      fit: BoxFit.fitHeight))));
    }
  }
}
