// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:accordion/accordion.dart';
import 'package:accordion/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:http/http.dart';
import 'package:recipes/ExampleCode/Media.dart';
import 'package:recipes/models/breed.dart';

import '../ExampleCode/RescueGroupsQuery.dart';
import '../models/searchPageConfig.dart';
import '../widgets/filterRow.dart';
import '../widgets/filterZipCodeRow.dart';
import 'globals.dart' as globals;

class searchScreen extends StatefulWidget {
  final server = globals.FelineFinderServer.instance;

  var categories = {};
  List<dynamic> categoryKeys = [];
  String userID = "";

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  @override
  SearchScreenState createState() {
    return SearchScreenState();
  }
}

class SearchScreenState extends State<searchScreen> with RouteAware {
  late TextEditingController controller2;

  @override
  void initState() {
    controller2 = TextEditingController();
    super.initState();
    categorize();
    getQueries();
  }

  void getQueries() async {
    var user = await widget.server.getUser();
    setState(() {
      widget.userID = user;
    });
    var queriesFuture = await widget.server.getQueries(widget.userID);
    setState(() {
      filterOption savedList = filteringOptions
          .where((element) => element.classification == CatClassification.saves)
          .first;
      savedList.options.clear();
      List<listOption> options = [];
      List queries = queriesFuture;
      options.add(listOption("New...", "New", 0));
      for (var query in queries) {
        options.add(listOption(query, query, 0));
      }
      savedList.options = options;
    });
  }

  void categorize() {
    if (widget.categoryKeys.isNotEmpty) {
      return;
    }
    widget.categories.clear();
    for (var filterOption in filteringOptions) {
      if (!widget.categories.containsKey(filterOption.classification)) {
        widget.categories[filterOption.classification] = [];
      }
      if (filterOption.options.isNotEmpty) {
        if (filterOption.list) {
          if (filterOption.choosenListValues.isEmpty &&
              filterOption.classification != CatClassification.breed) {
            filterOption.choosenListValues = [filterOption.options.last.value];
          }
        } else {
          filterOption.choosenValue ??= filterOption.options.last.search;
        }
      }
      widget.categories[filterOption.classification].add(filterOption);
    }
    widget.categoryKeys = widget.categories.keys.toList();
  }

  String categoryString(CatClassification classification) {
    switch (classification) {
      case CatClassification.admin:
        {
          return "Administrative";
        }
      case CatClassification.basic:
        {
          return "Basic";
        }
      case CatClassification.breed:
        {
          return "Primary Breed";
        }
      case CatClassification.compatibility:
        {
          return "Compatibility";
        }
      case CatClassification.personality:
        {
          return "Personality";
        }
      case CatClassification.physical:
        {
          return "Physical";
        }
      case CatClassification.saves:
        {
          return "Saves";
        }
      case CatClassification.sort:
        {
          return "Sort";
        }
      case CatClassification.zipCode:
        {
          return "Zip Code";
        }
    }
  }

  IconData icon(CatClassification classification) {
    switch (classification) {
      case CatClassification.admin:
        {
          return Icons.folder_open;
        }
      case CatClassification.basic:
        {
          return Icons.add;
        }
      case CatClassification.breed:
        {
          return Icons.pets;
        }
      case CatClassification.compatibility:
        {
          return Icons.equalizer;
        }
      case CatClassification.personality:
        {
          return Icons.face;
        }
      case CatClassification.physical:
        {
          return Icons.scale;
        }
      case CatClassification.saves:
        {
          return Icons.save_alt;
        }
      case CatClassification.sort:
        {
          return Icons.sort;
        }
      case CatClassification.zipCode:
        {
          return Icons.location_pin;
        }
    }
  }

