import 'dart:convert';
//import 'dart:html';
import 'package:catapp/models/rescuegroups_v5.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catapp/screens/petDetail.dart';
import '/models/breed.dart';
import '/models/question.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import '/models/playlist.dart';
import '/widgets/playlist-row.dart';
import '/utils/constants.dart';
import '../config.dart';
import 'globals.dart' as globals;
import '/ExampleCode/RescueGroupsQuery.dart';
import '/ExampleCode/petTileData.dart';
import 'package:get/get.dart';
import 'package:outlined_text/outlined_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/youtube-video-row.dart';
import '../theme.dart';
import '../network_utils.dart';
import '../widgets/design_system.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum WidgetMarker { adopt, videos, stats, info }

// Use theme gold so ribbon and circular buttons match the favorite icon and other
// gold accents on this page (and the frame).
class BreedDetail extends StatefulWidget {
  final Breed breed;
  final WidgetMarker? initialTab;
  /// When true (e.g. from Breed Fit), show user pref vs cat trait, legend, and bullseye.
  /// When false (e.g. from Breed List), show only cat trait bars with full width.
  final bool showUserComparison;

  const BreedDetail({
    Key? key,
    required this.breed,
    this.initialTab,
    this.showUserComparison = false,
  }) : super(key: key);

  @override
  _BreedDetailState createState() {
    return _BreedDetailState();
  }
}

class _BreedDetailState extends State<BreedDetail> with TickerProviderStateMixin {
  late WidgetMarker selectedWidgetMarker;
  List<Playlist> playlists = [];
  bool _quotaExceeded = false;
  
  // Cache for playlists to avoid repeated API calls (in-memory cache)
  static final Map<String, List<Playlist>> _playlistCache = {};
  static final Map<String, bool> _quotaExceededCache = {};
  
  // Firestore collection for YouTube playlists
  static const String _firestoreCollection = 'youtube_playlists';
  static const int _cacheExpiryDays = 7; // Refresh cache after 7 days
  final maxValues = [5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 11, 6, 3, 12];
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _playButtonPulseController;
  late Animation<double> _fadeAnimation;

  String url = "";
  double progress = 0;

  int maxPets = -1;
  int loadedPets = 0;
  int tilesPerLoad = 100;

  List<PetTileData> tiles = [];

  String? rescueGroupApi = "";

