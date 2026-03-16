import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'package:catapp/ExampleCode/Media.dart';
import 'package:catapp/models/animal_fit_record.dart';
import 'package:catapp/services/cat_fit_service.dart';
import 'package:catapp/models/catType.dart';
import 'package:catapp/services/cat_type_filter_mapping.dart';
import 'package:rating_dialog/rating_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/toolbar.dart';
import '../widgets/playIndicator.dart';
import '../widgets/youtube-video-row.dart';
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petDetailData.dart';
import '/models/shelter.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'webview_screen.dart';
import '/models/rescuegroups_v5.dart';
import '../config.dart';
import 'globals.dart' as globals;
import 'package:get/get.dart';
import 'package:flutter_network_connectivity/flutter_network_connectivity.dart';
import '../theme.dart';
import '../network_utils.dart';
import '../gold_frame/gold_frame_panel.dart';
import '../widgets/html_bold_key_extension.dart';
import '../widgets/gold/gold_trait_pill.dart';

/// One segment of description text and optional phrase index (null = normal text).
class _DescSegment {
  final String text;
  final int? phraseIndex;
  _DescSegment(this.text, this.phraseIndex);
}

/// Range of a phrase in plain text (start, end, phrase index).
class _PhraseRange {
  final int start;
  final int end;
  final int index;
  _PhraseRange(this.start, this.end, this.index);
}

/// One link-like range in the text (start index, end index, matched substring).
class _LinkRange {
  final int start;
  final int end;
  final String text;
  _LinkRange(this.start, this.end, this.text);
}

/// Header + bullet list for the top 3 personality trait differences.
class _Top3DifferenceData {
  final String header;
  final List<String> bullets;
  _Top3DifferenceData(this.header, this.bullets);
}

