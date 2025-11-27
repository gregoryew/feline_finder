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

class petDetail extends StatefulWidget {
  final String petID;
  late String userID;
  final server = globals.FelineFinderServer.instance;

  petDetail(
    this.petID, {
    Key? key,
  }) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
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
    // your app's name?
    title: const Text(
      'Feline Finder',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.bold,
      ),
    ),
    // encourage your user to leave a high rating?
    message: const Text(
      'Like the app? Then please rate it.  A review would also be appreciated.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15),
    ),
    // your app's logo?
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
    // Initialize sparkle animation
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
    Map<String, String>? mapKeys;
    () async {
      try {
        user = await widget.server.getUser();
        favorited = await widget.server.isFavorite(user, widget.petID);
        setState(() {
          rescueGroupApi = AppConfig.rescueGroupsApiKey;
          isFavorited = favorited;
          userID = user;
          getPetDetail(widget.petID);
          _controller.addListener(() {
            _scrollListener();
          });
        });
      } catch (e) {
        print("Error initializing pet detail: $e");
        // Set fallback values when Firestore fails
        setState(() {
          rescueGroupApi = AppConfig.rescueGroupsApiKey;
          isFavorited = false;
          userID = "demo-user"; // Fallback user ID
          getPetDetail(widget.petID);
          _controller.addListener(() {
            _scrollListener();
          });
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
      'Content-Type': 'application/json', //; charset=UTF-8',
      'Authorization': rescueGroupApi!
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");
      setState(() {
        shelterDetailInstance = Shelter.fromJson(jsonDecode(response.body));
        loadAsset();
      });
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
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
      'Content-Type': 'application/json', //; charset=UTF-8',
      'Authorization': rescueGroupApi!
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      print("status 200");
      var petDecoded = pet.fromJson(jsonDecode(response.body));
      setState(() {
        petDetailInstance = PetDetailData(
            petDecoded.data![0],
            petDecoded.included!,
            petDecoded.data![0].relationships!.values.toList());
        getShelterDetail(petDetailInstance!.organizationID!);
        loadAsset();
      });
      print("********DD = ${petDetailInstance?.media}");
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
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
                print("userID = ${userID}petID = ${widget.petID}");
                if (isLiked == true) {
                  widget.server.unfavoritePet(userID, widget.petID);
                  isFavorited = false;
                  globals.listOfFavorites.remove(widget.petID);
                } else if (isLiked == false) {
                  Future<SharedPreferences> prefs0 =
                      SharedPreferences.getInstance();
                  final SharedPreferences prefs = await prefs0;
                  if (!prefs.containsKey("RatedApp")) {
                    showDialog(
                      context: context,
                      barrierDismissible:
                          true, // set to false if you want to force a rating
                      builder: (context) => _dialog,
                    );
                  }
                  globals.listOfFavorites.add(widget.petID);
                  widget.server.favoritePet(userID, widget.petID);
                  isFavorited = true;

                  // Trigger sparkle animation when favorited
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
              // Horizontal Scrolling Photo Gallery (full width, no padding)
              if (petDetailInstance == null || petDetailInstance!.media.isEmpty)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.zero,
                  height: 200,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
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
                )
              else
                Builder(
                  builder: (context) {
                    final fixedHeight = 200.0;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final availableWidth = screenWidth;
                    
                    // Calculate total width of all images
                    double totalWidth = 0.0;
                    List<double> imageWidths = [];
                    
                    for (var media in petDetailInstance!.media) {
                      double imageWidth = fixedHeight;
                      
                      // Calculate proportional width based on image aspect ratio
                      if (media is SmallPhoto && petDetailInstance!.mainPictures.isNotEmpty) {
                        // Find matching picture in mainPictures by comparing URLs
                        final photoUrl = media.photo;
                        final matchingPicture = petDetailInstance!.mainPictures.firstWhere(
                          (pic) => pic.url.toString() == photoUrl,
                          orElse: () => petDetailInstance!.mainPictures[0],
                        );
                        
                        // Calculate width based on actual image dimensions
                        if (matchingPicture.resolutionX != null && 
                            matchingPicture.resolutionY != null &&
                            matchingPicture.resolutionX! > 0 &&
                            matchingPicture.resolutionY! > 0) {
                          final aspectRatio = matchingPicture.resolutionX! / matchingPicture.resolutionY!;
                          imageWidth = fixedHeight * aspectRatio;
                        } else {
                          // Default aspect ratio for photos (4:3)
                          imageWidth = fixedHeight * 4 / 3;
                        }
                      } else if (media is YouTubeVideo) {
                        // Standard video aspect ratio (16:9)
                        imageWidth = fixedHeight * 16 / 9;
                      } else {
                        // Default aspect ratio for photos (4:3)
                        imageWidth = fixedHeight * 4 / 3;
                      }
                      
                      // Ensure imageWidth is always positive
                      if (imageWidth <= 0) {
                        imageWidth = fixedHeight * 4 / 3;
                      }
                      
                      imageWidths.add(imageWidth);
                      totalWidth += imageWidth;
                      // Add margin between images (8px between each, except last)
                      if (imageWidths.length < petDetailInstance!.media.length) {
                        totalWidth += 8.0;
                      }
                    }
                    
                    // If total width is less than available width, center and disable scrolling
                    final shouldCenter = totalWidth < availableWidth;
                    
                    // Safety check: ensure imageWidths matches media length
                    if (imageWidths.length != petDetailInstance!.media.length) {
                      // If mismatch, use default widths
                      imageWidths = List.generate(
                        petDetailInstance!.media.length,
                        (index) => fixedHeight * 4 / 3,
                      );
                    }
                    
                    return Container(
                      width: double.infinity,
                      margin: EdgeInsets.zero,
                      height: 200,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.purpleGradient,
                      ),
                      child: petDetailInstance!.media.isEmpty
                          ? const SizedBox.shrink()
                          : (shouldCenter
                              ? Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      petDetailInstance!.media.length,
                                      (index) => _buildMediaItem(
                                        petDetailInstance!.media[index],
                                        imageWidths[index],
                                        fixedHeight,
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
                                  itemBuilder: (context, index) => _buildMediaItem(
                                    petDetailInstance!.media[index],
                                    imageWidths[index],
                                    fixedHeight,
                                    index,
                                    petDetailInstance!.media.length,
                                  ),
                                )),
                    );
                  },
                ),
              // Rest of content with padding
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 5,
                    ),
                    GoldenCard(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 11), // Reduced from 16 to 11 for wider content
                padding: EdgeInsets.all(AppTheme.spacingL),
                backgroundColor: AppTheme.traitCardBackground,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                petDetailInstance == null
                                    ? ""
                                    : petDetailInstance!.name ?? "",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.left,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                petDetailInstance == null
                                    ? ""
                                    : petDetailInstance!.primaryBreed ?? "",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    getStats(),
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Center(
                child: SizedBox(
                  height: 100,
                  child: Center(
                    child: ToolBar(
                        detail: petDetailInstance,
                        shelterDetail: shelterDetailInstance),
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text("General Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 11), // Reduced from 16 to 11 for wider content
                decoration: BoxDecoration(
                  color: AppTheme.traitCardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: AppTheme.goldenBorder,
                  boxShadow: AppTheme.goldenGlow,
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Contact",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  getAddress(petDetailInstance),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
              textBox("DISCLAIMER",
                  "PLEASE READ: Information regarding adoptable pets is provided by the adopting organization and is neither checked for accuracy or completeness nor guaranteed to be accurate or complete.  The health status and behavior of any pet found, adopted through, or listed on the Feline Finder app are sole responsibility of the adoption organization listing the same and/or the adopting party and by using this service, the adopting party releases Feline Finder and Gregory Edward Williams from any and all liability arising out of or in any way connected with the adoption of a pet listed on the Feline Finder app.")
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaItem(dynamic media, double imageWidth, double fixedHeight, int index, int totalCount) {
    final isLast = index == totalCount - 1;
    
    // Ensure imageWidth is positive
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
                        errorWidget: (context, url, error) =>
                            Container(
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
                            mainAxisAlignment:
                                MainAxisAlignment.center,
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
              : CachedNetworkImage(
                  imageUrl: (media as SmallPhoto).photo,
                  fit: BoxFit.cover,
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
                  errorWidget: (context, url, error) =>
                      Container(
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
    );
  }

  Widget textBox(String title, String textBlock) {
    var document = parseFragment(textBlock);
    var textString = document.text ?? "";
    final TextStyle textStyle;
    if (title == "DISCLAIMER") {
      textStyle = GoogleFonts.karla(fontSize: 10, fontWeight: FontWeight.w500);
    } else {
      textStyle = GoogleFonts.karla(fontSize: 16, fontWeight: FontWeight.w500);
    }

    // Get appropriate icon for each section
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 11), // Reduced from 16 to 11 for wider content
      decoration: BoxDecoration(
        color: AppTheme.traitCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: AppTheme.goldenBorder,
        boxShadow: AppTheme.goldenGlow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                getIconForTitle(title),
                color: Colors.white,
                size: 24,
              ),
            ),
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
                  LinkifyText(
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
                ],
              ),
            ),
          ],
        ),
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
    if (petDetailInstance!.status != null) {
      stats.add(petDetailInstance!.status ?? "");
    }
    if (petDetailInstance!.ageGroup != null) {
      stats.add(petDetailInstance!.ageGroup ?? "");
    }
    if (petDetailInstance!.sex != null) {
      stats.add(petDetailInstance!.sex ?? "");
    }
    if (petDetailInstance!.sizeGroup != null) {
      stats.add(petDetailInstance!.sizeGroup ?? "");
    }
    List<Color> foreground = [
      const Color.fromRGBO(101, 164, 43, 1),
      const Color.fromRGBO(3, 122, 254, 1),
      const Color.fromRGBO(245, 76, 10, 1.0),
      Colors.deepPurple
    ];
    List<Color> background = [
      const Color.fromRGBO(222, 234, 209, 1),
      const Color.fromRGBO(209, 224, 239, 1),
      const Color.fromARGB(255, 246, 193, 167),
      Colors.purpleAccent.shade100
    ];
    return Center(
        child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 10,
                runSpacing: 10,
                direction: Axis.horizontal,
                children: stats.map((item) {
                  return Container(
                      width: 100,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: foreground[stats.indexOf(item)]),
                          color: background[stats.indexOf(item)],
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5))),
                      child: Text(stats[stats.indexOf(item)].trim(),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: foreground[stats.indexOf(item)]),
                          textAlign: TextAlign.center));
                }).toList())));
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
