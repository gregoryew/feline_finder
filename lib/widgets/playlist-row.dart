// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:readmore/readmore.dart';
import 'package:flutter_network_connectivity/flutter_network_connectivity.dart';
import 'package:get/get.dart';

import '../models/playlist.dart';
import '../widgets/youtube-video-row.dart';

class PlaylistRow extends StatelessWidget {
  final Playlist playlist;
  bool displayDescription;

  PlaylistRow({
    required this.displayDescription,
    Key? key,
    required this.playlist,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        FlutterNetworkConnectivity flutterNetworkConnectivity =
            FlutterNetworkConnectivity(
          isContinousLookUp:
              false, // optional, false if you cont want continous lookup
          lookUpDuration: const Duration(
              seconds: 5), // optional, to override default lookup duration
          lookUpUrl: 'example.com', // optional, to override default lookup url
        );
        if (await flutterNetworkConnectivity.isInternetConnectionAvailable()) {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return YouTubeVideoRow(playlist: playlist, title: '', videoid: '');
          }));
        } else {
          await Get.defaultDialog(
              title: "Internet Not Available",
              middleText:
                  "Viewing videos requires you to be connected to the internet.  Please connect to the internet and try again.",
              backgroundColor: Colors.red,
              titleStyle: const TextStyle(color: Colors.white),
              middleTextStyle: const TextStyle(color: Colors.white),
              textConfirm: "OK",
              confirmTextColor: Colors.white,
              onConfirm: () {
                Get.back();
              },
              buttonColor: Colors.black,
              barrierDismissible: false,
              radius: 30);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Card(
            elevation: 3.0,
            shadowColor: Colors.grey,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0, top: 10.0),
                    child: Text(
                      playlist.title,
                      style: const TextStyle(fontSize: 20.0),
                    ),
                  ),
                  Container(
                      child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Image.network(playlist.image),
                      const Icon(Icons.play_arrow_sharp,
                          size: 50, color: Colors.white),
                    ],
                  )),
                  Visibility(
                    visible: displayDescription,
                    child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(playlist.description)),
                  ),
                  Visibility(
                    visible: displayDescription == false,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: ReadMoreText(
                        playlist.description,
                        trimLines: 2,
                        preDataText: "",
                        preDataTextStyle:
                            const TextStyle(fontWeight: FontWeight.w500),
                        style: const TextStyle(color: Colors.black),
                        colorClickableText: Colors.pink,
                        trimMode: TrimMode.Line,
                        trimCollapsedText: 'Show more',
                        trimExpandedText: ' show less',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
