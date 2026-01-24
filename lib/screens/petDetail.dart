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
import 'webview_screen.dart';
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
  late AnimationController _favoriteAnimationController;
  late Animation<Offset> _favoritePositionAnimation;
  Shelter? shelterDetailInstance;
  bool isFavorited = false;
  bool _showFavoriteAnimation = false;
  int _favoriteAnimationKey = 0; // Key to force GIF reload
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

    // Initialize favorite animation controller
    _favoriteAnimationController = AnimationController(
      duration: const Duration(seconds: 6), // 1 second to center + 4 seconds wait + 1 second to bottom
      vsync: this,
    );
    
    // Animation: start at top (off-screen), move to center, wait, then drop to bottom
    _favoritePositionAnimation = TweenSequence<Offset>([
      // Phase 1: Drop to center (1 second)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0, -1.5), // Start above screen
          end: const Offset(0, 0), // Center of screen
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1.0,
      ),
      // Phase 2: Wait at center (4 seconds)
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0, 0)),
        weight: 4.0,
      ),
      // Phase 3: Drop to bottom (1 second)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0, 0), // Center
          end: const Offset(0, 2.0), // Bottom of screen (off-screen)
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1.0,
      ),
    ]).animate(_favoriteAnimationController);

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
    _favoriteAnimationController.dispose();
    super.dispose();
  }

  void _startFavoriteAnimation() {
    // Stop any ongoing animation first
    _favoriteAnimationController.stop();
    
    setState(() {
      _showFavoriteAnimation = false; // Hide first to ensure rebuild
      _favoriteAnimationKey++; // Increment key to force GIF reload
    });
    
    // Small delay to ensure the widget tree updates
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _showFavoriteAnimation = true;
        });
        _favoriteAnimationController.reset();
        _favoriteAnimationController.forward().then((_) {
          // After animation completes, hide the widget
          if (mounted) {
            setState(() {
              _showFavoriteAnimation = false;
            });
          }
        });
      }
    });
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
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: () async {
                print("userID = $userID petID = ${widget.petID}");
                if (isFavorited) {
                  widget.server.unfavoritePet(userID, widget.petID);
                  setState(() {
                    isFavorited = false;
                  });
                  globals.listOfFavorites.remove(widget.petID);
                } else {
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
                  setState(() {
                    isFavorited = true;
                  });

                  _sparkleController.reset();
                  _sparkleController.forward();
                  
                  // Trigger favorite animation
                  _startFavoriteAnimation();
                }
                print("Set changed to $isFavorited");
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFBE7A1), // highlight
                      Color(0xFFE0A93C), // body gold
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFFC3922E),
                    width: 2.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      offset: Offset(1, 2),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                      colors: [
                        Color(0xFFEAC46E),
                        Color(0xFFC58F2B),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFB07A26),
                      width: 1.3,
                    ),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: isFavorited ? Colors.pinkAccent : Colors.white,
                          size: 26,
                          shadows: const [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                        if (isFavorited)
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: GoldFramedPanel(
                  plaqueLines: null,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Get actual available space inside the frame
                      final availableHeight = constraints.maxHeight;
                      final availableWidth = constraints.maxWidth;
                      
                      // Image height fills the full available height (touches top and bottom)
                      final imageHeight = availableHeight > 0 && availableHeight != double.infinity
                          ? availableHeight
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

                      // Use PageView to show one image at a time
                      return SizedBox(
                        width: double.infinity,
                        height: availableHeight > 0 && availableHeight != double.infinity 
                            ? availableHeight 
                            : imageHeight,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: AppTheme.purpleGradient,
                          ),
                          child: petDetailInstance!.media.isEmpty
                              ? const SizedBox.shrink()
                              : Stack(
                                  children: [
                                    // PageView for swiping through images
                                    PageView.builder(
                                      controller: _pageController,
                                      itemCount: petDetailInstance!.media.length,
                                      onPageChanged: (index) {
                                        setState(() {
                                          currentIndexPage = index;
                                        });
                                      },
                                      itemBuilder: (context, index) {
                                        // Calculate width based on aspect ratio
                                        double imageWidth = imageHeight;
                                        final media = petDetailInstance!.media[index];
                                        
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

                                        // Center the image
                                        return Center(
                                          child: _buildMediaItem(
                                            media,
                                            imageWidth,
                                            imageHeight,
                                            index,
                                            petDetailInstance!.media.length,
                                          ),
                                        );
                                      },
                                    ),
                                    // Page indicator dots at the bottom
                                    if (petDetailInstance!.media.length > 1)
                                      Positioned(
                                        bottom: 10,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(
                                            petDetailInstance!.media.length,
                                            (index) => Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.symmetric(horizontal: 4),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: currentIndexPage == index
                                                    ? AppTheme.goldBase
                                                    : Colors.white.withOpacity(0.5),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Name + Breed Plaque (purple with thin gold outline)
              if (petDetailInstance != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: NameBreedPlaque(
                    name: petDetailInstance!.name ?? "",
                    breed: petDetailInstance!.primaryBreed ?? "",
                  ),
                ),

              const SizedBox(height: 5),
              Center(
                child: SizedBox(
                  height: 80,
                  child: Center(
                    child: ToolBar(
                      detail: petDetailInstance,
                      shelterDetail: shelterDetailInstance,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

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
              const SizedBox(height: 10),

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

              const SizedBox(height: 12),
              textBox("Description", petDetailInstance?.description ?? ""),
              const SizedBox(height: 12),
              textBox("Serves Area", serveAreas),
              const SizedBox(height: 12),
              textBox("About", about),
              const SizedBox(height: 12),
              textBox("Services", services),
              const SizedBox(height: 12),
              textBox("Adoption Process", adoptionProcess),
              const SizedBox(height: 12),
              textBox("Meet Pets", meetPets),
              const SizedBox(height: 12),
              textBox("Adoption Url", adoptionUrl),
              const SizedBox(height: 12),
              textBox("Facebook Url", facebookUrl),
              const SizedBox(height: 12),
              textBox("Donation Url", donationUrl),
              const SizedBox(height: 12),
              textBox("Sponsorship Url", sponsorshipUrl),
              const SizedBox(height: 12),
              textBox(
                "DISCLAIMER",
                "PLEASE READ: Information regarding adoptable pets is provided by the adopting organization and is neither checked for accuracy or completeness nor guaranteed to be accurate or complete.  The health status and behavior of any pet found, adopted through, or listed on the Feline Finder app are sole responsibility of the adoption organization listing the same and/or the adopting party and by using this service, the adopting party releases Feline Finder and Gregory Edward Williams from any and all liability arising out of or in any way connected with the adoption of a pet listed on the Feline Finder app.",
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
          // Favorite animation overlay
          if (_showFavoriteAnimation)
            _buildFavoriteAnimation(),
        ],
      ),
    );
  }

  Widget _buildFavoriteAnimation() {
    return IgnorePointer(
      ignoring: true, // Don't block touches
      child: SlideTransition(
        position: _favoritePositionAnimation,
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 200,
            height: 200,
            child: Image.asset(
              'assets/Animation/screens/favorite.gif',
              key: ValueKey('favorite_gif_$_favoriteAnimationKey'), // Force reload with unique key
              fit: BoxFit.contain,
              cacheWidth: null, // Don't cache width
              cacheHeight: null, // Don't cache height
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.favorite, size: 50, color: Colors.pink),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaItem(
      dynamic media, double imageWidth, double fixedHeight, int index, int totalCount) {
    final safeWidth = imageWidth > 0 ? imageWidth : fixedHeight * 4 / 3;

    return Container(
      // No margin needed for PageView
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
                    fit: BoxFit.fitHeight,
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
    
    // Extract URLs from HTML <a> tags and ensure they're in the text with proper protocol
    // This ensures URLs in HTML links are also detected by LinkifyText
    final linkElements = document.querySelectorAll('a[href]');
    for (var link in linkElements) {
      final href = link.attributes['href'];
      final linkText = link.text.trim();
      if (href != null && href.isNotEmpty) {
        // Clean the href (remove HTML entities and whitespace)
        String cleanHref = href.trim();
        final originalHref = cleanHref;
        
        // Ensure URL has a protocol for proper detection by LinkifyText
        if (!cleanHref.startsWith('http://') && !cleanHref.startsWith('https://')) {
          // Special handling for Facebook URLs - construct full URL if needed
          if (title.toLowerCase().contains('facebook') || 
              cleanHref.contains('facebook.com') ||
              (!cleanHref.contains('.') && !cleanHref.startsWith('/'))) {
            // If it's a Facebook URL section and doesn't contain a domain, construct it
            if (!cleanHref.contains('facebook.com') && !cleanHref.contains('.')) {
              // Might be just a page name - construct Facebook URL
              if (cleanHref.startsWith('/')) {
                cleanHref = 'https://www.facebook.com$cleanHref';
              } else {
                cleanHref = 'https://www.facebook.com/$cleanHref';
              }
            } else {
              cleanHref = 'https://$cleanHref';
            }
          } else {
            cleanHref = 'https://$cleanHref';
          }
        }
        
        // Check if URL (with or without protocol) is already in text
        final hasProtocol = originalHref.startsWith('http://') || originalHref.startsWith('https://');
        final urlInText = textString.contains(cleanHref) || 
                         (!hasProtocol && textString.contains(originalHref));
        
        if (!urlInText) {
          // URL not in text - add it
          if (linkText.isNotEmpty && linkText != originalHref && linkText != cleanHref) {
            // Link text is different from URL - add URL after link text
            textString = textString.replaceFirst(linkText, '$linkText ($cleanHref)');
          } else {
            // Link text is same as URL or empty - add URL with protocol
            textString += ' $cleanHref';
          }
        } else {
          // URL is in text - ensure it has protocol for LinkifyText to detect it
          if (!hasProtocol && textString.contains(originalHref)) {
            // Replace URL without protocol with URL that has protocol
            // Use word boundaries to avoid partial matches
            // Replace only if it's a standalone word (not part of another URL)
            final regex = RegExp(r'\b' + RegExp.escape(originalHref) + r'\b');
            textString = textString.replaceAll(regex, cleanHref);
          }
        }
      }
    }
    
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
        linkStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
          decorationThickness: 1.5,
        ),
        onTap: (link) => _onOpen(link.value!),
      ),
    );
  }

  Future<void> _onOpen(String link) async {
    if (link.isEmpty || link.trim().isEmpty) {
      // Show error if URL is empty
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Clean and validate URL
    String url = link.trim();
    
    // Remove any leading/trailing quotes
    if (url.startsWith('"') || url.startsWith("'")) {
      url = url.substring(1);
    }
    if (url.endsWith('"') || url.endsWith("'")) {
      url = url.substring(0, url.length - 1);
    }
    
    // Remove any trailing punctuation that might have been included
    url = url.trim();
    
    // Ensure URL has a protocol - this is critical!
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      // Check if it looks like a URL (contains a dot or is a known domain)
      if (url.contains('.') || url.startsWith('www.')) {
        url = "https://$url";
      } else {
        // Might be a relative path or invalid - try to construct a valid URL
        // For Facebook URLs, construct the full URL
        if (url.contains('facebook') || url.startsWith('/')) {
          if (url.startsWith('/')) {
            url = "https://www.facebook.com$url";
          } else {
            url = "https://www.facebook.com/$url";
          }
        } else {
          // Try adding https:// anyway
          url = "https://$url";
        }
      }
    }
    
    // Final validation - ensure URL is properly formatted
    try {
      final uri = Uri.parse(url);
      
      // Double-check the scheme
      if (!uri.hasScheme) {
        // If somehow the scheme is missing, add it
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
          url = "https://$url";
          // Re-parse after adding scheme
          final reParsed = Uri.parse(url);
          if (!reParsed.hasScheme || !reParsed.scheme.startsWith('http')) {
            throw FormatException('Invalid URL scheme after repair');
          }
        } else {
          throw FormatException('Invalid URL scheme');
        }
      } else if (!uri.scheme.startsWith('http')) {
        throw FormatException('URL scheme must be http or https');
      }
      
      // Ensure we have a valid host
      if (uri.host.isEmpty && uri.path.isEmpty) {
        throw FormatException('URL must have a host or path');
      }
      
      // Navigate to in-app web browser with the validated URL
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              url: url, // Use the validated and fixed URL
              title: _getUrlTitle(url),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error if URL is invalid
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid URL: ${link.length > 50 ? "${link.substring(0, 50)}..." : link}\nError: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      print('URL parsing error: $e\nOriginal link: $link\nProcessed URL: $url');
    }
  }
  
  String _getUrlTitle(String url) {
    // Extract a readable title from the URL
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      // Remove www. prefix if present
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      // Capitalize first letter
      if (host.isNotEmpty) {
        host = host[0].toUpperCase() + host.substring(1);
      }
      return host;
    } catch (e) {
      return 'Web Page';
    }
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomPaint(
        painter: _GoldRibbonPainter(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (breed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  breed,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    // Create gold gradient
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.goldHighlight,
        AppTheme.goldBase,
        AppTheme.goldShadow,
        AppTheme.goldBase,
        AppTheme.goldHighlight,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = gradient.createShader(rect);
    
    // Draw flowing ribbon shape with wavy edges
    final path = Path();
    const waveHeight = 8.0;
    const waveLength = 40.0;
    
    // Top wavy edge
    path.moveTo(0, waveHeight);
    for (double x = 0; x <= size.width; x += waveLength) {
      path.quadraticBezierTo(
        x + waveLength / 2,
        x % (waveLength * 2) == 0 ? 0 : waveHeight * 2,
        x + waveLength,
        waveHeight,
      );
    }
    
    // Right edge
    path.lineTo(size.width, size.height - waveHeight);
    
    // Bottom wavy edge - out of phase with top for flowing ribbon effect
    // Iterate from right to left, but use x-from-left for pattern matching
    double currentX = size.width;
    while (currentX > 0) {
      final nextX = (currentX - waveLength).clamp(0.0, size.width);
      final xFromLeft = size.width - currentX;
      final controlX = currentX - waveLength / 2;
      // Offset by waveLength to be out of phase (peaks align with valleys)
      final controlY = (xFromLeft + waveLength) % (waveLength * 2) == 0 
          ? size.height 
          : size.height - waveHeight * 2;
      
      path.quadraticBezierTo(
        controlX,
        controlY,
        nextX,
        size.height - waveHeight,
      );
      currentX = nextX;
    }
    
    // Left edge
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Add gold border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppTheme.goldShadow
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoldIconBox extends StatelessWidget {
  final IconData icon;

  const GoldIconBox({
    Key? key,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 3D purple gradient matching the pills
    final purple3DGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF9B7BB8), // Lighter purple (top highlight)
        const Color(0xFF7A5A96), // Medium purple
        const Color(0xFF6B4C93), // Darker purple (bottom shadow)
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: purple3DGradient,
        boxShadow: [
          // Outer shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
          // Inner highlight for 3D effect
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 4,
            spreadRadius: -2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 22,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppTheme.purpleGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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