import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '/models/playlist.dart';

class YouTubeVideoRow extends StatefulWidget {
  final Playlist? playlist;
  final String? videoid;
  final String? title;

  const YouTubeVideoRow._(
      {required this.playlist, required this.videoid, required this.title});

  const YouTubeVideoRow(
      {Key? key,
      required this.playlist,
      required this.videoid,
      required this.title})
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

    print("===============PLAY VIDEO VideoID = " + id!);

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
        ),
        // 2
        body: (YoutubePlayerBuilder(
            player: YoutubePlayer(
              controller: _controller,
            ),
            builder: (context, player) {
              return Column(children: [
                player,
                Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: SingleChildScrollView(
                        child: Text(widget.playlist?.description ?? "")))
              ]);
            })));
  }
}
