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
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petDetailData.dart';
import '/models/shelter.dart';
import '/models/rescuegroups_v5.dart';
import '../config.dart';
import 'globals.dart' as globals;
import 'package:dots_indicator/dots_indicator.dart';

class petDetail extends StatefulWidget {
  final String petID;
  late String userID;
  final server = globals.FelineFinderServer.instance;

  petDetail(
    this.petID,
  );

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
  late ScrollController _controller = ScrollController();
  late PageController _pageController = PageController();
  int currentIndexPage = 0;

  final _dialog = RatingDialog(
    initialRating: 1.0,
    // your app's name?
    title: Text(
      'Feline Finder',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.bold,
      ),
    ),
    // encourage your user to leave a high rating?
    message: Text(
      'Like the app? Then please rate it.  A review would also be appreciated.',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15),
    ),
    // your app's logo?
    image: Image.asset("assets/icon/icon_rating.png"),
    submitButtonText: 'Submit',
    commentHint: 'Please provide a comment here.',
    onCancelled: () => print('cancelled'),
    onSubmitted: (response) async {
      print('rating: ${response.rating}, comment: ${response.comment}');
      Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
      final SharedPreferences prefs = await _prefs;
      if (!prefs.containsKey("RatedApp")) {
        await prefs.setString("RatedApp", "True");
      }
    },
  );

  @override
  void initState() {
    // Initialize sparkle animation
    _sparkleController = AnimationController(
      duration: Duration(milliseconds: 1000),
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
    var url = "https://api.rescuegroups.org/v5/public/orgs/${orgID}";

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
      print("response.statusCode = " + response.statusCode.toString());
      throw Exception('Failed to load pet ' + response.body);
    }
  }

  void getPetDetail(String petID) async {
    print('Getting Pet Detail');

    String id2 = widget.petID;

    print("id = ${id2}");

    var url =
        "https://api.rescuegroups.org/v5/public/animals/${id2}?fields[animals]=sizeGroup,ageGroup,sex,distance,id,name,breedPrimary,updatedDate,status,descriptionHtml,descriptionText&limit=1";

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
      print("response.statusCode = " + response.statusCode.toString());
      throw Exception('Failed to load pet ' + response.body);
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

    var thirdLine = (petDetailInstance.cityState ?? " ") +
        " " +
        (petDetailInstance.postalCode ?? "");
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
      appBar: AppBar(
        title: Text(petDetailInstance?.name ?? ""),
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 10.0),
            child: LikeButton(
              onTap: (isLiked) async {
                print("userID = " +
                    userID.toString() +
                    "petID = " +
                    widget.petID.toString());
                if (isLiked == true) {
                  widget.server.unfavoritePet(userID, widget.petID);
                  isFavorited = false;
                  globals.listOfFavorites.remove(widget.petID);
                } else if (isLiked == false) {
                  Future<SharedPreferences> _prefs =
                      SharedPreferences.getInstance();
                  final SharedPreferences prefs = await _prefs;
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
                print("Set changed to " + isFavorited.toString());
                return isFavorited;
              },
              size: 40,
              isLiked: isFavorited,
              likeBuilder: (isLiked) {
                final color = isLiked ? Colors.red : Colors.blueGrey;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
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
                                child: Icon(
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // Modern Photo Carousel
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9, // Standard widescreen ratio
                    child: Stack(
                      children: [
                        // Main carousel
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              currentIndexPage = index;
                            });
                          },
                          itemCount: petDetailInstance?.media.length ?? 0,
                          itemBuilder: (context, index) {
                            if (petDetailInstance == null ||
                                petDetailInstance!.media.isEmpty) {
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.pets,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No photos available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final media = petDetailInstance!.media[index];
                            return Container(
                              width: double.infinity,
                              child: media is YouTubeVideo
                                  ? Container(
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(media.photo),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      child: Container(
                                        color: Colors.black.withOpacity(0.3),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.play_circle_filled,
                                                size: 80,
                                                color: Colors.white,
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'Video Available',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: (media as SmallPhoto).photo,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                size: 64,
                                                color: Colors.grey[400],
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),

                        // Photo counter overlay
                        if (petDetailInstance != null &&
                            petDetailInstance!.media.length > 1)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${currentIndexPage + 1} / ${petDetailInstance!.media.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Dots indicator at bottom
                        if (petDetailInstance != null &&
                            petDetailInstance!.media.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: DotsIndicator(
                                decorator: DotsDecorator(
                                  color: Colors.white.withOpacity(0.5),
                                  activeColor: Colors.white,
                                  size: Size(8, 8),
                                  activeSize: Size(12, 8),
                                  spacing: EdgeInsets.symmetric(horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  activeShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                dotsCount: petDetailInstance!.media.length,
                                position: currentIndexPage.toDouble(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Container(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Color(0xFF2196F3).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.pets,
                            color: Color(0xFF2196F3),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                petDetailInstance == null
                                    ? ""
                                    : petDetailInstance!.name ?? "",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.left,
                              ),
                              SizedBox(height: 8),
                              Text(
                                petDetailInstance == null
                                    ? ""
                                    : petDetailInstance!.primaryBreed ?? "",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Color(0xFF2196F3).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Contact",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: Color(0xFF2196F3),
                              ),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  getAddress(petDetailInstance),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
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
      ),
    );
  }

  Widget textBox(String title, String textBlock) {
    var document = parseFragment(textBlock);
    var textString = document.text ?? "";
    final textStyle;
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
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Color(0xFF2196F3).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                getIconForTitle(title),
                color: Color(0xFF2196F3),
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 12),
                  LinkifyText(
                    textString,
                    textAlign: TextAlign.left,
                    textStyle: textStyle.copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    linkTypes: const [LinkType.email, LinkType.url],
                    linkStyle: TextStyle(
                      color: Color(0xFF2196F3),
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
          list.add(CustomPlayIndicatorBorder());
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