  @override
  void initState() {
    super.initState();
    
    // Set initial tab from widget parameter or default to info
    selectedWidgetMarker = widget.initialTab ?? WidgetMarker.info;
    
    // Set hilightedCell based on initial tab
    hilightedCell = selectedIcon.indexOf(selectedWidgetMarker);
    if (hilightedCell == -1) {
      hilightedCell = 3; // Default to info if not found
      selectedWidgetMarker = WidgetMarker.info;
    }
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    // Reset to 0 and start animation after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.reset();
        _fadeController.forward();
      }
    });
    
    _playButtonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    () async {
      setState(() {
        rescueGroupApi = AppConfig.rescueGroupsApiKey;
        getPlaylists();
        getPets(widget.breed.rid.toString());
      });
    }();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _playButtonPulseController.dispose();
    super.dispose();
  }

  void getPets(String breedID) async {
    print('Getting Pets');

    int currentPage = ((loadedPets + tilesPerLoad) / tilesPerLoad).floor();
    loadedPets += tilesPerLoad;
    var url =
        "https://api.rescuegroups.org/v5/public/animals/search/available/haspic?fields[animals]=sizeGroup,ageGroup,sex,distance,id,name,breedPrimary,updatedDate,status,descriptionHtml,descriptionText&limit=100&page=$currentPage";

    print("***********BreedID = $breedID");

    Map<String, dynamic> data = {
      "data": {
        "filterRadius": {"miles": 1000, "postalcode": "94043"},
        "filters": [
          {
            "fieldName": "species.singular",
            "operation": "equal",
            "criteria": "cat"
          },
          {
            "fieldName": "animals.breedPrimaryId",
            "operation": "equal",
            "criteria": breedID
          }
        ]
      }
    };

    var data2 = RescueGroupsQuery.fromJson(data);

    try {
      var response = await http.post(Uri.parse(url),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': rescueGroupApi!
          },
          body: json.encode(data2.toJson()));

      if (response.statusCode == 200) {
        // If the server did return a 200 OK response,
        // then parse the JSON.
        print("status 200");
        var json = jsonDecode(response.body);
        var meta = Meta.fromJson(json["meta"]);
        if (meta.count == 0) {
          maxPets = 0;
          tiles = [];
          return;
        }
        pet petDecoded = petFromJson(response.body);
        if (maxPets == -1) {
          maxPets = (petDecoded.meta?.count ?? 0);
        }
        if (mounted) {
          setState(() {
            petDecoded.data?.forEach((petData) {
              tiles.add(PetTileData(petData, petDecoded.included!));
            });
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load cats. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      loadedPets -= tilesPerLoad;
      if (mounted) {
        if (isLikelyNoInternet(e)) {
          showNetworkErrorSnackBar(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load cats. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> getPlaylists() async {
    // Check if playListID is empty or invalid
    if (widget.breed.playListID.isEmpty) {
      print('⚠️ No playlist ID for breed: ${widget.breed.name}');
      setState(() {
        playlists = [];
      });
      return;
    }
    
    final cacheKey = widget.breed.playListID;
    
    // 1. Check in-memory cache first (fastest)
    if (_playlistCache.containsKey(cacheKey)) {
      print('📺 Using in-memory cached playlist for ${widget.breed.name}');
      setState(() {
        playlists = _playlistCache[cacheKey]!;
        _quotaExceeded = _quotaExceededCache[cacheKey] ?? false;
      });
      return;
    }
    
    // 2. Check Firestore cache (persistent across app restarts)
    try {
      final firestoreDoc = await FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .doc(cacheKey)
          .get();
      
      if (firestoreDoc.exists) {
        final data = firestoreDoc.data()!;
        final lastUpdated = (data['lastUpdated'] as Timestamp).toDate();
        final daysSinceUpdate = DateTime.now().difference(lastUpdated).inDays;
        final quotaExceeded = data['quotaExceeded'] as bool? ?? false;
        
        // Use Firestore cache if it's not expired and quota wasn't exceeded
        if (daysSinceUpdate < _cacheExpiryDays && !quotaExceeded) {
          final videosData = data['videos'] as List<dynamic>? ?? [];
          final cachedPlaylists = videosData.map((item) {
            final videoMap = item as Map<String, dynamic>;
            // Reconstruct Playlist from Firestore format
            return Playlist(
              id: videoMap['id'] as String? ?? '',
              title: videoMap['title'] as String? ?? '',
              image: videoMap['image'] as String? ?? '',
              description: videoMap['description'] as String? ?? '',
              videoId: videoMap['videoId'] as String? ?? '',
            );
          }).toList();
          
          // Update in-memory cache
          _playlistCache[cacheKey] = cachedPlaylists;
          _quotaExceededCache[cacheKey] = false;
          
          print('📺 Using Firestore cached playlist for ${widget.breed.name} ($daysSinceUpdate days old)');
          setState(() {
            playlists = cachedPlaylists;
            _quotaExceeded = false;
          });
          return;
        } else if (quotaExceeded) {
          print('⚠️ Quota exceeded flag in Firestore, skipping API call');
          _quotaExceededCache[cacheKey] = true;
          setState(() {
            playlists = [];
            _quotaExceeded = true;
          });
          return;
        } else {
          print('📺 Firestore cache expired ($daysSinceUpdate days), fetching fresh data');
        }
      }
    } catch (e) {
      print('⚠️ Error reading from Firestore cache: $e, will try API');
      if (mounted && isLikelyNoInternet(e)) showNetworkErrorSnackBar(context);
    }
    
    // 3. Check if quota was exceeded in memory cache
    if (_quotaExceededCache.containsKey(cacheKey) && _quotaExceededCache[cacheKey] == true) {
      print('⚠️ Quota exceeded for this playlist, skipping API call');
      setState(() {
        playlists = [];
        _quotaExceeded = true;
      });
      return;
    }
    
    try {
      final String url =
          'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=49&playlistId=${widget.breed.playListID}&key=${Constants.YOU_TUBE_API_KEY}';
      print('📺 Fetching YouTube playlist: ${widget.breed.playListID} for ${widget.breed.name}');
      Uri u = Uri.parse(url);
      var response = await http.get(u);
      
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        
        // Check if items exist in response
        if (jsonResponse['items'] != null && jsonResponse['items'] is List) {
          final loadedPlaylists = (jsonResponse['items'] as List).map<Playlist>((item) {
            return Playlist.fromJson(item);
          }).toList();
          loadedPlaylists.removeWhere((x) => x.title == "Private video");
          
          // Cache the result in memory
          _playlistCache[cacheKey] = loadedPlaylists;
          _quotaExceededCache[cacheKey] = false;
          
          // Save to Firestore for persistent caching
          try {
            final videosJson = loadedPlaylists.map((playlist) {
              return {
                'id': playlist.id,
                'title': playlist.title,
                'image': playlist.image,
                'description': playlist.description,
                'videoId': playlist.videoId,
              };
            }).toList();
            
            await FirebaseFirestore.instance
                .collection(_firestoreCollection)
                .doc(cacheKey)
                .set({
              'videos': videosJson,
              'lastUpdated': Timestamp.now(),
              'quotaExceeded': false,
              'playlistId': cacheKey,
            }, SetOptions(merge: true));
            
            print('✅ Saved playlist to Firestore cache');
          } catch (e) {
            print('⚠️ Error saving to Firestore cache: $e');
          }
          
          setState(() {
            playlists = loadedPlaylists;
            _quotaExceeded = false;
          });
          print('✅ Loaded ${playlists.length} videos for ${widget.breed.name}');
        } else {
          print('⚠️ No items in playlist response for ${widget.breed.name}');
          setState(() {
            playlists = [];
          });
        }
      } else if (response.statusCode == 403) {
        // Check if it's a quota exceeded error
        bool isQuotaExceeded = false;
        try {
          var errorJson = convert.jsonDecode(response.body);
          if (errorJson['error'] != null && 
              errorJson['error']['errors'] != null &&
              errorJson['error']['errors'].isNotEmpty &&
              errorJson['error']['errors'][0]['reason'] == 'quotaExceeded') {
            isQuotaExceeded = true;
            print('❌ YouTube API quota exceeded. Videos will be unavailable until quota resets.');
          } else {
            print('❌ YouTube API error: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('❌ YouTube API error: ${response.statusCode} - ${response.body}');
        }
        // Cache the quota exceeded status
        if (isQuotaExceeded) {
          _quotaExceededCache[cacheKey] = true;
          
          // Save quota exceeded status to Firestore
          try {
            await FirebaseFirestore.instance
                .collection(_firestoreCollection)
                .doc(cacheKey)
                .set({
              'quotaExceeded': true,
              'lastUpdated': Timestamp.now(),
              'playlistId': cacheKey,
            }, SetOptions(merge: true));
            print('✅ Saved quota exceeded status to Firestore');
          } catch (e) {
            print('⚠️ Error saving quota status to Firestore: $e');
          }
        }
        
        setState(() {
          playlists = [];
          _quotaExceeded = isQuotaExceeded;
        });
      } else {
        print('❌ YouTube API error: ${response.statusCode} - ${response.body}');
        setState(() {
          playlists = [];
        });
      }
    } catch (e) {
      print('❌ Error fetching YouTube playlist for ${widget.breed.name}: $e');
      if (mounted) {
        if (isLikelyNoInternet(e)) {
          showNetworkErrorSnackBar(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load videos. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      setState(() {
        playlists = [];
      });
    }
  }

  List<IconData> icons = [
    Icons.favorite,      // Adopt
    Icons.play_circle,  // Videos
    Icons.analytics,     // Stats
    Icons.info,          // Info
  ];
  late int hilightedCell;
  List<WidgetMarker> selectedIcon = [
    WidgetMarker.adopt,
    WidgetMarker.videos,
    WidgetMarker.stats,
    WidgetMarker.info
  ];

  Future<void> _onOpen(String link) async {
    var l = Uri.parse((!link.startsWith("http") ? "http://" : "") + link);
    if (await canLaunchUrl(l)) {
      await launchUrl(l, mode: LaunchMode.inAppWebView);
    } else {
      throw 'Could not launch $link';
    }
  }

  Future<void> _openWikipediaArticle() async {
    final wikipediaUrl = 'https://en.wikipedia.org/wiki/${widget.breed.htmlUrl}';
    final uri = Uri.parse(wikipediaUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } else {
      throw 'Could not launch Wikipedia article';
    }
  }

  String _getSummary(String fullText) {
    // Use pre-computed summary from breed data if available
    if (widget.breed.breedSummary.isNotEmpty) {
      return widget.breed.breedSummary;
    }
    
    // Fallback to simple truncation if no summary is available
    if (fullText.isEmpty) return "";
    
    // Get first paragraph or first 500 characters, whichever is shorter
    final firstParagraph = fullText.split('\n\n').first;
    if (firstParagraph.length <= 500) {
      return firstParagraph;
    }
    
    // Truncate to 500 characters at word boundary
    final truncated = fullText.substring(0, 500);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > 0) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  String _extractVideoId(String url) {
    // Handle different YouTube URL formats
    if (url.contains('youtube.com/watch?v=')) {
      final videoId = url.split('v=')[1].split('&')[0];
      print('Extracted video ID from youtube.com/watch: $videoId');
      return videoId;
    } else if (url.contains('youtu.be/')) {
      final videoId = url.split('youtu.be/')[1].split('?')[0];
      print('Extracted video ID from youtu.be: $videoId');
      return videoId;
    }
    // If it's already a video ID, return as is
    print('Using URL as video ID: $url');
    return url;
  }

  String _getYouTubeThumbnail(String videoId) {
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    print('YouTube thumbnail URL: $thumbnailUrl');
    return thumbnailUrl;
  }

  Widget _buildTabContent() {
    switch (selectedWidgetMarker) {
      case WidgetMarker.adopt:
        return Container(
          key: const ValueKey('adopt'),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: (tiles.isEmpty)
                      ? Container(
                          padding: const EdgeInsets.all(40),
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
                          child: Center(
                            child: Text(
                              "No Cats Returned.",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 3 / 4,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12),
                          itemCount: tiles.length,
                          itemBuilder: (BuildContext context, int index) {
                            return GestureDetector(
                              onTap: () => {
                                Get.to(() =>
                                    petDetail(tiles[index].id.toString())),
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image(
                                        image: NetworkImage(
                                            tiles[index].picture ?? ""),
                                        fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                    color: AppTheme.deepPurple.withOpacity(0.3),
                                            child: Icon(Icons.pets,
                                                size: 50,
                                        color: Colors.white.withOpacity(0.7)),
                                          );
                                        },
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.7),
                                              ],
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: OutlinedText(
                                            text: Text(
                                      tiles[index].name ?? "Unknown Name",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            strokes: [
                                              OutlinedTextStroke(
                                          color: Colors.black, width: 4),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        );
      case WidgetMarker.videos:
        return Container(
          key: const ValueKey('videos'),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: (playlists.isEmpty)
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                    color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.goldBase.withOpacity(0.3),
                      width: 1,
                              ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _quotaExceeded 
                                      ? "YouTube API quota exceeded."
                                      : "No Cat Videos Available.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_quotaExceeded)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      "Videos will be available after quota resets.",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white70,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                    color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                      color: AppTheme.goldBase.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            separatorBuilder: (context, index) => Divider(
                              thickness: 1.0,
                      color: Colors.white.withOpacity(0.2),
                            ),
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: PlaylistRow(
                                  displayDescription: false,
                                  playlist: playlists[index],
                                ),
                              );
                            },
                          ),
                        ),
        );
      case WidgetMarker.stats:
        return Container(
          key: const ValueKey('stats'),
          margin: const EdgeInsets.symmetric(horizontal: 16),
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
          padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                      color: AppTheme.goldBase.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics_outlined,
                      color: AppTheme.goldBase,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "Breed Traits & Fit",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.showUserComparison) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Bar = breed • Triangle = your preference',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        separatorBuilder: (context, index) => Divider(
                          thickness: 1.0,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        itemCount: widget.breed.stats.length,
                        itemBuilder: (context, index) {
                          const segmentCount = 5;
                          const barHeight = 14.0;
                          const rowHeight = 20.0;
                          const triangleWidth = 20.0;
                          const triangleHeight = 20.0;

                          final maxVal = maxValues[index].toDouble();
                          final breedValue = widget.breed.stats[index].value.toDouble();
                          final filledSegments = widget.breed.stats[index].isPercent
                              ? ((breedValue / maxVal) * segmentCount).round().clamp(0, segmentCount)
                              : segmentCount;
                          // Fit screen stores slider by question.id (e.g. Grooming Needs is id 8, not list index 7)
                          final questionId = index < Question.questions.length
                              ? Question.questions[index].id
                              : index;
                          final userSliderValue = questionId < globals.FelineFinderServer.instance.sliderValue.length
                              ? globals.FelineFinderServer.instance.sliderValue[questionId]
                              : 0;
                          final showTriangle = widget.showUserComparison &&
                              widget.breed.stats[index].isPercent &&
                              userSliderValue > 0;
                          // User preference scale uses this question's choice count (e.g. Grooming has 0-4, not 0-5)
                          final userMax = index < Question.questions.length
                              ? (Question.questions[index].choices.length - 1).clamp(1, 10)
                              : maxVal.toInt();
                          // Which segment (1..5) the user preference falls in; triangle will be centered in that segment
                          final userSegmentIndex = showTriangle
                              ? (userSliderValue / userMax * segmentCount + 0.5).round().clamp(1, segmentCount)
                              : 1;

                          final statName = widget.breed.stats[index].name;
                          final traitLabel = statName == 'Willingness to be petted'
                              ? 'Handling'
                              : statName == 'Good with Children'
                                  ? 'Children'
                                  : statName == 'Good with other pets'
                                      ? 'Pets'
                                      : statName == 'TLC'
                                          ? 'Care'
                                          : statName;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    traitLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
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
                                        // Center of segment userSegmentIndex (1-based): (index - 0.5) / 5
                                        final left = showTriangle
                                            ? (barWidth * (userSegmentIndex - 0.5) / segmentCount - triangleWidth / 2)
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
                                                  final isFilled = segmentIndex <= filledSegments;
                                                  final isFirst = i == 0;
                                                  final isLast = i == segmentCount - 1;
                                                  return Expanded(
                                                    child: Container(
                                                      margin: EdgeInsets.only(right: isLast ? 0 : 1),
                                                      decoration: BoxDecoration(
                                                        color: isFilled ? AppTheme.goldBase : Colors.white24,
                                                        borderRadius: BorderRadius.horizontal(
                                                          left: Radius.circular(isFirst ? 6 : 0),
                                                          right: Radius.circular(isLast ? 6 : 0),
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
                                                  size: const Size(triangleWidth, triangleHeight),
                                                  painter: _GoldTrianglePainter(),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
        );
      case WidgetMarker.info:
        return Container(
          key: const ValueKey('info'),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: textBox(widget.breed.name, widget.breed.breedSummary),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1
    return Scaffold(
      appBar: GradientAppBar(
        title: "Feline Finder",
      ),
      // 2
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: <Widget>[
              // 4 - YouTube Video Thumbnail with Play Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: Builder(
                  builder: (context) {
                  // Only show thumbnail if cats101URL is available
                  print('cats101URL: ${widget.breed.cats101URL}');
                  if (widget.breed.cats101URL.isEmpty) {
                    print('cats101URL is empty, using fallback image');
                    // Fallback to breed image if no video URL — no frame on breed detail
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image(
                            width: double.infinity,
                            fit: BoxFit.cover,
                            image: AssetImage(
                                'assets/Full/${widget.breed.fullSizedPicture.replaceAll(' ', '_')}.jpg'),
                          ),
                        ),
                      ),
                    );
                  }

                  final videoId = _extractVideoId(widget.breed.cats101URL);
                  final thumbnailUrl = _getYouTubeThumbnail(videoId);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                          aspectRatio: 16 / 9, // YouTube thumbnail aspect ratio
                          child: GestureDetector(
                          onTap: () async {
                            // Open video directly; connectivity checks often give false "no internet"
                            // (e.g. slow network, firewall on lookup URL). If the video fails to load,
                            // the player will show an error.
                            Get.to(
                              () => YouTubeVideoRow(
                                playlist: null,
                                title: '${widget.breed.name} - Cats 101',
                                videoid: videoId,
                                fullScreen: false,
                              ),
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
          children: [
                              // YouTube thumbnail image
                              Image.network(
                                thumbnailUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // Log the error for debugging
                                  print('Failed to load YouTube thumbnail: $error');
                                  print('Stack trace: $stackTrace');
                                  // Try fallback thumbnail (hqdefault.jpg) if maxresdefault fails
                                  final fallbackUrl = 'https://img.youtube.com/vi/${_extractVideoId(widget.breed.cats101URL)}/hqdefault.jpg';
                                  print('Trying fallback thumbnail: $fallbackUrl');
                                  return Image.network(
                                    fallbackUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error2, stackTrace2) {
                                      print('Fallback thumbnail also failed: $error2');
                                      // Final fallback to breed image if both thumbnails fail
                                      return Image(
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        image: AssetImage(
                                            'assets/Full/${widget.breed.fullSizedPicture.replaceAll(' ', '_')}.jpg'),
                                      );
                                    },
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Small play icon in bottom-right corner with pulse animation
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: AnimatedBuilder(
                                  animation: _playButtonPulseController,
                                  builder: (context, child) {
                                    final scale = 1.0 + (_playButtonPulseController.value * 0.05);
                                    return Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        width: 48,
                                        height: 48,
              decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.7),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.5),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
              ),
              child: const Icon(
                                          Icons.play_arrow,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
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
              ),
              const SizedBox(height: 20),
              // Gold Flowing Ribbon with Breed Name
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.2),
                    end: Offset.zero,
                  ).animate(_fadeAnimation),
                  child: _buildGoldRibbon(widget.breed.name),
                ),
              ),
              const SizedBox(height: 20),
              // Circular 3D Gold Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  final isSelected = index == hilightedCell;
                  return _buildCircularGoldButton(
                    icon: icons[index],
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        hilightedCell = index;
                        selectedWidgetMarker = selectedIcon[index];
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Tab content with smooth transitions
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _buildTabContent(),
              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
  }

  Widget _buildCircularGoldButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowValue = isSelected 
            ? 0.5 + (_glowController.value * 0.5) // Pulse between 0.5 and 1.0
            : 0.3;
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.goldHighlight,
                  AppTheme.goldBase,
                  AppTheme.goldShadow,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                // Inner shadow for 3D effect
                BoxShadow(
                  color: AppTheme.goldShadow.withOpacity(0.8),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                  spreadRadius: -2,
                ),
                // Outer glow for selected button
                if (isSelected)
                  BoxShadow(
                    color: AppTheme.goldBase.withOpacity(glowValue),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                // Standard shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
              ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoldRibbon(String breedName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomPaint(
        painter: _GoldRibbonPainter(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Center(
            child: Text(
              breedName,
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
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget textBox(String title, String textBlock) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.goldBase.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
            // Summary text
            Text(
                    textBlock.isEmpty
                        ? "No description available."
                  : _getSummary(textBlock),
                    textAlign: TextAlign.left,
              style: GoogleFonts.poppins(
                      fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                      height: 1.5,
                    ),
            ),
            const SizedBox(height: 16),
            // Wikipedia link button
            if (textBlock.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _openWikipediaArticle,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  'Read Full Article on Wikipedia',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldBase,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
              ),
            ),
          ],
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

    // Same theme gold as circular buttons and favorite icon
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.goldHighlight,
        AppTheme.goldBase,
        AppTheme.goldShadow,
      ],
      stops: [0.0, 0.5, 1.0],
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

    // Add gold border (theme gold)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppTheme.goldShadow
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gold triangle for bar chart (user preference marker); matches pet detail style.
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
