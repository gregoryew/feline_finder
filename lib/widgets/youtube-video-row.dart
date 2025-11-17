import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

    // Allow both portrait and landscape orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
  void dispose() {
    // Reset to portrait only when leaving the video player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Detect current orientation
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    // Hide system UI in landscape for fullscreen experience
    if (isLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null // Hide app bar in landscape for fullscreen
          : AppBar(
              title: Text(widget.title ?? widget.playlist!.title),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              automaticallyImplyLeading: !(widget.fullScreen ?? false),
              leading: !(widget.fullScreen ?? false)
                  ? IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  : null,
              actions: <Widget>[
                Visibility(
                  visible: widget.fullScreen ?? false,
                  child: IconButton(
                    icon: const Icon(
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
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: isLandscape
            ? Stack(
                children: [
                  // Fullscreen video in landscape
                  SizedBox.expand(
                    child: YoutubePlayerBuilder(
                      player: YoutubePlayer(
                        controller: _controller,
                        onEnded: (_) {
                          Get.off(const HomeScreen(title: 'Feline Finder'));
                        },
                      ),
                      builder: (context, player) {
                        return player;
                      },
                    ),
                  ),
                  // Close button overlay in landscape
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () {
                        Get.off(const HomeScreen(title: 'Feline Finder'));
                      },
                    ),
                  ),
                ],
              )
            : Center(
                child: (widget.fullScreen ?? false)
                    ? (kIsWeb
                        ? Container(
                            height: 300,
                            width: double.infinity,
                            color: Colors.grey[800],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_outline,
                                    size: 64, color: Colors.white),
                                const SizedBox(height: 16),
                                const Text(
                                  'YouTube Player',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Video: ${widget.title ?? "Welcome To Feline Finder"}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    Get.off(
                                        const HomeScreen(title: 'Feline Finder'));
                                  },
                                  child: const Text('Continue to App'),
                                ),
                              ],
                            ),
                          )
                        : YoutubePlayerBuilder(
                            player: YoutubePlayer(
                              controller: _controller,
                              onEnded: (_) {
                                Get.off(
                                    const HomeScreen(title: 'Feline Finder'));
                              },
                            ),
                            builder: (context, player) {
                              return SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    player,
                                    if (widget.playlist != null &&
                                        widget.playlist!.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Text(
                                          widget.playlist!.description,
                                          style:
                                              const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ))
                    : (kIsWeb
                        ? Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[800],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_outline,
                                    size: 48, color: Colors.white),
                                const SizedBox(height: 12),
                                const Text(
                                  'YouTube Player',
                                  style:
                                      TextStyle(color: Colors.white, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Video: ${widget.title ?? "Welcome To Feline Finder"}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : YoutubePlayerBuilder(
                            player: YoutubePlayer(controller: _controller),
                            builder: (context, player) {
                              return Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      player,
                                      if (widget.playlist != null &&
                                          widget.playlist!.description.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Text(
                                            widget.playlist!.description,
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )),
              ),
      ),
    );
  }
}
