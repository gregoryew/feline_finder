// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/breed.dart';

class FilterBreedSelection extends StatefulWidget {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  List<int> choosenValues = [];

  FilterBreedSelection({Key? key, required this.choosenValues})
      : super(key: key);

  @override
  FilterBreedSelectionState createState() {
    return FilterBreedSelectionState();
  }
}

class FilterBreedSelectionState extends State<FilterBreedSelection> {
  var _selected = List<bool>.filled(breeds.length, false);

  @override
  void initState() {
    // TODO: implement initState
    for (int i = 0; i < widget.choosenValues.length; i++) {
      _selected[widget.choosenValues[i] - 1] = true;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Select Breeds"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _selected = List<bool>.filled(breeds.length, false);
                });
              },
            )
          ]),
      // 2
      body: Container(child: buildRows()),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(color: Color.fromRGBO(255, 255, 255, 1)),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: () => {Get.back(result: _selected)},
                icon: const Icon(Icons.save_alt, color: Colors.white),
                label: const Text('Return Breeds',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRows() {
    return ListView.builder(
      itemCount: breeds.length,
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _selected[index] = !_selected[index];
            });
          },
          child: buildBreedCard(index),
        );
      },
    );
  }

  Widget buildBreedCard(int index) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                  'assets/Cartoon/${breeds[index].pictureHeadShotName.replaceAll(' ', '_')}.png',
                  color: _selected[index]
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  colorBlendMode: BlendMode.modulate,
                  height: 70,
                  width: 70),
            ),
            // 5
            const SizedBox(height: 5.0, width: 5.0),
            // 6
            Text(breeds[index].name,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight:
                      (_selected[index] ? FontWeight.bold : FontWeight.w300),
                  fontFamily: 'Palatino',
                )),
          ],
        ),
      ),
    );
  }
}
