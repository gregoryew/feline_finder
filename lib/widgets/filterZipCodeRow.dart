// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:catapp/models/searchPageConfig.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/globals.dart' as globals;

class FilterZipCodeRow extends StatefulWidget {
  final int position;
  final CatClassification classification;
  final filterOption filter;
  const FilterZipCodeRow({
    Key? key,
    required this.position,
    required this.classification,
    required this.filter,
  }) : super(key: key);

  @override
  _FilterZipCodeRow createState() => _FilterZipCodeRow();
}

class _FilterZipCodeRow extends State<FilterZipCodeRow> {
  final _controller = TextEditingController();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  late TextEditingController controller2;
  final server = globals.FelineFinderServer.instance;

  @override
  void initState() {
    super.initState();
    controller2 = TextEditingController();
  }

  Future<String?> openDialog() => showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text("Enter Zip Code"),
              content: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: "Zip Code"),
                controller: controller2,
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(onPressed: submit, child: const Text("Submit"))
              ]));

  void submit() {
    Navigator.of(context).pop(controller2.text);
    controller2.clear();
  }

  void getZipCode() {
    _controller.text = "55555";
    print("Set zip code");
  }

  Future<void> askForZip() async {
    var zip = await openDialog();
    if (zip == null || zip.isEmpty) {
      zip = "66952";
    }
    setState(() {
      server.zip = zip!;
    });
    SharedPreferences prefs = await _prefs;
    prefs.setString("zipCode", zip);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 1, child: Text(widget.filter.name)),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(130, 25),
                      maximumSize: const Size(130, 25)),
                  onPressed: () => {askForZip()},
                  child: Text(server.zip)),
            ],
          ),
        ),
      ],
    );
  }
}
