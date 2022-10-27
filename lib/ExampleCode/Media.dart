import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
      onTap: () {
        Get.to(
          () => YouTubeVideoRow(
            playlist: null,
            title: widget.title,
            videoid: widget.videoID,
          ),
        );
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
