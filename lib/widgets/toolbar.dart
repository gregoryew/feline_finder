import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:recipes/screens/petDetail.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import '../ExampleCode/petDetailData.dart';

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

  email(BuildContext context) {
    // Emailer email = Emailer(detail: detail!);
    // email.
  }

  share(BuildContext context) {
    print("Share");
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

    if (detail.email != null && detail.email?.trim() != "") {
      toolsList.add(Tool(
        tool: toolType.meet,
        detail: detail,
      ));
    }

    return toolsList;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        crossAxisCount: 1,
        childAspectRatio: 3 / 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: getTools(detail));
  }
}

class Emailer extends StatefulWidget {
  const Emailer({Key? key, required PetDetailData detail}) : super(key: key);

  @override
  _Emailer createState() => _Emailer();
}

class _Emailer extends State<Emailer> {
  bool useTempDirectory = true;
  List<String> attachment = <String>[];
  final TextEditingController _subjectController =
      TextEditingController(text: 'the Subject');
  final TextEditingController _bodyController = TextEditingController(
      text: '''  <em>the body has <code>HTML</code></em> <br><br><br>
  <strong>Some Apps like Gmail might ignore it</strong>
  ''');
  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> send(BuildContext context) async {
    if (Platform.isIOS) {
      final bool canSend = await FlutterMailer.canSendMail();
      if (!canSend) {
        const SnackBar snackbar =
            const SnackBar(content: Text('no Email App Available'));
        ScaffoldMessenger.of(context).showSnackBar(snackbar);
        return;
      }
    }

    // Platform messages may fail, so we use a try/catch PlatformException.
    final MailOptions mailOptions = MailOptions(
      body: _bodyController.text,
      subject: _subjectController.text,
      recipients: <String>['example@example.com'],
      isHTML: true,
      // bccRecipients: ['other@example.com'],
      ccRecipients: <String>['third@example.com'],
      attachments: attachment,
    );

    String platformResponse;

    try {
      final MailerResponse response = await FlutterMailer.send(mailOptions);
      switch (response) {
        case MailerResponse.saved:
          platformResponse = 'mail was saved to draft';
          break;
        case MailerResponse.sent:
          platformResponse = 'mail was sent';
          break;
        case MailerResponse.cancelled:
          platformResponse = 'mail was cancelled';
          break;
        case MailerResponse.android:
          platformResponse = 'intent was success';
          break;
        default:
          platformResponse = 'unknown';
          break;
      }
    } on PlatformException catch (error) {
      platformResponse = error.toString();
      print(error);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Message',
                style: Theme.of(context).textTheme.subtitle1,
              ),
              Text(error.message ?? 'unknown error'),
            ],
          ),
          contentPadding: const EdgeInsets.all(26),
          title: Text(error.code),
        ),
      );
    } catch (error) {
      platformResponse = error.toString();
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(platformResponse),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Widget imagePath = GridView.count(
      primary: false,
      scrollDirection: Axis.vertical,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      crossAxisCount: 2,
      shrinkWrap: true,
      children: List<Widget>.generate(
        attachment.length,
        (int index) {
          final File file = File(attachment[index]);
          return GridTile(
            key: Key(attachment[index]),
            footer: GridTileBar(
              title: Text(
                file.path.split('/').last,
                textAlign: TextAlign.justify,
              ),
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      child: Image.file(
                        File(attachment[index]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.attachment,
                          size: 50,
                          color: Theme.of(context).primaryIconTheme.color,
                        ),
                      ),
                    )),
                Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    borderRadius: BorderRadius.circular(59),
                    type: MaterialType.transparency,
                    child: IconButton(
                      tooltip: 'remove',
                      onPressed: () {
                        setState(() {
                          attachment.removeAt(index);
                        });
                      },
                      padding: const EdgeInsets.all(10),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(context).primaryIconTheme.color,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return MaterialApp(
      theme: ThemeData.light().copyWith(primaryColor: Colors.red),
      darkTheme: ThemeData.dark().copyWith(primaryColor: Colors.deepOrange),
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Mailer Example'),
          actions: <Widget>[
            Builder(builder: (context) {
              return IconButton(
                onPressed: () => send(context),
                icon: const Icon(Icons.send),
              );
            })
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Subject',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _bodyController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Body',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  imagePath,
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.camera),
          label: const Text('Add Image'),
          onPressed: _picker,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: BottomAppBar(
          notchMargin: 4.0,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Builder(
                builder: (BuildContext context) => TextButton(
                  style: TextButton.styleFrom(
                    primary: Theme.of(context).primaryColor,
                  ),
                  child: const Text('add text File'),
                  onPressed: () => _onCreateFile(context),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _picker() async {
    final pick = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pick != null) {
      setState(() {
        attachment.add(pick.path);
      });
    }
  }

  /// create a text file in Temporary Directory to share.
  void _onCreateFile(BuildContext context) async {
    final TempFile? tempFile = await _showDialog(context);
    if (tempFile != null) {
      final File newFile = await writeFile(tempFile.content, tempFile.name);
      setState(() {
        attachment.add(newFile.path);
      });
    }
  }

  /// some A simple dialog and return fileName and content
  Future<TempFile?> _showDialog(BuildContext context) {
    return showDialog<TempFile>(
      context: context,
      builder: (BuildContext context) {
        String content = '';
        String fileName = '';

        return SimpleDialog(
          title: const Text('write something to a file'),
          contentPadding: const EdgeInsets.all(8.0),
          children: <Widget>[
            TextField(
              onChanged: (String str) => fileName = str,
              autofocus: true,
              decoration: const InputDecoration(
                suffix: const Text('.txt'),
                labelText: 'file name',
                alignLabelWithHint: true,
              ),
            ),
            TextField(
              decoration: const InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                alignLabelWithHint: true,
                labelText: 'Content',
              ),
              keyboardType: TextInputType.multiline,
              onChanged: (String str) => content = str,
              maxLines: 3,
            ),
            Row(
              children: [
                Text(
                  'use Temp directory',
                  style: Theme.of(context).textTheme.caption,
                ),
                Switch(
                  value: useTempDirectory,
                  onChanged: Platform.isAndroid
                      ? (bool useTemp) {
                          setState(() {
                            useTempDirectory = useTemp;
                          });
                        }
                      : null,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Theme.of(context).colorScheme.secondary,
                    onPrimary: Theme.of(context).colorScheme.secondary,
                  ),
                  child: const Icon(Icons.save),
                  onPressed: () {
                    final TempFile tempFile =
                        TempFile(content: content, name: fileName);
                    // Map.from({'content': content, 'fileName': fileName});
                    Navigator.of(context).pop<TempFile>(tempFile);
                  },
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Future<String> get _tempPath async {
    final Directory directory = await getTemporaryDirectory();

    return directory.path;
  }

  Future<String> get _localAppPath async {
    final Directory directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> _localFile(String fileName) async {
    final String path = await (useTempDirectory ? _tempPath : _localAppPath);
    return File('$path/$fileName.txt');
  }

  Future<File> writeFile(String text, [String fileName = '']) async {
    fileName = fileName.isNotEmpty ? fileName : 'fileName';
    final File file = await _localFile(fileName);

    // Write the file
    return file.writeAsString('$text');
  }
}

class TempFile {
  TempFile({required this.name, required this.content});
  final String name, content;
}
