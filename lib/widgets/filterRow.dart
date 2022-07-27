import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:recipes/models/searchPageConfig.dart';
import 'package:recipes/screens/breedList.dart';
import '../screens/filterBreedSelection.dart';
import '../models/breed.dart';

class FilterRow extends StatefulWidget {
  int position;
  CatClassification classification;
  late filterOption filter;
  FilterRow(
      {Key? key,
      required this.position,
      required this.classification,
      required this.filter})
      : super(key: key);

  @override
  _FilterRow createState() => _FilterRow();
}

class _FilterRow extends State<FilterRow> {
  bool shouldSelect(listOption choosen) {
    if (widget.filter.list) {
      if (widget.filter.choosenListValues.contains(choosen.value)) {
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
    var selected = await Get.to(
        FilterBreedSelection(choosenValues: widget.filter.choosenListValues));
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(widget.filter.name), flex: 1),
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
                          () => {
                            if (widget.filter.list)
                              {
                                if (item.search == "Any")
                                  {
                                    widget.filter.choosenListValues = [
                                      widget.filter.options.last.value
                                    ]
                                  }
                                else
                                  {
                                    if (!widget.filter.choosenListValues
                                        .contains(item.value))
                                      {
                                        widget.filter.choosenListValues.remove(
                                            widget.filter.options.last.value),
                                        widget.filter.choosenListValues
                                            .add(item.value)
                                      }
                                    else
                                      {
                                        widget.filter.choosenListValues
                                            .remove(item.value),
                                        if (widget
                                            .filter.choosenListValues.isEmpty)
                                          {
                                            widget.filter.choosenListValues.add(
                                                widget
                                                    .filter.options.last.value)
                                          }
                                      }
                                  }
                              }
                            else
                              {widget.filter.choosenValue = item.search}
                          },
                        ),
                      },
                  },
                  child: Container(
                    height: 20,
                    width: ((widget.filter.classification ==
                            CatClassification.breed)
                        ? 210
                        : 105),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(left: 5, right: 5),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        color: shouldSelect(item)
                            ? Colors.blue
                            : Colors.blueGrey[100],
                        borderRadius:
                            const BorderRadius.all(Radius.circular(5))),
                    child: Text(item.displayName.trim(),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: (shouldSelect(item)
                                ? Colors.white
                                : Colors.black)),
                        textAlign: TextAlign.center),
                  ),
                );
              },
            ).toList(),
          ),
        ),
      ],
    );
  }
}