/// Adjective for each personality trait (for "more X than" comparison sentences).
const Map<String, String> _kPersonalityTraitAdjective = {
  'Energy Level': 'energetic',
  'Playfulness': 'playful',
  'Affection Level': 'affectionate',
  'Independence': 'independent',
  'Sociability': 'sociable',
  'Vocality': 'vocal',
  'Confidence': 'confident',
  'Sensitivity': 'sensitive',
  'Adaptability': 'adaptable',
  'Intelligence': 'intelligent',
};

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
  Shelter? shelterDetailInstance;
  bool isFavorited = false;
  int selectedImage = 0;
  late String userID;
  String? rescueGroupApi = "";
  late final ScrollController _controller = ScrollController();
  late final PageController _pageController = PageController();
  int currentIndexPage = 0;
  AnimalFitRecord? _fitRecord;
  List<String>? _highlightedTraitEvidence;
  /// Per-phrase progress 0.0 (purple) to 1.0 (gold) for evidence highlight animation.
  List<double>? _evidenceHighlightProgress;
  /// One GlobalKey per evidence phrase for scrolling to center before each highlight.
  List<GlobalKey>? _phraseSegmentKeys;
  int _evidenceHighlightCurrentIndex = 0;
  late AnimationController _evidenceAnimationController;
  int _personalityChartMode = 0; // 0 = My Type, 1 = Suggested Type
  final GlobalKey _descriptionHighlightKey = GlobalKey();

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
    image: Image.asset("assets/Icons/icon.png"),
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
        if (mounted && isNetworkError(e)) showNetworkErrorSnackBar(context);
      }
    }();

    _evidenceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    super.initState();
  }

  @override
  void dispose() {
    _evidenceAnimationController.dispose();
    _controller.removeListener(_scrollListener);
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Map trait score 1–5 to "very low", "low", "medium", "high", "very high".
  static String _scoreToLevel(int? score) {
    if (score == null || score < 1 || score > 5) return 'unknown';
    const levels = ['very low', 'low', 'medium', 'high', 'very high'];
    return levels[score - 1];
  }

  /// Returns "he", "she", or "this cat" from pet sex for snackbar text.
  static String _sexToPronoun(String? sex) {
    if (sex == null || sex.isEmpty) return 'this cat';
    final s = sex.toLowerCase();
    if (s == 'male') return 'he';
    if (s == 'female') return 'she';
    return 'this cat';
  }

  /// Animates each evidence phrase background from purple to gold (200ms each, 200ms between).
  /// Before each phrase, scrolls so that phrase is in the middle of the screen.
  Future<void> _runEvidenceHighlightAnimation() async {
    final evidence = _highlightedTraitEvidence;
    final progress = _evidenceHighlightProgress;
    final phraseKeys = _phraseSegmentKeys;
    if (evidence == null ||
        progress == null ||
        evidence.isEmpty ||
        phraseKeys == null ||
        phraseKeys.length != evidence.length) return;
    final n = evidence.length;
    void listener() {
      if (!mounted || _evidenceHighlightProgress == null) return;
      if (_evidenceHighlightCurrentIndex < _evidenceHighlightProgress!.length) {
        setState(() {
          _evidenceHighlightProgress![_evidenceHighlightCurrentIndex] =
              _evidenceAnimationController.value;
        });
      }
    }
    const scrollDuration = Duration(milliseconds: 400);
    for (int i = 0; i < n; i++) {
      if (!mounted) return;
      // Scroll so this phrase is in the middle of the screen
      final ctx = phraseKeys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: scrollDuration,
          curve: Curves.easeInOut,
        );
        await Future.delayed(scrollDuration);
      }
      if (!mounted) return;
      _evidenceHighlightCurrentIndex = i;
      _evidenceAnimationController.removeListener(listener);
      _evidenceAnimationController.addListener(listener);
      _evidenceAnimationController.reset();
      await _evidenceAnimationController.forward().orCancel;
      _evidenceAnimationController.removeListener(listener);
      if (!mounted) return;
      setState(() => _evidenceHighlightProgress![i] = 1.0);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void getShelterDetail(String orgID) async {
    var url = "https://api.rescuegroups.org/v5/public/orgs/$orgID";

    print("URL = $url");

    try {
      var response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'Authorization': rescueGroupApi!
      });

      if (response.statusCode == 200) {
        print("status 200");
        if (mounted) {
          setState(() {
            shelterDetailInstance = Shelter.fromJson(jsonDecode(response.body));
            loadAsset();
          });
        }
      } else {
        print("response.statusCode = ${response.statusCode}");
      }
    } catch (e) {
      if (mounted && isNetworkError(e)) showNetworkErrorSnackBar(context);
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

    try {
      var response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'Authorization': rescueGroupApi!
      });

      if (response.statusCode == 200) {
        print("status 200");
        var petDecoded = pet.fromJson(jsonDecode(response.body));
        if (mounted) {
          setState(() {
            petDetailInstance = PetDetailData(
              petDecoded.data![0],
              petDecoded.included!,
              petDecoded.data![0].relationships!.values.toList(),
            );
            getShelterDetail(petDetailInstance!.organizationID!);
            loadAsset();
            _loadFitRecord();
          });
        }
        print("********DD = ${petDetailInstance?.media}");
      } else {
        print("response.statusCode = ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load pet details. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && isNetworkError(e)) showNetworkErrorSnackBar(context);
    }
  }

  Future<void> _loadFitRecord() async {
    if (petDetailInstance?.id == null) return;
    final record = await CatFitService.instance.getFitForAnimal(
      petDetailInstance!.id!,
      description: petDetailInstance!.description ?? '',
      name: petDetailInstance!.name,
      shelterName: petDetailInstance!.organizationName,
      updatedDate: null,
    );
    if (mounted) setState(() => _fitRecord = record);
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

  void _scrollListener() {
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
                  try {
                    await widget.server.unfavoritePet(userID, widget.petID);
                    if (mounted) {
                      setState(() {
                        isFavorited = false;
                      });
                      globals.listOfFavorites.remove(widget.petID);
                    }
                  } catch (e) {
                    if (mounted && isNetworkError(e)) {
                      showNetworkErrorSnackBar(context);
                    }
                  }
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
                  try {
                    await widget.server.favoritePet(userID, widget.petID);
                    if (mounted) {
                      setState(() {
                        isFavorited = true;
                      });
                      // Show snackbar when cat is favorited
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Saved! Return to main screen to see saves tab.',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.blue,
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height * 0.1,
                            left: 16,
                            right: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    globals.listOfFavorites.remove(widget.petID);
                    if (mounted && isNetworkError(e)) {
                      showNetworkErrorSnackBar(context);
                    }
                  }
                }
                if (mounted) print("Set changed to $isFavorited");
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
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
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
                      
                      // Content box = full inner frame so tall images touch top/bottom, wide images touch left/right (no purple at edges)
                      final contentWidth = availableWidth.clamp(0.0, double.infinity);
                      final contentHeight = imageHeight;
                      
                      if (petDetailInstance == null ||
                          petDetailInstance!.media.isEmpty) {
                        final isStillLoading = petDetailInstance == null;
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
                                if (isStillLoading)
                                  const SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.pets,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                SizedBox(height: AppTheme.spacingM),
                                Text(
                                  isStillLoading ? 'Loading...' : 'No photos available',
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

                                        // Contain: scale to fit inside content box (no clipping, no distortion)
                                        final naturalWidth = imageWidth;
                                        final naturalHeight = imageHeight;
                                        final scale = (contentWidth > 0 && contentHeight > 0 &&
                                                naturalWidth > 0 && naturalHeight > 0)
                                            ? math.min(
                                                contentWidth / naturalWidth,
                                                contentHeight / naturalHeight,
                                              ).clamp(0.0, 1.0)
                                            : 1.0;
                                        final displayWidth = naturalWidth * scale;
                                        final displayHeight = naturalHeight * scale;

                                        // Center the image
                                        return Center(
                                          child: _buildMediaItem(
                                            media,
                                            displayWidth,
                                            displayHeight,
                                            index,
                                            petDetailInstance!.media.length,
                                          ),
                                        );
                                      },
                                    ),
                                    // Page indicator dots at the bottom (play icon for video items); tap to go to that page
                                    if (petDetailInstance!.media.length > 1)
                                      Positioned(
                                        bottom: 10,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(
                                            petDetailInstance!.media.length,
                                            (index) {
                                              final isVideo = petDetailInstance!.media[index] is YouTubeVideo;
                                              final isSelected = currentIndexPage == index;
                                              final color = isSelected
                                                  ? AppTheme.goldBase
                                                  : Colors.white.withOpacity(0.5);
                                              return GestureDetector(
                                                onTap: () {
                                                  _pageController.animateToPage(
                                                    index,
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                  );
                                                },
                                                behavior: HitTestBehavior.opaque,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                  child: isVideo
                                                      ? Icon(
                                                          Icons.play_circle_fill,
                                                          size: 20,
                                                          color: color,
                                                        )
                                                      : Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: color,
                                                          ),
                                                        ),
                                                ),
                                              );
                                            },
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

              // Name + Breed Plaque (ribbon with gold gradient)
              if (petDetailInstance != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: NameBreedPlaque(
                    name: petDetailInstance!.name ?? "",
                    breed: petDetailInstance!.primaryBreed ?? "",
                  ),
                ),

              // Pill bar: personality type, adoption status, age, sex, size (wraps like adoption list)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: _buildDetailPills(),
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

              // Contact section using thin gold outline
              ThinGoldSection(
                title: "Contact",
                icon: Icons.public,
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

              if (_fitRecord != null) ...[
                const SizedBox(height: 12),
                _buildPersonalityChart(),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  /// Returns aspect ratio (width/height) for the currently visible gallery media. Used to reduce top/bottom inset for tall images.
  double? _getAspectRatioForCurrentMedia() {
    if (petDetailInstance == null || petDetailInstance!.media.isEmpty) return null;
    final index = currentIndexPage.clamp(0, petDetailInstance!.media.length - 1);
    final media = petDetailInstance!.media[index];
    if (media is SmallPhoto && petDetailInstance!.mainPictures.isNotEmpty) {
      final photoUrl = media.photo;
      try {
        final matching = petDetailInstance!.mainPictures.firstWhere(
          (pic) => pic.url.toString() == photoUrl,
          orElse: () => petDetailInstance!.mainPictures[0],
        );
        if (matching.resolutionX != null &&
            matching.resolutionY != null &&
            matching.resolutionX! > 0 &&
            matching.resolutionY! > 0) {
          return matching.resolutionX! / matching.resolutionY!;
        }
      } catch (_) {}
      return 4 / 3;
    }
    if (media is YouTubeVideo) return 16 / 9;
    return 4 / 3;
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
                    final video = media;
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
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_circle_filled,
                            size: 40,
                            color: Colors.white,
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

  List<Widget> _buildDetailPills() {
    final pills = <Widget>[];
    final personalityType = _fitRecord?.suggestedCatTypeName?.trim();
    if (personalityType != null && personalityType.isNotEmpty) {
      pills.add(GoldTraitPill(label: personalityType));
    }
    final pd = petDetailInstance;
    if (pd != null) {
      if (pd.ageGroup != null && pd.ageGroup!.trim().isNotEmpty) {
        pills.add(GoldTraitPill(label: pd.ageGroup!));
      }
      if (pd.sex != null && pd.sex!.trim().isNotEmpty) {
        pills.add(GoldTraitPill(label: pd.sex!));
      }
      if (pd.sizeGroup != null && pd.sizeGroup!.trim().isNotEmpty) {
        pills.add(GoldTraitPill(label: pd.sizeGroup!));
      }
    }
    return pills;
  }

  String get _adopterTypeLabel {
    final name = widget.server.selectedPersonalityCatTypeName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'My Type';
  }

  String get _suggestedTypeLabel {
    final name = _fitRecord?.suggestedCatTypeName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Suggested Type';
  }

  /// Returns the trait profile (trait name -> 1-5) for the type to show as triangle.
  /// For "My Type" (mode 0): use last search user profile from sliders when available, else selected cat type.
  Map<String, int>? _getTypeProfileForChart() {
    if (_personalityChartMode == 1) {
      final name = _fitRecord?.suggestedCatTypeName;
      if (name == null || name.trim().isEmpty) return null;
      CatType? type;
      try {
        type = catType.firstWhere(
            (t) => t.name.toLowerCase() == name.trim().toLowerCase());
      } catch (_) {
        return null;
      }
      return CatTypeFilterMapping.getTraitProfileForCatType(type);
    }
    // My Type (mode 0): prefer profile from search/fit sliders so bar chart reflects current filters
    final fromSearch = widget.server.lastSearchUserTraitProfile;
    if (fromSearch != null && fromSearch.isNotEmpty) {
      return fromSearch;
    }
    final name = widget.server.selectedPersonalityCatTypeName;
    if (name == null || name.trim().isEmpty) return null;
    CatType? type;
    try {
      type = catType.firstWhere(
          (t) => t.name.toLowerCase() == name.trim().toLowerCase());
    } catch (_) {
      return null;
    }
    return CatTypeFilterMapping.getTraitProfileForCatType(type);
  }

  /// Match label from fit score using same ranges as fit screen: 0.0–1.0 percent.
  static String _getMatchLabel(double percentMatch) {
    final percentage = percentMatch * 100;
    if (percentage >= 95) return 'Purrfect';
    if (percentage >= 90) return 'Excellent';
    if (percentage >= 85) return 'Great';
    if (percentage >= 75) return 'Very Good';
    if (percentage >= 65) return 'Good';
    if (percentage >= 55) return 'Fair';
    if (percentage >= 45) return 'Okay';
    if (percentage >= 35) return 'Poor';
    return 'Not a Match';
  }

  /// Top 3 trait differences as a header + bullet list. Only includes traits the cat has data for. Null if no type profile or no differences.
  _Top3DifferenceData? _getTop3DifferenceBullets() {
    final typeProfile = _getTypeProfileForChart();
    if (typeProfile == null || _fitRecord == null) return null;
    const defaultScore = 3;
    final diffs = <String, int>{};
    for (final traitName in kPersonalityTraitNames) {
      final match = _fitRecord!.traits[traitName]?.score;
      if (match == null || match < 1 || match > 5) continue; // skip traits we don't have data for
      final selected = typeProfile[traitName] ?? defaultScore;
      final d = selected - match;
      if (d != 0) diffs[traitName] = d;
    }
    if (diffs.isEmpty) return null;
    // Biggest differences by absolute value (positive or negative)
    final sorted = diffs.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final top3 = sorted.take(3).toList();
    final isTypical = _personalityChartMode == 1;
    final header = isTypical ? 'Compared to the usual type:' : 'Compared to my type:';
    final bullets = <String>[];
    for (final e in top3) {
      final adj = _kPersonalityTraitAdjective[e.key] ?? e.key.toLowerCase();
      final magnitude = e.value.abs();
      final degree = (magnitude >= 3) ? 'Far' : 'A bit';
      if (e.value > 0) {
        bullets.add('$degree less $adj');
      } else {
        bullets.add('$degree more $adj');
      }
    }
    return _Top3DifferenceData(header, bullets);
  }

  void _showPersonalityChartHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to use the Personality chart'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'What you see\n'
                'At the top you may see a match rating and up to three comparison bullets (how this cat differs from the selected type). '
                'Each row is a personality trait. The gold bars show how strong that trait is for this cat (1–5). '
                'If you\'ve chosen My or Usual below, a gold triangle on the bar shows that type\'s level for the same trait.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                'Two modes\n'
                'Use the buttons below the chart to switch between My (your chosen type from search/fit) and Usual (the usual personality type we suggest for this cat). '
                'The triangle on each bar shows the selected type; the bar always shows the cat.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                'Seeing evidence\n'
                'Tap anywhere on a trait row (name, bar, or (i) icon). A message will explain that we\'re showing evidence for that trait. '
                'After a moment, the page scrolls to the description and highlights the exact phrases we used as evidence for that trait. Tap the same row again to clear the highlight.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                'No evidence\n'
                'If a trait has no supporting phrases in the description, the (i) icon appears dimmed and tapping the row won\'t scroll or highlight.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityChart() {
    const segmentCount = 5;
    const barHeight = 14.0;
    const rowHeight = 20.0;
    const triangleWidth = 20.0;
    const triangleHeight = 20.0;
    final typeProfile = _getTypeProfileForChart();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GoldIconBox(icon: Icons.psychology),
                const SizedBox(width: 16),
                const Text(
                  'Personality',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white70, size: 24),
                  onPressed: () => _showPersonalityChartHelpDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            ...() {
              const bulletStyle = TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontFamily: 'Poppins',
                height: 1.3,
              );
              final list = <Widget>[const SizedBox(height: 8)];
              // Rating label: use stored fitScore or compute from current type profile vs cat traits
              double? score = _fitRecord?.fitScore;
              if (score == null && _fitRecord != null && typeProfile != null && typeProfile!.isNotEmpty) {
                score = CatFitService.computeFitScore(_fitRecord!.traitScores, typeProfile!);
              }
              if (score != null) {
                final percent = score <= 1 ? score : score / 100.0;
                final typeLabel = _personalityChartMode == 1 ? _suggestedTypeLabel : _adopterTypeLabel;
                list.add(Text(
                  '${_getMatchLabel(percent)} $typeLabel Match',
                  style: bulletStyle.copyWith(fontWeight: FontWeight.w600),
                ));
                list.add(const SizedBox(height: 6));
              }
              final data = _getTop3DifferenceBullets();
              if (data != null && data.bullets.isNotEmpty) {
                list.add(Text(
                  data.header,
                  style: bulletStyle.copyWith(fontWeight: FontWeight.w600),
                ));
                list.add(const SizedBox(height: 6));
                list.addAll(data.bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: bulletStyle),
                      Expanded(child: Text(b, style: bulletStyle)),
                    ],
                  ),
                )));
              }
              list.add(const SizedBox(height: 12));
              return list;
            }(),
            ...kPersonalityTraitNames.map((traitName) {
              final detail = _fitRecord!.traits[traitName];
              final score = detail?.score;
              final filledSegments = (score != null && score >= 1 && score <= 5)
                  ? score
                  : 0;
              final typeValue = typeProfile?[traitName];
              final showTriangle = typeValue != null && typeValue >= 1 && typeValue <= 5;
              final evidence = detail?.evidence ?? [];
              final isActive = _highlightedTraitEvidence != null &&
                  _highlightedTraitEvidence!.isNotEmpty &&
                  identical(_highlightedTraitEvidence, evidence);

              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final willHighlight = evidence.isNotEmpty &&
                          !(_highlightedTraitEvidence == evidence &&
                              evidence.isNotEmpty);
                      setState(() {
                        if (_highlightedTraitEvidence == evidence &&
                            evidence.isNotEmpty) {
                          _highlightedTraitEvidence = null;
                          _evidenceHighlightProgress = null;
                          _phraseSegmentKeys = null;
                        } else {
                          _highlightedTraitEvidence =
                              evidence.isEmpty ? null : evidence;
                          _evidenceHighlightProgress = evidence.isEmpty
                              ? null
                              : List.filled(evidence.length, 0.0);
                          _phraseSegmentKeys = evidence.isEmpty
                              ? null
                              : List.generate(
                                  evidence.length,
                                  (_) => GlobalKey(),
                                );
                        }
                      });
                      if (willHighlight &&
                          evidence.isNotEmpty &&
                          mounted) {
                        final pronoun =
                            _sexToPronoun(petDetailInstance?.sex);
                        final level = _scoreToLevel(detail?.score);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Here is evidence $pronoun is $level in $traitName.',
                              style: const TextStyle(
                                color: AppTheme.darkText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AppTheme.goldBase,
                            duration: const Duration(milliseconds: 2000),
                          ),
                        );
                        Future.delayed(
                          const Duration(milliseconds: 2000),
                          () {
                            if (!mounted) return;
                            final ctx =
                                _descriptionHighlightKey.currentContext;
                            if (ctx != null) {
                              Scrollable.ensureVisible(
                                ctx,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                alignment: 0.5,
                              );
                            }
                            if (mounted &&
                                _highlightedTraitEvidence != null &&
                                _highlightedTraitEvidence!.isNotEmpty) {
                              _runEvidenceHighlightAnimation();
                            }
                          },
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            traitName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive ? AppTheme.goldBase : Colors.white70,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: rowHeight,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final barWidth = constraints.maxWidth;
                                final left = showTriangle
                                    ? (barWidth * ((typeValue! - 0.5) / segmentCount) -
                                            triangleWidth / 2)
                                        .clamp(0.0, barWidth - triangleWidth)
                                    : 0.0;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: (rowHeight - barHeight) / 2,
                                      height: barHeight,
                                      child: Row(
                                        children: List.generate(segmentCount, (i) {
                                          final segmentIndex = i + 1;
                                          final isFilled =
                                              segmentIndex <= filledSegments;
                                          final isFirst = i == 0;
                                          final isLast =
                                              i == segmentCount - 1;
                                          return Expanded(
                                            child: Container(
                                              margin: EdgeInsets.only(
                                                right: isLast ? 0 : 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isFilled
                                                    ? AppTheme.goldBase
                                                    : Colors.white24,
                                                borderRadius:
                                                    BorderRadius.horizontal(
                                                  left: Radius.circular(
                                                      isFirst ? 6 : 0),
                                                  right: Radius.circular(
                                                      isLast ? 6 : 0),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                    if (showTriangle)
                                      Positioned(
                                        left: left,
                                        top: 0,
                                        child: CustomPaint(
                                          size: const Size(
                                              triangleWidth, triangleHeight),
                                          painter: _GoldTrianglePainter(),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: Icon(
                            isActive ? Icons.info : Icons.info_outline,
                            size: 28,
                            color: evidence.isEmpty
                                ? Colors.white38
                                : (isActive ? AppTheme.goldBase : Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Compare this match to:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _personalityChartMode = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<int>(
                            value: 0,
                            groupValue: _personalityChartMode,
                            onChanged: (v) =>
                                setState(() => _personalityChartMode = 0),
                            activeColor: AppTheme.goldBase,
                            fillColor: WidgetStateProperty.resolveWith((states) =>
                                states.contains(WidgetState.selected)
                                    ? AppTheme.goldBase
                                    : Colors.white54),
                          ),
                          Text(
                            'My: $_adopterTypeLabel',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _personalityChartMode = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<int>(
                            value: 1,
                            groupValue: _personalityChartMode,
                            onChanged: (v) =>
                                setState(() => _personalityChartMode = 1),
                            activeColor: AppTheme.goldBase,
                            fillColor: WidgetStateProperty.resolveWith((states) =>
                                states.contains(WidgetState.selected)
                                    ? AppTheme.goldBase
                                    : Colors.white54),
                          ),
                          Text(
                            'Usual: $_suggestedTypeLabel',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps each evidence phrase in the description with <b></b> for highlighting.
  /// Uses case-insensitive matching so "loves cuddling" matches "Loves cuddling" in the text.
  static String _wrapEvidenceInBold(String description, List<String> evidence) {
    String result = description;
    for (final phrase in evidence) {
      if (phrase.isEmpty) continue;
      try {
        final pattern = RegExp(RegExp.escape(phrase), caseSensitive: false);
        final found = pattern.hasMatch(result);
        print('Evidence highlight: searching for "${phrase}" -> ${found ? "found" : "NOT found"}');
        if (found) {
          result = result.replaceFirstMapped(
            pattern,
            (match) => '<b>${match.group(0)}</b>',
          );
        }
      } catch (e) {
        print('Evidence highlight: error for phrase "${phrase}": $e');
      }
    }
    return result;
  }

  /// One segment of description: text and optional phrase index (null = normal text).
  static List<_DescSegment> _descriptionSegments(
    String plainText,
    List<String> evidence,
  ) {
    if (evidence.isEmpty) return [_DescSegment(plainText, null)];
    final ranges = <_PhraseRange>[];
    for (int i = 0; i < evidence.length; i++) {
      final phrase = evidence[i];
      if (phrase.isEmpty) continue;
      try {
        final pattern = RegExp(RegExp.escape(phrase), caseSensitive: false);
        final match = pattern.firstMatch(plainText);
        if (match != null) {
          ranges.add(_PhraseRange(match.start, match.end, i));
        }
      } catch (_) {}
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final segments = <_DescSegment>[];
    int pos = 0;
    for (final r in ranges) {
      if (r.start > pos) {
        segments.add(_DescSegment(plainText.substring(pos, r.start), null));
      }
      segments.add(_DescSegment(plainText.substring(r.start, r.end), r.index));
      pos = r.end;
    }
    if (pos < plainText.length) {
      segments.add(_DescSegment(plainText.substring(pos), null));
    }
    return segments;
  }

  /// Matches URL-like text: with scheme (https://...), www.xxx.tld, or bare domain (xxx.tld). TLD at least 2 letters to avoid numbers like 3.14.
  static final RegExp _urlWithSchemeRegex = RegExp(
    r'https?://[^\s<>]+',
    caseSensitive: false,
  );
  static final RegExp _urlLikeRegex = RegExp(
    r'(?:www\.)?(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}',
  );
  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  /// Returns non-overlapping (start, end, matchedText) for all link-like substrings, ordered by start.
  List<_LinkRange> _getLinkLikeRanges(String text) {
    final list = <_LinkRange>[];
    void addMatches(RegExp re) {
      for (final m in re.allMatches(text)) {
        String matched = m.group(0)!;
        int end = m.end;
        while (matched.length > 1 && _isTrailingPunctuation(matched.codeUnitAt(matched.length - 1))) {
          matched = matched.substring(0, matched.length - 1);
          end--;
        }
        if (matched.isNotEmpty) list.add(_LinkRange(m.start, end, matched));
      }
    }
    addMatches(_urlWithSchemeRegex);
    addMatches(_urlLikeRegex);
    addMatches(_emailRegex);
    list.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_LinkRange>[];
    for (final r in list) {
      if (merged.isEmpty || r.start >= merged.last.end) merged.add(r);
    }
    return merged;
  }

  static bool _isTrailingPunctuation(int code) {
    return code == 0x2C || code == 0x2E || code == 0x3B || code == 0x3A || code == 0x29 || code == 0x5D; // , . ; : ) ]
  }

  /// Returns corrected URL (https://, www. when missing) for embedding in HTML or launching.
  String _correctUrlString(String link) {
    if (link.isEmpty) return link;
    String url = link.trim();
    if (url.startsWith('"') || url.startsWith("'")) url = url.substring(1);
    if (url.endsWith('"') || url.endsWith("'")) url = url.substring(0, url.length - 1);
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') || url.startsWith('www.')) {
        url = 'https://$url';
      } else if (url.contains('facebook') || url.startsWith('/')) {
        url = url.startsWith('/') ? 'https://www.facebook.com$url' : 'https://www.facebook.com/$url';
      } else {
        url = 'https://$url';
      }
    }
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty && !uri.host.toLowerCase().startsWith('www.')) {
        final path = uri.path;
        final query = uri.query.isEmpty ? '' : '?${uri.query}';
        final fragment = uri.fragment.isEmpty ? '' : '#${uri.fragment}';
        url = 'https://www.${uri.host}$path$query$fragment';
      }
    } catch (_) {}
    return url;
  }

  static String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _decodeHtmlEntities(String s) {
    return s
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
  }

  /// Remove all non-breaking space (entity and Unicode) so description displays without &nbsp;.
  static String _stripNbsp(String s) {
    return s
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&#160;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&#x0?A0;', caseSensitive: false), ' ');
  }

  /// Wrap URL-like substrings in plain text with <a href="..."> so HTML renderer shows and launches them.
  String _linkifyPlainText(String text) {
    final decoded = _decodeHtmlEntities(text);
    final ranges = _getLinkLikeRanges(decoded);
    if (ranges.isEmpty) return text;
    final buffer = StringBuffer();
    int pos = 0;
    for (final r in ranges) {
      buffer.write(_escapeHtml(decoded.substring(pos, r.start)));
      final String href = _emailRegex.hasMatch(r.text)
          ? 'mailto:${r.text}'
          : _correctUrlString(r.text);
      buffer.write('<a href="${_escapeHtml(href)}">');
      buffer.write(_escapeHtml(r.text));
      buffer.write('</a>');
      pos = r.end;
    }
    // Trim trailing whitespace so the renderer does not show extra &nbsp; after the link
    buffer.write(_escapeHtml(decoded.substring(pos).trimRight()));
    return buffer.toString();
  }

  /// Linkify only text outside HTML tags so we don't break existing markup.
  String _linkifyHtml(String html) {
    final buffer = StringBuffer();
    int pos = 0;
    while (pos < html.length) {
      final tagStart = html.indexOf('<', pos);
      if (tagStart < 0) {
        buffer.write(_linkifyPlainText(html.substring(pos)));
        break;
      }
      buffer.write(_linkifyPlainText(html.substring(pos, tagStart)));
      final tagEnd = html.indexOf('>', tagStart);
      if (tagEnd < 0) {
        buffer.write(html.substring(tagStart));
        break;
      }
      buffer.write(html.substring(tagStart, tagEnd + 1));
      pos = tagEnd + 1;
    }
    return buffer.toString();
  }

  List<InlineSpan> _buildLinkifiedSpans(String text, TextStyle textStyle, TextStyle linkStyle) {
    final ranges = _getLinkLikeRanges(text);
    final spans = <InlineSpan>[];
    int pos = 0;
    for (final r in ranges) {
      if (r.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, r.start), style: textStyle));
      }
      final String linkText = r.text;
      spans.add(TextSpan(
        text: linkText,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => _onOpen(linkText),
      ));
      pos = r.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: textStyle));
    }
    return spans;
  }

  Widget textBox(String title, String textBlock) {
    if (title == 'Description') {
      textBlock = _stripNbsp(textBlock);
      final evidence = _highlightedTraitEvidence;
      final progress = _evidenceHighlightProgress;
      final useSegmentHighlight = evidence != null &&
          evidence.isNotEmpty &&
          progress != null &&
          progress.length == evidence.length &&
          _phraseSegmentKeys != null &&
          _phraseSegmentKeys!.length == evidence.length;

      if (useSegmentHighlight) {
        final plainText = parseFragment(textBlock).text ?? textBlock;
        final segments = _descriptionSegments(plainText, evidence!);
        final phraseKeys = _phraseSegmentKeys!;
        final baseStyle = TextStyle(
          fontFamily: GoogleFonts.karla().fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.5,
        );
        final progressList = progress!;
        final spans = <InlineSpan>[];
        final keyUsedForPhraseIndex = <int>{};
        for (final seg in segments) {
          if (seg.phraseIndex != null) {
            final idx = seg.phraseIndex!;
            final t = progressList[idx].clamp(0.0, 1.0);
            final bgColor = Color.lerp(
              AppTheme.deepPurple,
              AppTheme.goldBase,
              t,
            )!;
            final style = baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              backgroundColor: bgColor,
            );
            // Use key only for first occurrence of each phrase index (no duplicate keys)
            final useKey =
                idx < phraseKeys.length && !keyUsedForPhraseIndex.contains(idx);
            if (useKey) {
              keyUsedForPhraseIndex.add(idx);
              spans.add(WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Container(
                  key: phraseKeys[idx],
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  child: Text(seg.text, style: style),
                ),
              ));
            } else {
              spans.add(TextSpan(text: seg.text, style: style));
            }
          } else {
            spans.add(TextSpan(text: seg.text, style: baseStyle));
          }
        }
        return ThinGoldSection(
          key: _descriptionHighlightKey,
          title: title,
          icon: Icons.description_outlined,
          child: RichText(
            text: TextSpan(style: baseStyle, children: spans),
          ),
        );
      }

      final htmlContent = (evidence != null && evidence.isNotEmpty)
          ? _wrapEvidenceInBold(textBlock, evidence)
          : textBlock;
      final hasHighlight = evidence != null && evidence.isNotEmpty;
      String htmlWithLinks = _linkifyHtml(htmlContent);
      // Remove stray &nbsp; that can appear after a link at end of description
      htmlWithLinks = htmlWithLinks.replaceAll('</a>&nbsp;&nbsp;', '</a>').replaceAll('</a>&nbsp;', '</a>');
      return ThinGoldSection(
        key: _descriptionHighlightKey,
        title: title,
        icon: Icons.description_outlined,
        child: Html(
          data: htmlWithLinks,
          extensions: hasHighlight
              ? [BoldKeyExtension(_descriptionHighlightKey)]
              : const [],
          style: {
            '*': Style(
              fontFamily: GoogleFonts.karla().fontFamily,
              fontSize: FontSize(16),
              fontWeight: FontWeight.w500,
              color: Colors.white,
              lineHeight: LineHeight(1.5),
            ),
            'b': Style(
              fontWeight: FontWeight.bold,
              color: AppTheme.goldBase,
            ),
            'strong': Style(
              fontWeight: FontWeight.bold,
              color: AppTheme.goldBase,
            ),
            'a': Style(
              color: AppTheme.goldBase,
              fontWeight: FontWeight.bold,
              textDecoration: TextDecoration.underline,
              textDecorationColor: AppTheme.goldBase,
            ),
          },
          onLinkTap: (url, _, __) {
            if (url != null) _onOpen(url);
          },
        ),
      );
    }

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

    final TextStyle baseTextStyle = textStyle.copyWith(
      color: Colors.white,
      height: 1.5,
    );
    final TextStyle linkStyle = baseTextStyle.copyWith(
      color: AppTheme.goldBase,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
      decorationColor: AppTheme.goldBase,
      decorationThickness: 1.5,
    );
    return ThinGoldSection(
      title: title,
      icon: getIconForTitle(title),
      child: RichText(
        textAlign: TextAlign.left,
        text: TextSpan(
          style: baseTextStyle,
          children: _buildLinkifiedSpans(textString, baseTextStyle, linkStyle),
        ),
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

    String url = link.trim();
    if (url.startsWith('"') || url.startsWith("'")) url = url.substring(1);
    if (url.endsWith('"') || url.endsWith("'")) url = url.substring(0, url.length - 1);
    url = url.trim();

    // If it looks like an email (or is a mailto: URL), open default email client with To set to this address
    String? emailForMailto;
    if (url.toLowerCase().startsWith('mailto:')) {
      emailForMailto = url.substring(7).trim().split(RegExp(r'[?&]')).first;
      if (emailForMailto.isEmpty) emailForMailto = null;
    } else {
      final match = _emailRegex.firstMatch(url);
      if (match != null) emailForMailto = match.group(0)!;
    }
    if (emailForMailto != null && emailForMailto.isNotEmpty) {
      try {
        final mailto = Uri.parse('mailto:$emailForMailto');
        final launched = mounted && await url_launcher.launchUrl(mailto);
        if (mounted && !launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open email: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // Clean and validate URL
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

    // Add www. when missing so links like animalsanctuarysociety.org open correctly
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty && !uri.host.toLowerCase().startsWith('www.')) {
        final path = uri.path;
        final query = uri.query.isEmpty ? '' : '?${uri.query}';
        final fragment = uri.fragment.isEmpty ? '' : '#${uri.fragment}';
        url = 'https://www.${uri.host}$path$query$fragment';
      }
    } catch (_) {}

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
      
      // Open in device browser
      if (mounted) {
        if (await url_launcher.canLaunchUrl(uri)) {
          await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open link'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    double currentX = size.width;
    while (currentX > 0) {
      final nextX = (currentX - waveLength).clamp(0.0, size.width);
      final xFromLeft = size.width - currentX;
      final controlX = currentX - waveLength / 2;
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

class _GoldTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    final fillPaint = Paint()
      ..color = AppTheme.goldBase
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
    final strokePaint = Paint()
      ..color = const Color(0xFF2B1E3A).withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}