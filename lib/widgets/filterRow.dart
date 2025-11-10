import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:catapp/models/searchPageConfig.dart';
import '../screens/filterBreedSelection.dart';
import '../models/breed.dart';
import '../screens/globals.dart' as globals;

class FilterRow extends StatefulWidget {
  int position;
  CatClassification classification;
  late filterOption filter;
  final server = globals.FelineFinderServer.instance;
  late Function(String) loadSearch;
  late Function() getQueries;

  FilterRow(
      {Key? key,
      required this.position,
      required this.classification,
      required this.filter,
      required this.loadSearch,
      required this.getQueries})
      : super(key: key);

  @override
  _FilterRow createState() => _FilterRow();
}

class _FilterRow extends State<FilterRow> {
  bool shouldSelect(listOption choosen) {
    if (widget.filter.list) {
      if (widget.filter.classification == CatClassification.breed) {
        return false;
      } else if (widget.filter.choosenListValues.contains(choosen.value)) {
        return true;
      } else {
        return false;
      }
    } else if (widget.filter.classification == CatClassification.saves) {
      if (widget.server.currentFilterName == "" && choosen.displayName == "New...") {
        return true;
      } else if (widget.server.currentFilterName == choosen.search) {
        return true;
      } else {
        return false;
      }
    } else if (widget.filter.choosenValue == choosen.search) {
      return true;
    } else {
      return false;
    }
  }

  goToBreedSelectionScreen() async {
    var selected = await Get.to(() => FilterBreedSelection(choosenValues: widget.filter.choosenListValues));
    List<int> selectedBreeds = [];
    List<listOption> options = [];
    options.add(listOption("Change...", "Change", 0));
    for (var i = 0; i < selected.length; i++) {
      if (selected[i]) {
        selectedBreeds.add(breeds[i].id);
        options.add(listOption(breeds[i].name, breeds[i].name, breeds[i].rid));
      }
    }
    setState(() {
      widget.filter.choosenListValues = selectedBreeds;
      widget.filter.options = options;
    });
  }

  deleteQuery(String name) async {
    String localUserID = "";
    var userID = await widget.server.getUser();
    setState(() {
      localUserID = userID;
    });
    await widget.server.deleteQuery(localUserID, name);
    await widget.getQueries();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 1, child: Text(widget.filter.name)),
        Expanded(
          flex: 2,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 10,
            runSpacing: 10,
            direction: Axis.horizontal,
            children: widget.filter.options.map(
              (item) {
                return GestureDetector(
                  onTap: () => {
                    if (widget.filter.classification == CatClassification.breed)
                      {goToBreedSelectionScreen()}
                    else
                      {
                        setState(
                          () {
                            if (widget.filter.list) {
                              if (item.search == "Any") {
                                widget.filter.choosenListValues = [widget.filter.options.last.value];
                              } else {
                                if (!widget.filter.choosenListValues.contains(item.value)) {
                                  widget.filter.choosenListValues.remove(widget.filter.options.last.value);
                                  widget.filter.choosenListValues.add(item.value);
                                } else {
                                  widget.filter.choosenListValues.remove(item.value);
                                  if (widget.filter.choosenListValues.isEmpty) {
                                    widget.filter.choosenListValues.add(widget.filter.options.last.value);
                                  }
                                }
                              }
                            } else {
                              if (widget.classification == CatClassification.saves) {
                                widget.server.currentFilterName = "";
                                widget.loadSearch(item.search);
                              } else {
                                widget.filter.choosenValue = item.search;
                              }
                            }
                          },
                        ),
                      },
                  },
                  child: Container(
                      height: 40,
                      width: ((widget.filter.classification == CatClassification.breed ||
                              widget.filter.classification == CatClassification.saves)
                          ? 210
                          : 105),
                      //padding: const EdgeInsets.only(left: 5, right: 5),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          color: shouldSelect(item) ? Colors.blue : Colors.blueGrey[100],
                          borderRadius: const BorderRadius.all(Radius.circular(5))),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(item.displayName.trim(),
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: (shouldSelect(item) ? Colors.white : Colors.black)),
                                      textAlign: TextAlign.center),
                                ),
                                Positioned(
                                  right: 0,
                                  top: -1,
                                  child: Visibility(
                                    visible: (widget.filter.classification == CatClassification.saves &&
                                        item.displayName != "New..."),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: TextButton(
                                        style: ButtonStyle(
                                            padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.all(0))),
                                        child: const Align(
                                          alignment: Alignment(0.5, 0.0),
                                          child: Text(
                                            "🗑️",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                backgroundColor: Colors.transparent,
                                                color: Colors.black),
                                          ),
                                        ),
                                        onPressed: () {
                                          deleteQuery(item.displayName);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )),
                );
              },
            ).toList(),
          ),
        ),
      ],
    );
  }
}
