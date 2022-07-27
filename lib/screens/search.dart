// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:accordion/accordion.dart';
import 'package:accordion/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
  @override
  void initState() {
    super.initState();
    categorize();
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
          if (filterOption.choosenValue.isEmpty) {
            filterOption.choosenValue = filterOption.options.last.search;
          }
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

  final _headerStyle = const TextStyle(
      color: Color(0xffffffff), fontSize: 15, fontWeight: FontWeight.bold);
  final _contentStyleHeader = const TextStyle(
      color: Color(0xff999999), fontSize: 14, fontWeight: FontWeight.w700);
  final _contentStyle = const TextStyle(
      color: Color(0xff999999), fontSize: 14, fontWeight: FontWeight.normal);

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
                    filter: widget.categories[category][position]);
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
              onPressed: () => {},
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
    List<Filters> filters = [];
    filters.add(Filters(
        fieldName: "species.singular", operation: "equals", criteria: ["cat"]));
    for (var item in filteringOptions) {
      if (item.classification == CatClassification.saves ||
          item.classification == CatClassification.sort) {
        continue;
      }
      if (item.list) {
        if (!item.choosenListValues.contains(item.options.last.value) ||
            (item.classification == CatClassification.breed)) {
          List<String> criteria = [];
          for (var choosenValue in item.choosenListValues) {
            if (item.classification == CatClassification.breed) {
              criteria.add(item.options
                  .where((element) =>
                      element.value == breeds[choosenValue - 1].rid)
                  .first
                  .value
                  .toString());
            } else {
              criteria.add(item.options
                  .where((element) => element.value == choosenValue)
                  .first
                  .search);
            }
          }
          filters.add(Filters(
              fieldName: item.fieldName,
              operation: "equals",
              criteria: criteria));
        }
      } else {
        if (item.choosenValue == "Any") {
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
