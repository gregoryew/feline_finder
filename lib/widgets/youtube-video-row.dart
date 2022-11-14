import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '/models/playlist.dart';
import '../main.dart';
import 'package:get/get.dart';

class YouTubeVideoRow extends StatefulWidget {
  final Playlist? playlist;
  final String? videoid;
  final String? title;
  final bool? fullScreen;

  const YouTubeVideoRow._(
      {required this.playlist,
      required this.videoid,
      required this.title,
      this.fullScreen});

  const YouTubeVideoRow(
      {Key? key,
      required this.playlist,
      required this.videoid,
      required this.title,
      this.fullScreen})
      : super(key: key);

  @override
  _YouTubeVideoRowState createState() => _YouTubeVideoRowState();
}

class _YouTubeVideoRowState extends State<YouTubeVideoRow> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    String? id =
        (widget.videoid == "") ? widget.playlist!.videoId : widget.videoid;

    _controller = YoutubePlayerController(
      initialVideoId: id!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? widget.playlist!.title),
        automaticallyImplyLeading: !(widget.fullScreen ?? false),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white,
            ),
            onPressed: () {
              Get.off(const HomeScreen(title: 'Feline Finder'));
            },
          )
        ],
      ),
      // 2
      body: (widget.fullScreen ?? false)
          ? (Container(
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  YoutubePlayerBuilder(
                    player: YoutubePlayer(
                      controller: _controller,
                      onEnded: (_) {
                        Get.off(const HomeScreen(title: 'Feline Finder'));
                      },
                    ),
                    builder: (context, player) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            player,
                            Padding(
                              child: Text(widget.playlist?.description ?? ""),
                              padding: EdgeInsets.all(10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ))
          : (YoutubePlayerBuilder(
              player: YoutubePlayer(controller: _controller),
              builder: (context, player) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      player,
                      Padding(
                        child: Text(widget.playlist?.description ?? ""),
                        padding: EdgeInsets.all(10),
                      ),
                    ],
                  ),
                );
              },
            )),
    );
  }
}
