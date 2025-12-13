import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:like_button/like_button.dart';
import 'package:linkfy_text/linkfy_text.dart';
import 'package:catapp/ExampleCode/Media.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rating_dialog/rating_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/toolbar.dart';
import '../widgets/playIndicator.dart';
import '../widgets/youtube-video-row.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petDetailData.dart';
import '/models/shelter.dart';
import '/models/rescuegroups_v5.dart';
import '../config.dart';
import 'globals.dart' as globals;
import 'package:dots_indicator/dots_indicator.dart';
import 'package:get/get.dart';
import 'package:flutter_network_connectivity/flutter_network_connectivity.dart';
import '../theme.dart';
import '../widgets/design_system.dart';
import '../gold_frame/gold_frame_panel.dart';

class petDetail extends StatefulWidget {
  final String petID;
  late String userID;
  final server = globals.FelineFinderServer.instance;

  petDetail(
    this.petID, {
    Key? key,
  }) : super(key: key);

  @override
  petDetailState createState() {
    return petDetailState();
  }
}

class petDetailState extends State<petDetail>
    with RouteAware, TickerProviderStateMixin {
  PetDetailData? petDetailInstance;
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;
  Shelter? shelterDetailInstance;
  bool isFavorited = false;
  int selectedImage = 0;
  late String userID;
  String? rescueGroupApi = "";
  late final ScrollController _controller = ScrollController();
  late final PageController _pageController = PageController();
  int currentIndexPage = 0;

  final _dialog = RatingDialog(
    initialRating: 1.0,
    title: const Text(
      'Feline Finder',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.bold,
      ),
    ),
    message: const Text(
      'Like the app? Then please rate it.  A review would also be appreciated.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15),
    ),
    image: Image.asset("assets/icon/icon_rating.png"),
    submitButtonText: 'Submit',
    commentHint: 'Please provide a comment here.',
    onCancelled: () => print('cancelled'),
    onSubmitted: (response) async {
      print('rating: ${response.rating}, comment: ${response.comment}');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey("RatedApp")) {
        await prefs.setString("RatedApp", "True");
      }
    },
  );

  @override
  void initState() {
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOut,
    ));

    String user = "";
    bool favorited = false;

    () async {
      try {
        user = await widget.server.getUser();
        favorited = await widget.server.isFavorite(user, widget.petID);
        setState(() {
          rescueGroupApi = AppConfig.rescueGroupsApiKey;
          isFavorited = favorited;
          userID = user;
          getPetDetail(widget.petID);
          _controller.addListener(_scrollListener);
        });
      } catch (e) {
        print("Error initializing pet detail: $e");
        setState(() {
          rescueGroupApi = AppConfig.rescueGroupsApiKey;
          isFavorited = false;
          userID = "demo-user";
          getPetDetail(widget.petID);
          _controller.addListener(_scrollListener);
        });
      }
    }();

    super.initState();
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollListener);
    _controller.dispose();
    _pageController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void getShelterDetail(String orgID) async {
    var url = "https://api.rescuegroups.org/v5/public/orgs/$orgID";

    print("URL = $url");

    var response = await http.get(Uri.parse(url), headers: {
      'Content-Type': 'application/json',
      'Authorization': rescueGroupApi!
    });

    if (response.statusCode == 200) {
      print("status 200");
      setState(() {
        shelterDetailInstance = Shelter.fromJson(jsonDecode(response.body));
        loadAsset();
      });
    } else {
      print("response.statusCode = ${response.statusCode}");
      throw Exception('Failed to load pet ${response.body}');
    }
  }

  void getPetDetail(String petID) async {
    print('Getting Pet Detail');

    String id2 = widget.petID;

    print("id = $id2");

    var url =
        "https://api.rescuegroups.org/v5/public/animals/$id2?fields[animals]=sizeGroup,ageGroup,sex,distance,id,name,breedPrimary,updatedDate,status,descriptionHtml,descriptionText&limit=1";

    print("URL = $url");

    Map<String, dynamic> data = {
      "data": {
        "filterRadius": {"miles": 3000, "postalcode": "94043"},
        "filters": [
          {
            "fieldName": "species.singular",
            "operation": "equal",
            "criteria": "cat"
          }
        ]
      }
    };

    var data2 = RescueGroupsQuery.fromJson(data);

    var response = await http.get(Uri.parse(url), headers: {
      'Content-Type': 'application/json',
      'Authorization': rescueGroupApi!
    });

    if (response.statusCode == 200) {
      print("status 200");
      var petDecoded = pet.fromJson(jsonDecode(response.body));
      setState(() {
        petDetailInstance = PetDetailData(
          petDecoded.data![0],
          petDecoded.included!,
          petDecoded.data![0].relationships!.values.toList(),
        );
        getShelterDetail(petDetailInstance!.organizationID!);
        loadAsset();
      });
      print("********DD = ${petDetailInstance?.media}");
    } else {
      print("response.statusCode = ${response.statusCode}");
      throw Exception('Failed to load pet ${response.body}');
    }
  }

  String getAddress(PetDetailData? petDetailInstance) {
    if (petDetailInstance == null) {
      return "";
    }

    List<String> lines = [];

    if ((petDetailInstance.organizationName ?? "").trim() != "") {
      lines.add((petDetailInstance.organizationName ?? ""));
    }

    if ((petDetailInstance.street ?? "").trim() != "") {
      lines.add(petDetailInstance.street ?? "");
    }

    var thirdLine =
        "${petDetailInstance.cityState ?? " "} ${petDetailInstance.postalCode ?? ""}";
    if (thirdLine.trim() != "") {
      lines.add(thirdLine);
    }

    return lines.join("\n");
  }

  _scrollListener() {
    if (petDetailInstance == null ||
        petDetailInstance!.mediaWidths.length <= 1) {
      return;
    }
    if (_controller.position.pixels == _controller.position.maxScrollExtent) {
      setState(() {
        currentIndexPage = petDetailInstance!.mediaWidths.length - 2;
      });
      return;
    }
    if (_controller.position.pixels == _controller.position.minScrollExtent) {
      setState(() {
        currentIndexPage = 0;
      });
      return;
    }
    double mid = MediaQuery.of(context).size.width / 2;
    var pos = _controller.position.pixels + mid;
    for (var i = 0; i < petDetailInstance!.mediaWidths.length - 1; i++) {
      if (pos > petDetailInstance!.mediaWidths[i] &&
          pos < petDetailInstance!.mediaWidths[i + 1]) {
        setState(() {
          currentIndexPage = i;
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String serveAreas = "Please contact shelter for details.";
    String about = "Please contact shelter for details.";
    String services = "Please contact shelter for details.";
    String adoptionProcess = "Please contact shelter for details.";
    String meetPets = "Please contact shelter for details.";
    String adoptionUrl = "Not Available.";
    String donationUrl = "Not Available.";
    String sponsorshipUrl = "Not Available.";
    String facebookUrl = "Not Available.";

    if (shelterDetailInstance != null &&
        shelterDetailInstance!.data != null &&
        shelterDetailInstance!.data!.isNotEmpty &&
        shelterDetailInstance!.data![0].attributes != null) {
      Attributes detail = shelterDetailInstance!.data![0].attributes!;
      serveAreas = detail.serveAreas ?? "Please contact shelter for details.";
      about = detail.about ?? "Please contact shelter for details.";
      services = detail.services ?? "Please contact shelter for details.";
      adoptionProcess =
          detail.adoptionProcess ?? "Please contact shelter for details.";
      meetPets = detail.meetPets ?? "Please contact shelter for details.";
      facebookUrl = (detail.facebookUrl != null)
          ? "<a href='${detail.facebookUrl}'>${detail.facebookUrl}</a>"
          : "Not Available.";
      adoptionUrl = (detail.adoptionUrl != null)
          ? "<a href='${detail.adoptionUrl}'>${detail.adoptionUrl}</a>"
          : "Not Available.";
      donationUrl = (detail.donationUrl != null)
          ? "<a href='${detail.donationUrl}'>${detail.donationUrl}</a>"
          : "Not Available.";
      sponsorshipUrl = (detail.sponsorshipUrl != null)
          ? "<a href='${detail.sponsorshipUrl}'>${detail.sponsorshipUrl}</a>"
          : "Not Available.";
    }

    return Scaffold(
      backgroundColor: AppTheme.deepPurple,
      appBar: AppBar(
        title: Text(petDetailInstance?.name ?? ""),
        backgroundColor: AppTheme.deepPurple,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: LikeButton(
              onTap: (isLiked) async {
                print("userID = $userID petID = ${widget.petID}");
                if (isLiked == true) {
                  widget.server.unfavoritePet(userID, widget.petID);
                  isFavorited = false;
                  globals.listOfFavorites.remove(widget.petID);
                } else if (isLiked == false) {
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  if (!prefs.containsKey("RatedApp")) {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => _dialog,
                    );
                  }
                  globals.listOfFavorites.add(widget.petID);
                  widget.server.favoritePet(userID, widget.petID);
                  isFavorited = true;

                  _sparkleController.reset();
                  _sparkleController.forward();
                }
                print("Set changed to $isFavorited");
                return isFavorited;
              },
              size: 40,
              isLiked: isFavorited,
              likeBuilder: (isLiked) {
                final color = isLiked ? Colors.red : Colors.blueGrey;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.favorite, color: color, size: 40),
                      if (isLiked)
                        AnimatedBuilder(
                          animation: _sparkleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _sparkleAnimation.value,
                              child: Opacity(
                                opacity: 1.0 - _sparkleAnimation.value,
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.yellow,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gold-framed media gallery (no built-in plaque)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: GoldFramedPanel(
                  plaqueLines: null,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Get actual available space inside the frame
                      final availableHeight = constraints.maxHeight;
                      final availableWidth = constraints.maxWidth;
                      
                      // Image height is available height - 20px
                      final imageHeight = availableHeight > 0 && availableHeight != double.infinity
                          ? availableHeight - 20.0
                          : 200.0;
                      
                      if (petDetailInstance == null ||
                          petDetailInstance!.media.isEmpty) {
                        return Container(
                          width: double.infinity,
                          height: availableHeight > 0 && availableHeight != double.infinity 
                              ? availableHeight 
                              : 200,
                          decoration: const BoxDecoration(
                            gradient: AppTheme.purpleGradient,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.pets,
                                  size: 64,
                                  color: Colors.white,
                                ),
                                SizedBox(height: AppTheme.spacingM),
                                Text(
                                  'No photos available',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTheme.fontSizeM,
                                    fontFamily: AppTheme.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      double totalWidth = 0.0;
                      List<double> imageWidths = [];

                      for (var media in petDetailInstance!.media) {
                        double imageWidth = imageHeight;

                        if (media is SmallPhoto &&
                            petDetailInstance!.mainPictures.isNotEmpty) {
                          final photoUrl = media.photo;
                          final matchingPicture =
                              petDetailInstance!.mainPictures.firstWhere(
                            (pic) => pic.url.toString() == photoUrl,
                            orElse: () => petDetailInstance!.mainPictures[0],
                          );

                          if (matchingPicture.resolutionX != null &&
                              matchingPicture.resolutionY != null &&
                              matchingPicture.resolutionX! > 0 &&
                              matchingPicture.resolutionY! > 0) {
                            final aspectRatio = matchingPicture.resolutionX! /
                                matchingPicture.resolutionY!;
                            imageWidth = imageHeight * aspectRatio;
                          } else {
                            imageWidth = imageHeight * 4 / 3;
                          }
                        } else if (media is YouTubeVideo) {
                          imageWidth = imageHeight * 16 / 9;
                        } else {
                          imageWidth = imageHeight * 4 / 3;
                        }

                        if (imageWidth <= 0) {
                          imageWidth = imageHeight * 4 / 3;
                        }

                        imageWidths.add(imageWidth);
                        totalWidth += imageWidth;
                        if (imageWidths.length <
                            petDetailInstance!.media.length) {
                          totalWidth += 8.0;
                        }
                      }

                      final shouldCenter = totalWidth < availableWidth;

                      if (imageWidths.length !=
                          petDetailInstance!.media.length) {
                        imageWidths = List.generate(
                          petDetailInstance!.media.length,
                          (index) => imageHeight * 4 / 3,
                        );
                      }

                      return Container(
                        width: double.infinity,
                        height: availableHeight > 0 && availableHeight != double.infinity 
                            ? availableHeight 
                            : imageHeight + 20,
                        decoration: const BoxDecoration(
                          gradient: AppTheme.purpleGradient,
                        ),
                        child: petDetailInstance!.media.isEmpty
                            ? const SizedBox.shrink()
                            : (shouldCenter
                                ? Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        petDetailInstance!.media.length,
                                        (index) => _buildMediaItem(
                                          petDetailInstance!.media[index],
                                          imageWidths[index],
                                          imageHeight,
                                          index,
                                          petDetailInstance!.media.length,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.zero,
                                    itemCount: petDetailInstance!.media.length,
                                    itemBuilder: (context, index) =>
                                        _buildMediaItem(
                                      petDetailInstance!.media[index],
                                      imageWidths[index],
                                      imageHeight,
                                      index,
                                      petDetailInstance!.media.length,
                                    ),
                                  )),
                      );
                    },
                  ),
                ),
              ),

              // Name + Breed Plaque (purple with thin gold outline)
              if (petDetailInstance != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: NameBreedPlaque(
                    name: petDetailInstance!.name ?? "",
                    breed: petDetailInstance!.primaryBreed ?? "",
                  ),
                ),

              // Stats badges section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: StatsBadgeSection(
                  child: getStats(),
                ),
              ),

              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  height: 100,
                  child: Center(
                    child: ToolBar(
                      detail: petDetailInstance,
                      shelterDetail: shelterDetailInstance,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Center(
                child: Text(
                  "General Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Contact section using thin gold outline
              ThinGoldSection(
                title: "Contact",
                icon: Icons.location_on_outlined,
                child: Text(
                  getAddress(petDetailInstance),
                  style: GoogleFonts.karla(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              textBox("Description", petDetailInstance?.description ?? ""),
              const SizedBox(height: 20),
              textBox("Serves Area", serveAreas),
              const SizedBox(height: 20),
              textBox("About", about),
              const SizedBox(height: 20),
              textBox("Services", services),
              const SizedBox(height: 20),
              textBox("Adoption Process", adoptionProcess),
              const SizedBox(height: 20),
              textBox("Meet Pets", meetPets),
              const SizedBox(height: 20),
              textBox("Adoption Url", adoptionUrl),
              const SizedBox(height: 20),
              textBox("Facebook Url", facebookUrl),
              const SizedBox(height: 20),
              textBox("Donation Url", donationUrl),
              const SizedBox(height: 20),
              textBox("Sponsorship Url", sponsorshipUrl),
              const SizedBox(height: 20),
              textBox(
                "DISCLAIMER",
                "PLEASE READ: Information regarding adoptable pets is provided by the adopting organization and is neither checked for accuracy or completeness nor guaranteed to be accurate or complete.  The health status and behavior of any pet found, adopted through, or listed on the Feline Finder app are sole responsibility of the adoption organization listing the same and/or the adopting party and by using this service, the adopting party releases Feline Finder and Gregory Edward Williams from any and all liability arising out of or in any way connected with the adoption of a pet listed on the Feline Finder app.",
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaItem(
      dynamic media, double imageWidth, double fixedHeight, int index, int totalCount) {
    final isLast = index == totalCount - 1;
    final safeWidth = imageWidth > 0 ? imageWidth : fixedHeight * 4 / 3;

    return Container(
      margin: EdgeInsets.only(
        right: isLast ? 0 : 8.0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: fixedHeight,
          width: safeWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: media is YouTubeVideo
              ? GestureDetector(
                  onTap: () async {
                    final video = media as YouTubeVideo;
                    final flutterNetworkConnectivity =
                        FlutterNetworkConnectivity(
                      isContinousLookUp: false,
                      lookUpDuration: const Duration(seconds: 5),
                      lookUpUrl: 'www.google.com',
                    );
                    if (await flutterNetworkConnectivity
                        .isInternetConnectionAvailable()) {
                      Get.to(
                        () => YouTubeVideoRow(
                          playlist: null,
                          title: video.title,
                          videoid: video.videoID,
                          fullScreen: false,
                        ),
                      );
                    } else {
                      await Get.defaultDialog(
                        title: "Internet Not Available",
                        middleText:
                            "Viewing videos requires you to be connected to the internet. Please connect to the internet and try again.",
                        backgroundColor: Colors.red,
                        titleStyle: const TextStyle(color: Colors.white),
                        middleTextStyle:
                            const TextStyle(color: Colors.white),
                        textConfirm: "OK",
                        confirmTextColor: Colors.white,
                        onConfirm: () {
                          Get.back();
                        },
                        buttonColor: Colors.black,
                        barrierDismissible: false,
                        radius: 30,
                      );
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: media.photo,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                size: 60,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImageView(
                          imageUrl: (media as SmallPhoto).photo,
                        ),
                      ),
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: (media as SmallPhoto).photo,
                    fit: BoxFit.contain,
                    width: safeWidth,
                    height: fixedHeight,
                    placeholder: (context, url) => Container(
                      width: safeWidth,
                      height: fixedHeight,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: safeWidth,
                      height: fixedHeight,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget textBox(String title, String textBlock) {
    var document = parseFragment(textBlock);
    var textString = document.text ?? "";
    final TextStyle textStyle;
    if (title == "DISCLAIMER") {
      textStyle = GoogleFonts.karla(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      );
    } else {
      textStyle = GoogleFonts.karla(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );
    }

    IconData getIconForTitle(String title) {
      switch (title.toLowerCase()) {
        case 'about':
          return Icons.info_outline;
        case 'services':
          return Icons.medical_services_outlined;
        case 'adoption process':
          return Icons.how_to_reg_outlined;
        case 'meet pets':
          return Icons.pets_outlined;
        case 'adoption url':
          return Icons.link_outlined;
        case 'donation url':
          return Icons.favorite_outline;
        case 'sponsorship url':
          return Icons.support_agent_outlined;
        case 'facebook url':
          return Icons.facebook_outlined;
        case 'disclaimer':
          return Icons.warning_outlined;
        default:
          return Icons.description_outlined;
      }
    }

    return ThinGoldSection(
      title: title,
      icon: getIconForTitle(title),
      child: LinkifyText(
        textString,
        textAlign: TextAlign.left,
        textStyle: textStyle.copyWith(
          color: Colors.white,
          height: 1.5,
        ),
        linkTypes: const [LinkType.email, LinkType.url],
        linkStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
        onTap: (link) => _onOpen(link.value!),
      ),
    );
  }

  Future<void> _onOpen(String link) async {
    var l = Uri.parse((!link.startsWith("http") ? "http://" : "") + link);
    if (await canLaunchUrl(l)) {
      await launchUrl(l);
    } else {
      throw 'Could not launch $link';
    }
  }

  Widget getStats() {
    if (petDetailInstance == null) {
      return const SizedBox.shrink();
    }

    List<String> stats = [];
    if (petDetailInstance!.status != null &&
        petDetailInstance!.status!.trim().isNotEmpty) {
      stats.add(petDetailInstance!.status!.trim());
    }
    if (petDetailInstance!.sex != null &&
        petDetailInstance!.sex!.trim().isNotEmpty) {
      stats.add(petDetailInstance!.sex!.trim());
    }
    if (petDetailInstance!.sizeGroup != null &&
        petDetailInstance!.sizeGroup!.trim().isNotEmpty) {
      stats.add(petDetailInstance!.sizeGroup!.trim());
    }
    if (petDetailInstance!.ageGroup != null &&
        petDetailInstance!.ageGroup!.trim().isNotEmpty) {
      stats.add(petDetailInstance!.ageGroup!.trim());
    }

    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: stats
            .map(
              (item) => GoldOutlineBadge(label: item),
            )
            .toList(),
      ),
    );
  }

  void loadAsset() async {
    String addressString = "";
    addressString = "<h3><table>";
    if (petDetailInstance?.organizationName != "") {
      addressString =
          "$addressString<tr><td><b>${petDetailInstance?.organizationName ?? ""}</b></td></tr>";
    }
    if (petDetailInstance?.street != "") {
      addressString =
          "$addressString<tr><td><b>${petDetailInstance?.street ?? ""}</b></td></tr>";
    }
    if (petDetailInstance?.cityState != "") {
      addressString =
          "$addressString<tr><td><b>${petDetailInstance?.cityState ?? ""} ${petDetailInstance?.postalCode ?? ""}</b></td></tr></table></h3>";
    }

    final String description = petDetailInstance?.description ?? "";

    String serveAreas = "Please contact shelter for details.";
    String about = "Please contact shelter for details.";
    String services = "Please contact shelter for details.";
    String adoptionProcess = "Please contact shelter for details.";
    String meetPets = "Please contact shelter for details.";
    String adoptionUrl = "Not Available.";
    String donationUrl = "Not Available.";
    String sponsorshipUrl = "Not Available.";
    String facebookUrl = "Not Available.";
    String rescueOrgID = "?";
    String animalID = "?";

    if (shelterDetailInstance != null &&
        shelterDetailInstance!.data != null &&
        shelterDetailInstance!.data!.isNotEmpty &&
        shelterDetailInstance!.data![0].attributes != null) {
      Attributes detail = shelterDetailInstance!.data![0].attributes!;
      animalID = petDetailInstance?.id ?? "?";
      rescueOrgID = shelterDetailInstance!.data![0].id ?? "?";
      serveAreas = detail.serveAreas ?? "Please contact shelter for details.";
      about = detail.about ?? "Please contact shelter for details.";
      services = detail.services ?? "Please contact shelter for details.";
      adoptionProcess =
          detail.adoptionProcess ?? "Please contact shelter for details.";
      meetPets = detail.meetPets ?? "Please contact shelter for details.";
      facebookUrl = (detail.facebookUrl != null)
          ? "<a href='${detail.facebookUrl}'>${detail.facebookUrl}</a>"
          : "Not Available.";
      adoptionUrl = (detail.adoptionUrl != null)
          ? "<a href='${detail.adoptionUrl}'>${detail.adoptionUrl}</a>"
          : "Not Available.";
      donationUrl = (detail.donationUrl != null)
          ? "<a href='${detail.donationUrl}'>${detail.donationUrl}</a>"
          : "Not Available.";
      sponsorshipUrl = (detail.sponsorshipUrl != null)
          ? "<a href='${detail.sponsorshipUrl}'>${detail.sponsorshipUrl}</a>"
          : "Not Available.";
    }
  }

  double calculateRatio(Large pd, double width) {
    return (pd.resolutionY! / pd.resolutionX!) * width;
  }

  Widget getImage(PetDetailData? pd) {
    if (pd == null) {
      return const CircularProgressIndicator();
    } else {
      return (pd.mainPictures.isEmpty)
          ? Image.asset("assets/Icons/No_Cat_Image.png")
          : CachedNetworkImage(
              placeholder: (BuildContext context, String url) => Container(
                  width: MediaQuery.of(context).size.width,
                  height: calculateRatio(pd.mainPictures[selectedImage],
                      MediaQuery.of(context).size.width),
                  color: Colors.grey),
              imageUrl: pd.mainPictures[selectedImage].url.toString());
    }
  }

  List<Widget> getMedia(PetDetailData? pd) {
    if (pd != null) {
      List<Widget> list = [];
      for (var el in pd.media) {
        list.add(const SizedBox(width: 5));
        list.add(el);
      }
      return list;
    }
    return [];
  }

  List<ShapeBorder> getShapes(PetDetailData? pd) {
    if (pd != null) {
      List<ShapeBorder> list = [];
      for (var el in pd.media) {
        if (el is YouTubeVideo) {
          list.add(const CustomPlayIndicatorBorder());
        } else {
          list.add(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
          );
        }
      }
      return list;
    }
    return [];
  }
}

/// Full-screen image viewer
class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
// 👇 New reusable widgets for the Option A mockup
//

class NameBreedPlaque extends StatelessWidget {
  final String name;
  final String breed;

  const NameBreedPlaque({
    Key? key,
    required this.name,
    required this.breed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.goldenBorder.top.color;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.traitCardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          if (breed.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              breed,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GoldOutlineBadge extends StatelessWidget {
  final String label;

  const GoldOutlineBadge({
    Key? key,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.goldenBorder.top.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.traitCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.karla(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class StatsBadgeSection extends StatelessWidget {
  final Widget child;

  const StatsBadgeSection({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.goldenBorder.top.color;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.traitCardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GoldIconBox extends StatelessWidget {
  final IconData icon;

  const GoldIconBox({
    Key? key,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.goldenBorder.top.color;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

class ThinGoldSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const ThinGoldSection({
    Key? key,
    required this.title,
    required this.icon,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.goldenBorder.top.color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 11),
      decoration: BoxDecoration(
        color: AppTheme.traitCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GoldIconBox(icon: icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}