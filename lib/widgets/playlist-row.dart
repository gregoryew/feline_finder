// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:readmore/readmore.dart';

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
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return YouTubeVideoRow(playlist: playlist, title: '', videoid: '');
        }));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Card(
            elevation: 3.0,
            shadowColor: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 15.0, top: 10.0),
                    child: Text(
                      playlist.title,
                      style: TextStyle(fontSize: 20.0),
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
                      padding: EdgeInsets.all(10.0),
                      child: Text(playlist.description),
                    ),
                  ),
                  Visibility(
                    visible: displayDescription == false,
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: ReadMoreText(
                        playlist.description,
                        trimLines: 2,
                        preDataText: "",
                        preDataTextStyle:
                            TextStyle(fontWeight: FontWeight.w500),
                        style: TextStyle(color: Colors.black),
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
