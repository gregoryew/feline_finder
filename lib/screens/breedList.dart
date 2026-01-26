import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/models/breed.dart';
import '/screens/breedDetail.dart';
import '/gold_frame/gold_frame_panel.dart';

class BreedList extends StatefulWidget {
  BreedList({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<BreedList> createState() => _BreedList();
}

class _BreedList extends State<BreedList> {
  List<Breed> filteredBreedsList = breeds;
  Map<String, List<Breed>> letters = {};
  List<String> keys = [];

  @override
  void initState() {
    super.initState();
    // Sort breeds and set up filtered list
    breeds.sort((b1, b2) => b1.name.compareTo(b2.name));
    filteredBreedsList = breeds;
    // Categorize breeds immediately and trigger rebuild
    categorize();
  }

  void categorize() {
    letters.clear();
    filteredBreedsList.sort((b1, b2) => b1.name.compareTo(b2.name));
    for (var breed in filteredBreedsList) {
      final firstLetter = breed.name[0].toUpperCase();
      if (!letters.containsKey(firstLetter)) {
        letters[firstLetter] = [];
      }
      letters[firstLetter]!.add(breed);
    }
    keys = letters.keys.toList()..sort();
    // Ensure setState is called to trigger rebuild
    if (mounted) {
      setState(() {});
    }
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
                filteredBreedsList = list.toList();
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
          child: keys.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: keys.length,
                  itemBuilder: (context, subSubMenuIndex) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 5),
                            SizedBox(
                              width: 20,
                              child: Text(
                                keys[subSubMenuIndex],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 18),
                              ),
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
                          itemCount: letters[keys[subSubMenuIndex]]!.length,
                          itemBuilder: (BuildContext context, int index) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: GestureDetector(
                                onTap: () => {
                                  Get.to(
                                      () => BreedDetail(
                                          breed: letters[keys[subSubMenuIndex]]![index]),
                                      transition: Transition.circularReveal,
                                      duration: const Duration(seconds: 1))
                                },
                                child: SizedBox.expand(
                                  child: GoldFramedPanel(
                                    plaqueLines: [
                                      letters[keys[subSubMenuIndex]]![index].name,
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
                                            "assets/Cartoon/${letters[keys[subSubMenuIndex]]![index].pictureHeadShotName.replaceAll(' ', '_')}.png"),
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
