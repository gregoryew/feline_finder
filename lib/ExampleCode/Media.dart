import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:recipes/main.dart';

// ignore: must_be_immutable
class Media extends StatefulWidget {
  bool selected = false;
  int order = 0;
  String photo = "";
  late Function(int) selectedChanged;

  Media(this.selected, this.order, this.photo, this.selectedChanged);

  @override
  State<StatefulWidget> createState() {
    return _Media();
  }
}

class _Media extends State<Media> {
  @override
  Widget build(BuildContext context) {
    // ignore: todo
    // TODO: implement build
    throw UnimplementedError();
  }

  @override
  void initState() {
    super.initState();
    ;
  }
}

// ignore: must_be_immutable
class SmallPhoto extends Media {
  SmallPhoto(
      bool selected, int order, String photo, Function(int p1) selectedChanged)
      : super(selected, order, photo, selectedChanged);

  @override
  State<StatefulWidget> createState() {
    return _SmallPhoto();
  }
}

class _SmallPhoto extends State<SmallPhoto> {
  void setSelected(int pic) {
    setState(() {
      print("****************setState button");
      if (widget.order == pic) {
        widget.selected = true;
      } else {
        widget.selected = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    buttonChangedHighlight.stream.listen((index) {
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
              imageUrl: widget.photo, height: 50, fit: BoxFit.fitHeight),
        ),
      ),
    );
  }
}


/*
class smallPhoto extends StatelessWidget implements Media {
  smallPhoto({Key? key, required this.update, required this.selectedIndex})
      : super(key: key);

    throw UnimplementedError();
  }

  @override
  int order = 0;

  @override
  String photo = "";

  @override
  set selectedIndex(ValueSetter<int> _selectedIndex) {
    // TODO: implement selectedIndex
  }
}
*/