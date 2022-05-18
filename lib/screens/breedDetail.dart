import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/breed.dart';
import '/models/question.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import '/models/playlist.dart';
import '/widgets/playlist-row.dart';
import '/utils/constants.dart';
import '../models/favoritesRespository.dart';


enum WidgetMarker {
  adopt, videos, stats, info
}

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

class _BreedDetailState extends State<BreedDetail> with SingleTickerProviderStateMixin<BreedDetail> {

  final DataRepository repository = DataRepository();

  WidgetMarker selectedWidgetMarker = WidgetMarker.info;
  late AnimationController _controller;
  late Animation<double> _animation;
  List<Playlist> playlists = [];
  final maxValues = [5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 11, 6, 3, 12];

  InAppWebViewController? webView;
  String url = "";
  double progress = 0;

  bool fullScreen = true;
 
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller);
    getPlaylists();
  }

  Future<void> getPlaylists() async {
    final String url = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=49&playlistId=${widget.breed.playListID}&key=${Constants.YOU_TUBE_API_KEY}';
    Uri u = Uri.parse(url);
    var response = await http.get(u);
    if (response.statusCode == 200) {
      var jsonResponse = convert.jsonDecode(response.body);
      setState(() {
        playlists = jsonResponse['items'].map<Playlist>((item) {
          return Playlist.fromJson(item);
        }).toList();
        print("******** title: ${playlists[0].title}");
        print("******** videoId: ${playlists[0].videoId}");
        playlists.removeWhere((x) => x.title == "Private video");
      });
    } else {
      print('I should handle this error better: ${response.statusCode}.');
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
      body: StreamBuilder<QuerySnapshot>(
      stream: repository.getStream(),
      builder: (context, snapshot) {return SafeArea(
        // 3
        child: Column(
          children: <Widget>[
            // 4
            Visibility (
              visible: fullScreen,
              child: Column(
                children: [
                  Image(
                    height: 200,
                    width: MediaQuery.of(context).size.width,
                    image: AssetImage('assets/Full/${widget.breed.fullSizedPicture.replaceAll(' ', '_')}.jpg'),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  // 6
                  Text(
                    widget.breed.name,
                    style: const TextStyle(fontSize: 18),
                  ),  
                ],
              ),
            ),
            // 5
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget> [
                IconButton(
                  icon: Image.asset((selectedWidgetMarker == WidgetMarker.adopt) ? 'assets/Icons/Tool_Filled_Cat.png' : 'assets/Icons/Tool_Cat.png'),
                  onPressed: () {
                    setState(() {
                      selectedWidgetMarker = WidgetMarker.adopt;
                    });
                  },
                ),
                IconButton(
                  icon: Image.asset((selectedWidgetMarker == WidgetMarker.videos) ? 'assets/Icons/Tool_Filled_Video.png' : 'assets/Icons/Tool_Video.png'),
                  onPressed: () {
                    setState(() {
                      selectedWidgetMarker = WidgetMarker.videos;
                    });
                  },
                ),
                IconButton(
                  icon: Image.asset((selectedWidgetMarker == WidgetMarker.stats) ? 'assets/Icons/Tool_Filled_Stats.png' : 'assets/Icons/Tool_Stats.png'),
                  onPressed: () {
                    setState(() {
                      selectedWidgetMarker = WidgetMarker.stats;
                    });
                  },
                ),
                IconButton(
                  icon: Image.asset((selectedWidgetMarker == WidgetMarker.info) ? 'assets/Icons/Tool_Filled_Info.png' : 'assets/Icons/Tool_Info.png'),
                  onPressed: () {
                    setState(() {
                      selectedWidgetMarker = WidgetMarker.info;
                    });
                  },
                ),
                IconButton(
                  icon: Image.asset((fullScreen) ? 'assets/Icons/fullScreen.png' : 'assets/Icons/collapsedScreen.png'),
                  onPressed: () {
                    setState(() {
                      if (fullScreen) {
                        fullScreen = false;
                      } else {
                        fullScreen = true;
                      }
                    });
                  },
                )
              ],
            ),
            FutureBuilder(
              future: _playAnimation(),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                return 
                Expanded(
                  child: Align(alignment: Alignment.bottomCenter,
                  child: getCustomContainer(),
                  )
                );
              }
            )
          ],
        ),
      );
      }
    )
    );
  }

  _playAnimation() {
    _controller.forward();
  }

  Widget getCustomContainer() {
    switch (selectedWidgetMarker) {
      case WidgetMarker.adopt:
        return getAdoptContainer();
      case WidgetMarker.videos:
        return getVideosContainer();
      case WidgetMarker.stats:
        return getStatsContainer();
      case WidgetMarker.info:
        return getInfoContainer();
    }
  }

  Widget getAdoptContainer() {
    return FadeTransition(
    opacity: _animation,
    child: Container(
      color: Colors.red,
      )
    );
  }

  Widget getVideosContainer() {
    return FadeTransition(
    opacity: _animation,
    child: ListView.separated(
            separatorBuilder: (context, index) => Divider(
  thickness: 2.0,
),
    itemCount: playlists.length,
    itemBuilder: (context, index) {
    return PlaylistRow(
      playlist: playlists[index],
    );
    }
    ),
    );
  }

  Widget getStatsContainer() {
    return FadeTransition(
    opacity: _animation,
    child: ListView.separated(
            separatorBuilder: (context, index) => Divider(
  thickness: 2.0,
),
    itemCount: widget.breed.stats.length,
    itemBuilder: (context, index) {
    return new LinearPercentIndicator(
                lineHeight: 14.0,
                percent: (widget.breed.stats[index].isPercent) ? widget.breed.stats[index].value.toDouble() / maxValues[index].toDouble() : 1.0,
                backgroundColor: Colors.grey,
                progressColor: Colors.blue,
                center: Text(
                  widget.breed.stats[index].name + ': ' +  Question.questions[index].choices[widget.breed.stats[index].value.toInt()].name,
                  style: new TextStyle(fontSize: 12.0),
                ),
              );
    }
    ),
    );
  }

  Widget getInfoContainer() {
    return FadeTransition(
    opacity: _animation,
    child:
      Column(children: [
        Expanded(child:
            InAppWebView(initialUrlRequest: URLRequest(
                      url: Uri.parse(widget.breed.htmlUrl)
                    ),
                    initialOptions: InAppWebViewGroupOptions(
                      crossPlatform: InAppWebViewOptions(

                      ),
                      ios: IOSInAppWebViewOptions(

                      ),
                      android: AndroidInAppWebViewOptions(
                        useHybridComposition: true
                      )
                    ),
                    onWebViewCreated: (InAppWebViewController controller) {
                      webView = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        this.url = url?.toString() ?? '';
                      });
                    },
                    onLoadStop: (controller, url) async {
                      setState(() {
                        this.url = url?.toString() ?? '';
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        this.progress = progress / 100;
                      });
                    },
                  ),
              ),
              ButtonBar(
                alignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    child: Icon(Icons.arrow_back),
                    onPressed: () {
                      webView?.goBack();
                    },
                  ),
                  ElevatedButton(
                    child: Icon(Icons.arrow_forward),
                    onPressed: () {
                      webView?.goForward();
                    },
                  ),
                  ElevatedButton(
                    child: Icon(Icons.refresh),
                    onPressed: () {
                      webView?.reload();
                    },
                  ),
                ],
              ),
      ],)
    );
  }
}

