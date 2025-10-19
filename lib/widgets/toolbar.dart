import 'package:catapp/models/shelter.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import '../ExampleCode/petDetailData.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

enum toolType { phone, map, email, share, meet }

enum LaunchMode { marker, directions }

class Tool extends StatelessWidget {
  final toolType tool;
  final PetDetailData? detail;
  final Shelter? shelterData;

  Tool(
      {Key? key,
      required this.tool,
      required this.detail,
      required this.shelterData})
      : super(key: key);

  get apiKey => "AIzaSyBNEcaJtpfNh1ako5P_XexuILvjnPlscdE";

  Widget _buildCircularIcon(
      BuildContext context, IconData iconData, Color iconColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: iconColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        iconData,
        size: 24,
        color: iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (tool) {
      case toolType.phone:
        return InkWell(
            child: Center(
                child: _buildCircularIcon(
                    context, Icons.phone, Colors.green[700]!)),
            onTap: () {
              call(context);
            });
      case toolType.map:
        return InkWell(
            child: Center(
                child: _buildCircularIcon(
                    context, Icons.map, Colors.indigo[600]!)),
            onTap: () {
              map(context);
            });
      case toolType.email:
        return InkWell(
            child: Center(
                child: _buildCircularIcon(
                    context, Icons.email, Colors.deepOrange[600]!)),
            onTap: () {
              email(context);
            });
      case toolType.share:
        return InkWell(
            child: Center(
                child: _buildCircularIcon(
                    context, Icons.share, Colors.deepPurple[600]!)),
            onTap: () {
              share(context);
            });
      case toolType.meet:
        return InkWell(
            child: Center(
                child: _buildCircularIcon(
                    context, Icons.video_call, Colors.teal[600]!)),
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
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: detail?.email ?? "",
      query:
          'subject=${detail?.name ?? "Pet Inquiry"}&body=I would like to talk to you about the cat named ${detail?.name ?? ""} I saw on the app Feline Finder as being available from your organization.',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      // Show error dialog if email can't be launched
      showDialog<String>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Email not available'),
          content: Text('Sorry, email cannot be opened on this device.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    }
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
    try {
      var response = await http.get(Uri.parse(detail!.mainPictures[0].url!));
      String filepath = await getFilePath();
      File file = File(filepath);
      file.writeAsBytesSync(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(filepath)],
        text: detail?.description ?? "",
      );
    } catch (e) {
      // Fallback to text-only sharing if file sharing fails
      await Share.share(
        '${detail?.name ?? "Pet"} - ${detail?.description ?? ""}',
        subject: 'Pet from Feline Finder',
      );
    }
  }

  launchMessenger() async {
    String facebookIdHere = "greg61545";
    String url() {
      if (Platform.isAndroid) {
        String uri = 'fb-messenger://user/$facebookIdHere';
        return uri;
      } else if (Platform.isIOS) {
        // iOS
        String uri =
            'https://www.facebook.com/messages/t/$facebookIdHere?text=test';
        return uri;
      } else {
        return 'error';
      }
    }

    if (await canLaunchUrl(Uri.parse(url()))) {
      await launchUrl(Uri.parse(url()));
    } else {
      throw 'Could not launch ${url()}';
    }
  }

  meet(BuildContext context) {
    launchMessenger();
  }
}

class ToolBar extends StatelessWidget {
  final PetDetailData? detail;
  final Shelter? shelterDetail;
  final List<Tool> tools = [];

  ToolBar({Key? key, required this.detail, required this.shelterDetail})
      : super(key: key);

  List<Tool> getTools(PetDetailData? detail) {
    List<Tool> toolsList = [];
    if (detail == null) {
      return [];
    }
    if (detail.phoneNumber?.trim() != "" && detail.phoneNumber != null) {
      toolsList.add(Tool(
          tool: toolType.phone, detail: detail, shelterData: shelterDetail));
    }

    String address = "";
    if (detail.street != null) {
      address = detail.street!.toUpperCase().replaceAll(" ", "");
    }
    if (address != "" &&
        address.substring(0, "POBOX".length) != "POBOX" &&
        address.substring(0, "P.O.".length) != "P.O.") {
      toolsList.add(
          Tool(tool: toolType.map, detail: detail, shelterData: shelterDetail));
    }

    if (detail.email != null && detail.email?.trim() != "") {
      toolsList.add(Tool(
          tool: toolType.email, detail: detail, shelterData: shelterDetail));
    }

    if (shelterDetail != null &&
        shelterDetail!.data != null &&
        shelterDetail!.data!.length > 0 &&
        shelterDetail!.data![0].attributes != null) {
      toolsList.add(Tool(
          tool: toolType.share, detail: detail, shelterData: shelterDetail));
      Attributes detailAttrib = shelterDetail!.data![0].attributes!;
      if (detailAttrib.facebookUrl != null && detailAttrib.facebookUrl != "") {
        toolsList.add(Tool(
          tool: toolType.meet,
          detail: detail,
          shelterData: shelterDetail,
        ));
      }
    }
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
