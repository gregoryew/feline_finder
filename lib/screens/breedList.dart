import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/models/breed.dart';
import '/screens/breedDetail.dart';
import '/gold_frame/gold_frame_panel.dart';

class BreedList extends StatefulWidget {
  BreedList({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  List<Breed> filteredBreedsList = breeds;

  var letters = {};
  List<dynamic> keys = [];

  @override
  State<BreedList> createState() => _BreedList();
}

class _BreedList extends State<BreedList> {
  @override
  initState() {
    super.initState();
    breeds.sort((b1, b2) => b1.name.compareTo(b2.name));
    widget.filteredBreedsList = breeds;
    categorize();
  }

  categorize() {
    widget.letters.clear();
    widget.filteredBreedsList.sort((b1, b2) => b1.name.compareTo(b2.name));
    for (var breed in widget.filteredBreedsList) {
      if (!widget.letters.containsKey(breed.name[0])) {
        widget.letters[breed.name[0]] = [];
      }
      widget.letters[breed.name[0]].add(breed);
    }
    widget.keys = widget.letters.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    int numberOfCellsPerRow = (MediaQuery.of(context).size.width / 295).ceil();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            onChanged: (value) {
              Iterable<Breed> list = [];
              if (value == "") {
                list = breeds;
              } else {
                list = breeds.where((breed) =>
                    breed.name.toLowerCase().contains(value.toLowerCase()));
              }
              setState(() {
                widget.filteredBreedsList = list.toList();
                categorize();
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '🔎 Breed Name',
              hintStyle: const TextStyle(color: Colors.white70),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.keys.length,
            itemBuilder: (context, subSubMenuIndex) {
              return Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 20,
                        child: (Text(
                          widget.keys[subSubMenuIndex],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 18),
                        )),
                      ),
                      const SizedBox(width: 5),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                              height: 1,
                              width: MediaQuery.of(context).size.width - 45,
                              color: Colors.white)),
                    ],
                  ),
                  GridView.builder(
                    physics: const ScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: numberOfCellsPerRow,
                        childAspectRatio: 3 / 4),
                    itemCount:
                        widget.letters[widget.keys[subSubMenuIndex]].length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: GestureDetector(
                          onTap: () => {
                            Get.to(
                                () => BreedDetail(
                                    breed: widget.letters[
                                        widget.keys[subSubMenuIndex]][index]),
                                transition: Transition.circularReveal,
                                duration: const Duration(seconds: 1))
                          },
                          child: SizedBox.expand(
                            child: GoldFramedPanel(
                              plaqueLines: [
                                widget.letters[widget.keys[subSubMenuIndex]][index].name,
                              ],
                            child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 15.0,
                                  left: 15.0,
                                  right: 15.0,
                                  bottom: 8.0, // Keep original bottom padding
                                ),
                              child: Center(
                                  child: Image(
                                        image: AssetImage(
                                        "assets/Cartoon/${widget.letters[widget.keys[subSubMenuIndex]][index].pictureHeadShotName.replaceAll(' ', '_')}.png"),
                                    fit: BoxFit.contain,
                                    ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
