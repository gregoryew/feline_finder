import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
      // ignore: unused_element_parameter
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
      initialVideoId: id ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? widget.playlist!.title),
        automaticallyImplyLeading: !(widget.fullScreen ?? false),
        actions: <Widget>[
          Visibility(
            visible: widget.fullScreen ?? false,
            child: IconButton(
              icon: Icon(
                Icons.close,
                color: Colors.white,
              ),
              onPressed: () {
                Get.off(const HomeScreen(title: 'Feline Finder'));
              },
            ),
          ),
        ],
      ),
      // 2
      body: (widget.fullScreen ?? false)
          ? (Container(
              color: Colors.black,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (kIsWeb)
                      Container(
                        height: 300,
                        width: double.infinity,
                        color: Colors.grey[800],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_outline,
                                size: 64, color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'YouTube Player',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Video: ${widget.title ?? "Welcome To Feline Finder"}',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Get.off(
                                    const HomeScreen(title: 'Feline Finder'));
                              },
                              child: Text('Continue to App'),
                            ),
                          ],
                        ),
                      )
                    else
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
                                  child: Text((widget.playlist != null)
                                      ? widget.playlist!.description
                                      : ""),
                                  padding: EdgeInsets.all(10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ))
          : (kIsWeb
              ? Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[800],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_outline,
                          size: 48, color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'YouTube Player',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Video: ${widget.title ?? "Welcome To Feline Finder"}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : YoutubePlayerBuilder(
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
