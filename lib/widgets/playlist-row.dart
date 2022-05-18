import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../widgets/youtube-video-row.dart';

class PlaylistRow extends StatelessWidget {
  final Playlist playlist;

  const PlaylistRow({
    Key? key,
    required this.playlist
  }):super(key: key);

@override
Widget build(BuildContext context) {
  return InkWell(
    onTap: ()async {
      Navigator.push(context, MaterialPageRoute(builder: (context) {
        return YouTubeVideoRow(playlist: playlist);
      }));
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const Icon(Icons.play_arrow_sharp, size: 50, color: Colors.white),
      ],
    )
  ),
  Padding(
    padding: EdgeInsets.all(10.0),
    child: Text(playlist.description),
  ),
],
    ),
  );
}
}