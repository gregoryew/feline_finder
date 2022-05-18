import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:like_button/like_button.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/toolbar.dart';
import '/ExampleCode/RescueGroups.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petDetailData.dart';

class petDetail extends StatefulWidget {
  final String petID;
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

class petDetailState extends State<petDetail> {
  PetDetailData? petDetailInstance;
  bool isLiked = false;
  int selectedImage = 0;
  double _height = 20.0;
  late WebViewController _webViewController;

@override
void initState() {
  super.initState();
  getPetDetail(widget.petID);
}

void getPetDetail(String petID) async {
    print('Getting Pet Detail');

    String id2 = widget.petID;

    print("id = ${id2}");

    var url = "https://api.rescuegroups.org/v5/public/animals/${id2}?fields[animals]=sizeGroup,ageGroup,sex,distance,id,name,breedPrimary,updatedDate,status,descriptionHtml,descriptionText&limit=1&page=1";

  print("URL = $url");

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

  var response = await http.get(Uri.parse(url),
    headers: {
      'Content-Type': 'application/json', //; charset=UTF-8',
      'Authorization': '0doJkmYU'
    }
  );

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    print("status 200");
    var petDecoded = pet.fromJson(jsonDecode(response.body));
    setState(() {
      petDetailInstance = PetDetailData(petDecoded.data![0], petDecoded.included!, petDecoded.data![0].relationships!.values.toList());
      loadAsset();
    });
    print("********DD = ${petDetailInstance?.smallPictures}");
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    print("response.statusCode = " + response.statusCode.toString());
    throw Exception('Failed to load pet ' + response.body );
  }
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(petDetailInstance?.name ?? ""),
        actions: <Widget>[
    Padding(
      padding: EdgeInsets.only(right: 20.0),
      child: GestureDetector(
        onTap: () {},
        child: LikeButton(
          size: 40,
          isLiked: isLiked,
          likeBuilder: (isLiked) {
            final color = isLiked ? Colors.red : Colors.blueGrey;
            return Icon(Icons.favorite, color: color, size: 40);
          }
        ),
      ))]),
      body: SingleChildScrollView(child: Column(children: [const SizedBox(
                height: 20,
              ), 
              Center(child: ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: getImage(petDetailInstance))),
              const SizedBox(
                height: 20,
              ),
              Center(child: Text(petDetailInstance == null ? "" : petDetailInstance!.name ?? "",
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center)),
              const SizedBox(
                height: 20,
              ),
              Center(child: Text(petDetailInstance == null ? "" : petDetailInstance!.primaryBreed ?? "",
              style: const TextStyle(fontSize: 25),
              textAlign: TextAlign.center)),
              Center(child: Text(getStats(),
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center)),
              Center(child: Text(petDetailInstance == null ? "" : petDetailInstance!.cityState ?? "",
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center)),
              const SizedBox(
                height: 20,
              ), 
              Center(child: SizedBox(
                height: 100,
                child: Center(child: ToolBar(detail: petDetailInstance)
              )
              )),
              Center(child: SizedBox(
                height: 100,
                child: Center(child: MasonryGridView.count(
                  scrollDirection: Axis.horizontal,
                  itemCount: petDetailInstance == null ? 0 : petDetailInstance!.smallPictures.length,
                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 3),
                  // the number of columns
                  crossAxisCount: 1, 
                  // vertical gap between two items
                  mainAxisSpacing: 7, 
                  // horizontal gap between two items
                  crossAxisSpacing: 0, 
                  itemBuilder: (context, index) {
                    return getSmallImage(petDetailInstance, index);
                  }
              )
              ))),
              Container(
                height: _height < 100.0 ? 100.0 : _height,
                color: Colors.deepOrange,
                child: WebView(
                initialUrl: '',
                onPageFinished: (some) async {
                double height = double.parse(await _webViewController
                    .evaluateJavascript(
                        "document.documentElement.scrollHeight;"));
                setState(() {
                  _height = height;
                });
              },
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (WebViewController webViewController){
              _webViewController=webViewController;
            },
              ),
            )
      ])));
          }
  
    String getStats() {
      List<String> stats = [];
      if (petDetailInstance == null) {
        return "";
      }
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
      return stats.join(" | ");
    }

    void loadAsset() async {
      String addressString = "";
      addressString = "<table>";
      if (petDetailInstance?.organizationName != "") {
        addressString = "$addressString<tr><td>${petDetailInstance?.organizationName ?? ""}</td></tr>";
      }
      if (petDetailInstance?.street != "") {
        addressString = "$addressString<tr><td>${petDetailInstance?.street ?? ""}</td></tr>";
      }
      if (petDetailInstance?.cityState != "") {
        addressString = "$addressString<tr><td>${petDetailInstance?.cityState ?? ""} ${petDetailInstance?.postalCode ?? ""}</td></tr></table>";
      }

      final String description = petDetailInstance?.description ?? "";

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
                                                        ${description}
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

    Widget getImage(PetDetailData? pd) {
      if (pd == null) {
        return const CircularProgressIndicator();
      } else {
        return Image.network(pd.mainPictures[selectedImage].url ?? 'https://cdn.pixabay.com/photo/2022/03/27/11/23/cat-7094808__340.jpg',
                             height: 300, fit: BoxFit.fitHeight
        );
      }
    }

    Widget getSmallImage(PetDetailData? pd, int index) {
      if (pd == null || pd.smallPictures.length < index) {
        return const CircularProgressIndicator();
      } else {
        return GestureDetector(
                            onTap: () {
                              setState(() {selectedImage = index;});
                            }, child: ClipRRect(
  borderRadius: BorderRadius.circular(10), child: ColorFiltered(
  colorFilter: ColorFilter.mode(Colors.black.withOpacity(selectedImage == index ? 0.0 : 0.4), BlendMode.srcOver),
  child: Image.network(pd.smallPictures[index].url ?? 'https://cdn.pixabay.com/photo/2022/03/27/11/23/cat-7094808__340.jpg',
                             height: 50,
                             fit: BoxFit.fitHeight))));
      }
    }
  }