import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_network_connectivity/flutter_network_connectivity.dart';
import '../widgets/youtube-video-row.dart';
import 'package:get/get.dart';
import '../screens/globals.dart' as globals;

class SmallPhoto extends StatefulWidget {
  int order = 0;
  String photo = "";

  SmallPhoto(this.order, this.photo);

  @override
  State<StatefulWidget> createState() {
    return _SmallPhoto();
  }
}

class _SmallPhoto extends State<SmallPhoto> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
            imageUrl: widget.photo,
            height: globals.petDetailImageHeight,
            fit: BoxFit.fitHeight),
      ),
    );
  }
}

class YouTubeVideo extends StatefulWidget {
  String photo = "";
  String videoID = "";
  String title = "";

  YouTubeVideo(this.photo, this.title, this.videoID);

  @override
  State<StatefulWidget> createState() {
    return _YouTubeVideo();
  }
}

class _YouTubeVideo extends State<YouTubeVideo> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          Get.to(
            () => YouTubeVideoRow(
                playlist: null,
                title: widget.title,
                videoid: widget.videoID,
                fullScreen: false),
          );
        } else {
          await Get.defaultDialog(
              title: "Internet Not Available",
              middleText:
                  "Viewing videos requires you to be connected to the internet.  Please connect to the internet and try again.",
              backgroundColor: Colors.red,
              titleStyle: TextStyle(color: Colors.white),
              middleTextStyle: TextStyle(color: Colors.white),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            SizedBox(
                height: globals.petDetailImageHeight,
                child: Image.network(widget.photo, fit: BoxFit.fitHeight)),
            Positioned.fill(
                child: Image.asset("assets/Icons/small_youtube_icon.png"))
          ],
        ),
      ),
    );
  }
}