  Future<String?> openDialog() => showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text("Please Enter Filter Name:"),
              content: TextField(
                keyboardType: TextInputType.name,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Filter Name"),
                controller: controller2,
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(onPressed: submit, child: const Text("Submit")),
                TextButton(onPressed: Get.back, child: const Text("Cancel"))
              ]));

  void submit() {
    Navigator.of(context).pop(controller2.text);
    controller2.clear();
  }

  saveSearch() async {
    late bool? valid = false;
    late bool canceled = false;
    late String? FilterName = "";
    do {
      controller2.text = widget.server.currentFilterName;
      FilterName = await openDialog();
      if (FilterName != widget.server.currentFilterName) {
        filterOption savedList = filteringOptions
            .where(
                (element) => element.classification == CatClassification.saves)
            .first;
        valid = savedList.options
            .where((element) => element.displayName == FilterName)
            .isEmpty;
      } else {
        valid = true;
      }
      if (!valid!) {
        await Get.defaultDialog(
            title: "Duplicate Filter Name",
            middleText:
                "This filter name has already been used.  Please enter another name.",
            backgroundColor: Colors.red,
            titleStyle: const TextStyle(color: Colors.white),
            middleTextStyle: const TextStyle(color: Colors.white),
            textConfirm: "OK",
            confirmTextColor: Colors.white,
            onConfirm: () {
              valid = false;
              canceled = false;
              Get.back();
            },
            textCancel: "Cancel",
            cancelTextColor: Colors.white,
            onCancel: () {
              valid = true;
              canceled = true;
              Get.back();
            },
            buttonColor: Colors.black,
            barrierDismissible: false,
            radius: 30);
      }
    } while (valid == false);

    if (canceled == false) {
      List<Filters> filters = generateFilters();
      List<Map<dynamic, dynamic>> filtersJson = [];
      for (var element in filters) {
        filtersJson.add({
          "fieldName": element.fieldName,
          "operation": element.operation,
          "criteria": element.criteria
        });
      }

      Map<dynamic, dynamic> data = {
        "data": {
          "filterRadius": {
            "miles": globals.distance,
            "postalcode": widget.server.zip
          },
          "filters": filtersJson,
        }
      };

      await widget.server.saveFilter(widget.userID, FilterName!, data);
      getQueries();
      widget.server.currentFilterName = FilterName;
    }
  }

  loadSearch(String name) async {
    setState(() {
      for (var filterOption in filteringOptions) {
        if (filterOption.fieldName == "species.singular" ||
            filterOption.classification == CatClassification.saves) {
          continue;
        }
        if (filterOption.classification == CatClassification.breed) {
          filterOption.options = [];
          filterOption.options.add(listOption("Change...", "Change", 0));
          filterOption.choosenListValues = [];
        } else if (filterOption.list) {
          filterOption.choosenListValues = [filterOption.options.last.value];
        } else {
          filterOption.choosenValue = filterOption.options.last.search;
        }
      }
    });

    if (name == "New...") {
      widget.server.currentFilterName = "";
      return;
    }

    var SavedQuery = await widget.server.getQuery(widget.userID, name);

    setState(() {
      late RescueGroupsQuery query;
      query = SavedQuery;

      for (var filter in query.data.filters) {
        if (filter.fieldName == "species.singular") {
          continue;
        }

        var filterOption = filteringOptions
            .where((element) => element.fieldName == filter.fieldName)
            .first;

        if (filter.fieldName == "animals.breedPrimaryId") {
          filterOption.choosenListValues = [];
          for (var criteria in filter.criteria) {
            var breed = breeds
                .where((element) => element.rid == int.parse(criteria))
                .first;
            filterOption.options
                .add(listOption(breed.name, breed.name, breed.rid));
            filterOption.choosenListValues.add(breed.id);
          }
          continue;
        }

        if (filterOption.list) {
          filterOption.choosenListValues = [];
          for (var criteria in filter.criteria) {
            filterOption.choosenListValues.add(filterOption.options
                .where((element) => element.displayName == criteria)
                .first
                .value);
          }
        } else {
          filterOption.choosenValue = filterOption.options
              .where((element) => element.displayName == filter.criteria.first)
              .first
              .search;
          if (filterOption.choosenValue == "true" ||
              filterOption.choosenValue == "false") {
            if (filterOption.choosenValue == "true") {
              filterOption.choosenValue = true;
            } else {
              filterOption.choosenValue = false;
            }
          }
        }
      }
      widget.server.currentFilterName = name;
      print("%%%% LOAD SEARCH = " + name);
    });
  }

  final _headerStyle = const TextStyle(
      color: Color(0xffffffff), fontSize: 15, fontWeight: FontWeight.bold);
  final _contentStyleHeader = const TextStyle(
      color: Color(0xff999999), fontSize: 14, fontWeight: FontWeight.w700);
  final _contentStyle = const TextStyle(
      color: Color(0xff999999), fontSize: 14, fontWeight: FontWeight.normal);

  @override
  void dispose() {
    controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<AccordionSection> sections = [];
    for (var category in widget.categoryKeys) {
      print(widget.categories[category].length);
      print(categoryString(category));
      sections.add(AccordionSection(
          isOpen: category == widget.server.whichCategory,
          leftIcon: Icon(icon(category), color: Colors.white),
          headerBackgroundColor: Colors.blue,
          headerBackgroundColorOpened: Colors.grey,
          header: Text(categoryString(category), style: _headerStyle),
          content: ListView.separated(
            separatorBuilder: (BuildContext context, int index) {
              return const Divider(
                height: 20,
                thickness: 2,
                indent: 5,
                endIndent: 0,
                color: Colors.grey,
              );
            },
            padding: const EdgeInsets.all(5),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: widget.categories[category].length,
            itemBuilder: (context, position) {
              if (category == CatClassification.zipCode) {
                return FilterZipCodeRow(
                    position: position,
                    classification: category,
                    filter: widget.categories[category][position]);
              } else {
                return FilterRow(
                  position: position,
                  classification: category,
                  filter: widget.categories[category][position],
                  loadSearch: loadSearch,
                  getQueries: getQueries,
                );
              }
            },
          ),
          contentHorizontalPadding: 10,
          contentBorderWidth: 1,
          onOpenSection: () => widget.server.whichCategory = category));
    }

    var buttonWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text("Search"),
      ),
      // 2
      body: Accordion(
          maxOpenSections: 1,
          headerBackgroundColorOpened: Colors.black54,
          scaleWhenAnimating: true,
          openAndCloseAnimation: true,
          headerPadding:
              const EdgeInsets.symmetric(vertical: 7, horizontal: 15),
          sectionOpeningHapticFeedback: SectionHapticFeedback.heavy,
          sectionClosingHapticFeedback: SectionHapticFeedback.light,
          children: sections),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(height: 50, width: 10),
            TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: TextStyle(color: Color.fromRGBO(255, 255, 255, 1)),
                backgroundColor: Colors.green,
                minimumSize: Size((buttonWidth - 30) / 2, 50),
                maximumSize: Size((buttonWidth - 30) / 2, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onPressed: () => {saveSearch()},
              icon: const Icon(Icons.save_alt, color: Colors.white),
              label: const Text('Save Search',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 50, width: 10),
            TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: TextStyle(color: Color.fromRGBO(255, 255, 255, 1)),
                backgroundColor: Colors.orange,
                minimumSize: Size((buttonWidth - 30) / 2, 50),
                maximumSize: Size((buttonWidth - 30) / 2, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onPressed: () => {Navigator.pop(context, generateFilters())},
              icon: const Icon(
                Icons.search,
                color: Colors.white,
              ),
              label: const Text('Show Results',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 50, width: 10),
          ],
        ),
      ),
    );
  }

  List<Filters> generateFilters() {
    DateTime date = DateTime.now();

    List<Filters> filters = [];
    filters.add(Filters(
        fieldName: "species.singular", operation: "equals", criteria: ["cat"]));
    for (var item in filteringOptions) {
      if (item.classification == CatClassification.saves) {
        continue;
      }
      if (item.classification == CatClassification.sort) {
        if (item.fieldName == "sortBy") {
          if (item.choosenValue == "date") {
            globals.sortMethod = "-animals.updatedDate";
          } else {
            globals.sortMethod = "animals.distance";
          }
        } else if (item.fieldName == "distance") {
          if (item.choosenValue == "" || item.choosenValue == "Any") {
            globals.distance = 1000;
          } else {
            globals.distance = int.parse(item.choosenValue);
          }
        } else if (item.fieldName == "date" &&
            !(item.choosenValue == "" || item.choosenValue == "Any")) {
          if (item.choosenValue == "Day") {
            date = date.subtract(const Duration(days: 1));
          } else if (item.choosenValue == "Week") {
            date = date.subtract(const Duration(days: 7));
          } else if (item.choosenValue == "Month") {
            date = date.subtract(const Duration(days: 30));
          } else if (item.choosenValue == "Year") {
            date = date.subtract(const Duration(days: 365));
          }
          filters.add(Filters(
              fieldName: "animals.updatedDate",
              operation: "greaterthan",
              criteria: date.year.toString() +
                  "-" +
                  date.month.toString() +
                  "-" +
                  date.day.toString() +
                  "T00:00:00Z"));
        }
        continue;
      }
      if (item.list) {
        if (!item.choosenListValues.contains(item.options.last.value) ||
            (item.classification == CatClassification.breed)) {
          List<String> breedList = [];
          for (var choosenValue in item.choosenListValues) {
            if (item.classification == CatClassification.breed) {
              breedList.add(item.options
                  .where((element) =>
                      element.value == breeds[choosenValue - 1].rid)
                  .first
                  .value
                  .toString());
            } else {
              breedList.add(item.options
                  .where((element) => element.value == choosenValue)
                  .first
                  .search);
            }
          }
          if (breedList.isNotEmpty) {
            filters.add(Filters(
                fieldName: item.fieldName,
                operation: "equals",
                criteria: breedList));
          }
        }
      } else {
        if (item.choosenValue == "Any" || item.choosenValue == "") {
          continue;
        }
        filters.add(Filters(
            fieldName: item.fieldName,
            operation: "equals",
            criteria: [item.choosenValue]));
      }
    }
    return filters;
  }
}
