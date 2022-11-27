import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:recipes/screens/petDetail.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import '../ExampleCode/petDetailData.dart';
import 'package:email_launcher/email_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

enum toolType { phone, map, email, share, meet }

enum LaunchMode { marker, directions }

class Tool extends StatelessWidget {
  final toolType tool;
  final PetDetailData? detail;

  Tool({Key? key, required this.tool, required this.detail}) : super(key: key);

  get apiKey => "AIzaSyBNEcaJtpfNh1ako5P_XexuILvjnPlscdE";

  @override
  Widget build(BuildContext context) {
    switch (tool) {
      case toolType.phone:
        return InkWell(
            child: Center(child: Image.asset("assets/Icons/tools_phone.png")),
            onTap: () {
              call(context);
            });
      case toolType.map:
        return InkWell(
            child: Center(child: Image.asset("assets/Icons/tools_map.png")),
            onTap: () {
              map(context);
            });
      case toolType.email:
        return InkWell(
            child: Center(child: Image.asset("assets/Icons/tools_email.png")),
            onTap: () {
              email(context);
            });
      case toolType.share:
        return InkWell(
            child: Center(child: Image.asset("assets/Icons/tools_share.png")),
            onTap: () {
              share(context);
            });
      case toolType.meet:
        return InkWell(
            child: Center(child: Image.asset("assets/Icons/tools_video.png")),
            onTap: () {
              meet(context);
            });
      default:
        return Column();
    }
  }

  call(BuildContext context) {
    launchUrl(Uri.parse("tel://${detail?.phoneNumber ?? ""}"));
  }

  map(BuildContext context) async {
    List<Location> locations = await locationFromAddress(
        "${detail?.street ?? ""}, ${detail?.cityState ?? ""} ${detail?.postalCode ?? ""}");
    print("******************** LAT = " +
        locations[0].latitude.toString() +
        " LONG = " +
        locations[0].longitude.toString());

    //print("***************** LAT = " + data.latitude.toString() + ", LOMG = " + data.longitude.toString());
    if (locations.length == 0) {
      showDialog<String>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Location not found'),
          content: Text(
              'Sorry, there was a problem with the address given and the shelter can not be found.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                print("Not found");
                Navigator.pop(context, 'Ok');
              },
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    } else {
      _launchMap(context, locations[0].latitude, locations[0].longitude);
    }
  }

  _launchMap(BuildContext context, double lat, double lng) async {
    var url = '';
    var urlAppleMaps = '';
    if (Platform.isAndroid) {
      url = "https://www.google.com/maps/search/?api=1&query=${lat},${lng}";
    } else {
      urlAppleMaps = 'https://maps.apple.com/?q=$lat,$lng';
      url = "comgooglemaps://?saddr=&daddr=$lat,$lng&directionsmode=driving";
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else if (await canLaunchUrl(Uri.parse(urlAppleMaps))) {
      await launchUrl(Uri.parse(urlAppleMaps));
    } else {
      throw 'Could not launch $url';
    }
  }

  email(BuildContext context) async {
    Email email = Email(
        to: [detail?.email ?? ""],
        cc: [],
        bcc: [],
        subject: detail?.name ?? "",
        body:
            "I would like to talk to you about the dog named ${detail?.name ?? ""} I saw on the app Feline Finder as being available from your organization.");
    await EmailLauncher.launch(email);
  }

  Future<String> getFilePath() async {
    Directory appDocumentsDirectory =
        await getApplicationDocumentsDirectory(); // 1
    String appDocumentsPath = appDocumentsDirectory.path; // 2
    var userID = const Uuid();
    String filePath = '$appDocumentsPath/${userID.v1()}.jpg';

    return filePath;
  }

  share(BuildContext context) async {
    var response = await http.get(Uri.parse(detail!.mainPictures[0].url!));
    String filepath = await getFilePath();
    File file = File(filepath); // 1
    file.writeAsBytesSync(response.bodyBytes);
    Share.shareFiles([filepath], text: detail?.description ?? "");
  }

  meet(BuildContext context) {
    print("Meet");
  }
}

class ToolBar extends StatelessWidget {
  final PetDetailData? detail;
  final List<Tool> tools = [];

  ToolBar({Key? key, required this.detail}) : super(key: key);

  List<Tool> getTools(PetDetailData? detail) {
    List<Tool> toolsList = [];
    if (detail == null) {
      return [];
    }
    if (detail.phoneNumber?.trim() != "" && detail.phoneNumber != null) {
      toolsList.add(Tool(tool: toolType.phone, detail: detail));
    }

    String address = "";
    if (detail.street != null) {
      address = detail.street!.toUpperCase().replaceAll(" ", "");
    }
    if (address != "" &&
        address.substring(0, "POBOX".length) != "POBOX" &&
        address.substring(0, "P.O.".length) != "P.O.") {
      toolsList.add(Tool(tool: toolType.map, detail: detail));
    }

    if (detail.email != null && detail.email?.trim() != "") {
      toolsList.add(Tool(
        tool: toolType.email,
        detail: detail,
      ));
    }

    toolsList.add(Tool(tool: toolType.share, detail: detail));

/*
    if (detail.email != null && detail.email?.trim() != "") {
      toolsList.add(Tool(
        tool: toolType.meet,
        detail: detail,
      ));
    }
*/
    return toolsList;
  }

  @override
  Widget build(BuildContext context) {
    List<Tool> tools = getTools(detail);
    if (tools.isEmpty) {
      return Column();
    } else {
      return GridView.count(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          crossAxisCount: 1,
          childAspectRatio: 3 / 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: tools);
    }
  }
}
