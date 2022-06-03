import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class Media extends StatefulWidget {
  bool selected = false;
  int order = 0;
  String photo = "";
  late Function(int) selectedChanged;

  Media({
    Key? key,
    required this.selected,
    required this.order,
    required this.photo,
    required this.selectedChanged,
  }) : super(key: key);

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

  void setSelected(bool _selected) {
    setState(() {
      widget.selected = _selected;
    });
  }
}

// ignore: must_be_immutable
class SmallPhoto extends Media {
  SmallPhoto(
      {Key? key,
      required bool selected,
      required int order,
      required String photo,
      required Function(int p1) selectedChanged})
      : super(
            key: key,
            selected: selected,
            order: order,
            photo: photo,
            selectedChanged: selectedChanged);

  @override
  State<StatefulWidget> createState() {
    return _SmallPhoto();
  }
}

class _SmallPhoto extends State<SmallPhoto> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.selectedChanged(widget.order);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: //ColorFiltered(
            //colorFilter: ColorFilter.mode(
            //    Colors.black.withOpacity(widget.selected ? 0.0 : 0.4),
            //    BlendMode.srcOver),
            //child:
            CachedNetworkImage(
                imageUrl: widget.photo, height: 50, fit: BoxFit.fitHeight),
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