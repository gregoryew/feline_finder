import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:recipes/main.dart';
import '../widgets/youtube-video-row.dart';
import 'package:get/get.dart';

class SmallPhoto extends StatefulWidget {
  bool selected = false;
  int order = 0;
  String photo = "";
  late Function(int) selectedChanged;
  String videoID = "";
  String title = "";

  SmallPhoto(
      this.selected, this.order, this.photo, this.selectedChanged, this.title,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SmallPhoto();
  }
}

class _SmallPhoto extends State<SmallPhoto> {
  void setSelected(int pic) {
    setState(() {
      if (widget.order == pic) {
        widget.selected = true;
      } else {
        widget.selected = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    photoButtonChangedHighlight.stream.listen((index) {
      print("===============I am listening...");
      setSelected(index);
    });

    return GestureDetector(
      onTap: () {
        widget.selectedChanged(widget.order);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(widget.selected ? 0.0 : 0.4),
              BlendMode.srcOver),
          child: CachedNetworkImage(
              imageUrl: widget.photo, height: 100, fit: BoxFit.fitHeight),
        ),
      ),
    );
  }
}

class YouTubeVideo extends StatefulWidget {
  bool selected = false;
  int order = 0;
  String photo = "";
  late Function(int) selectedChanged;
  String videoID = "";
  String title = "";

  YouTubeVideo(this.selected, this.order, this.photo, this.selectedChanged,
      this.title, this.videoID,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _YouTubeVideo();
  }
}

class _YouTubeVideo extends State<YouTubeVideo> {
  void setSelected(int pic) {
    setState(() {
      if (widget.order == pic) {
        widget.selected = true;
        Get.to(() => YouTubeVideoRow(
              playlist: null,
              title: widget.title,
              videoid: widget.videoID,
            ));
      } else {
        widget.selected = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    videoButtonChangedHighlight.stream.listen((index) {
      print("===============I am listening...");
      setSelected(index);
    });

    return GestureDetector(
      onTap: () {
        widget.selectedChanged(widget.order);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(widget.selected ? 0.0 : 0.4),
              BlendMode.srcOver),
          child: Stack(
            children: [
              CachedNetworkImage(
                  imageUrl: widget.photo, width: 110, height: 100),
              const Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Image(
                    image: AssetImage("assets/Icons/small_youtube_icon.png"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
