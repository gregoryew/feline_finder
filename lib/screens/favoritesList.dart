import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../ExampleCode/RescueGroupsQuery.dart';
import '../ExampleCode/petTileData.dart';
import '../models/rescuegroups_v5.dart';
import '../screens/globals.dart' as globals;
import '../screens/petDetail.dart';
import '../theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FavoritesListScreen extends StatefulWidget {
  const FavoritesListScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesListScreen> createState() => _FavoritesListScreenState();
}

class _FavoritesListScreenState extends State<FavoritesListScreen> {
  List<PetTileData> favoritePets = [];
  bool isLoading = true;
  String? errorMessage;
  String? userID;
  final globals.FelineFinderServer server = globals.FelineFinderServer.instance;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get user ID
      userID = await server.getUser();
      
      // Get favorites list
      List<String> favorites = await server.getFavorites(userID!);
      
      // Update globals
      globals.listOfFavorites = favorites;

      if (favorites.isEmpty) {
        setState(() {
          favoritePets = [];
          isLoading = false;
        });
        return;
      }

      // Query RescueGroups API with favorite IDs
      await _fetchFavoritePets(favorites);
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() {
        errorMessage = 'Failed to load favorites: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchFavoritePets(List<String> favoriteIDs) async {
    try {
      String baseUrl =
          "https://api.rescuegroups.org/v5/public/animals/search/available";
      String url =
          "$baseUrl?fields[animals]=distance,id,ageGroup,sex,sizeGroup,name,breedPrimary,updatedDate,status,descriptionText"
          "&sort=animals.distance&limit=100&page=1";

      // Create filter for favorite IDs
      List<Map> filtersJson = [
        {
          "fieldName": "animals.id",
          "operation": "equal",
          "criteria": favoriteIDs,
        }
      ];

      // API requires filterRadius; when zip unknown use center of USA + largest distance so favorites still load
      final bool zipUnknown = server.zip.isEmpty || server.zip == "?";
      final String postalcode = zipUnknown ? AppConfig.centerOfUsaZipCode : server.zip;
      final int miles = zipUnknown ? AppConfig.maxDistanceMiles : 3000;

      Map<String, dynamic> data = {
        "data": {
          "filterRadius": {
            "miles": miles,
            "postalcode": postalcode,
          },
          "filters": filtersJson,
        }
      };

      var requestBody = json.encode(RescueGroupsQuery.fromJson(data).toJson());
      final encodedUrl = url.replaceAll('[', '%5B').replaceAll(']', '%5D');

      var response = await http.post(
        Uri.parse(encodedUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': AppConfig.rescueGroupsApiKey,
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to load favorites: ${response.body}");
      }

      if (response.body.isEmpty) {
        setState(() {
          favoritePets = [];
          isLoading = false;
        });
        return;
      }

      var jsonMap = jsonDecode(response.body);
      pet petDecoded = pet.fromJson(jsonMap);

      List<PetTileData> pets = [];
      if (petDecoded.data != null && petDecoded.included != null) {
        for (var petData in petDecoded.data!) {
          pets.add(PetTileData(petData, petDecoded.included!));
        }
      }

      setState(() {
        favoritePets = pets;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching favorite pets: $e');
      setState(() {
        errorMessage = 'Failed to fetch favorite pets: $e';
        isLoading = false;
      });
    }
  }

  String _getAvailabilityStatus(PetTileData pet) {
    // Check if pet is still available
    // Status "Available" means still available, others mean adopted/not available
    if (pet.status?.toLowerCase() == 'available') {
      return 'Available';
    } else if (pet.status?.toLowerCase() == 'adopted') {
      return 'Adopted';
    } else {
      return pet.status ?? 'Unknown';
    }
  }

  Color _getAvailabilityColor(String status) {
    if (status.toLowerCase() == 'available') {
      return Colors.green;
    } else if (status.toLowerCase() == 'adopted') {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepPurple,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      "Saved Cats",
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.fontSizeXXL,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.goldBase,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.goldBase),
                        ),
                      )
                    : errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTheme.fontSizeM,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadFavorites,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.goldBase,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : favoritePets.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.favorite_border,
                                      color: Colors.white70,
                                      size: 64,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No saved cats yet',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: AppTheme.fontSizeL,
                                        fontFamily: AppTheme.fontFamily,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tap the heart icon on any cat\nto save them here',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: AppTheme.fontSizeM,
                                        fontFamily: AppTheme.fontFamily,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadFavorites,
                                color: AppTheme.goldBase,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: favoritePets.length,
                                  itemBuilder: (context, index) {
                                    final pet = favoritePets[index];
                                    final availabilityStatus =
                                        _getAvailabilityStatus(pet);
                                    final availabilityColor =
                                        _getAvailabilityColor(availabilityStatus);

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: InkWell(
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => petDetail(
                                                pet.id!,
                                              ),
                                            ),
                                          );
                                          // Refresh favorites list when returning from detail screen
                                          _loadFavorites();
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              // Cat photo
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: pet.smallPicture != null
                                                    ? CachedNetworkImage(
                                                        imageUrl:
                                                            pet.smallPicture!,
                                                        width: 80,
                                                        height: 80,
                                                        fit: BoxFit.cover,
                                                        placeholder:
                                                            (context, url) =>
                                                                Container(
                                                          width: 80,
                                                          height: 80,
                                                          color: Colors.grey[
                                                              300],
                                                          child: Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                          ),
                                                        ),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Container(
                                                          width: 80,
                                                          height: 80,
                                                          color: Colors.grey[
                                                              300],
                                                          child: Icon(
                                                            Icons.pets,
                                                            color: Colors.grey[
                                                                600],
                                                          ),
                                                        ),
                                                      )
                                                    : Container(
                                                        width: 80,
                                                        height: 80,
                                                        color: Colors.grey[300],
                                                        child: Icon(
                                                          Icons.pets,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                              ),
                                              SizedBox(width: 16),
                                              // Cat name and availability
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      pet.name ?? 'Unknown',
                                                      style: TextStyle(
                                                        fontSize:
                                                            AppTheme.fontSizeL,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily:
                                                            AppTheme.fontFamily,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                availabilityColor
                                                                    .withOpacity(
                                                                        0.2),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                              color:
                                                                  availabilityColor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            availabilityStatus,
                                                            style: TextStyle(
                                                              fontSize:
                                                                  AppTheme
                                                                      .fontSizeS,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  availabilityColor,
                                                              fontFamily:
                                                                  AppTheme
                                                                      .fontFamily,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right,
                                                color: Colors.grey[400],
                                              ),
                                            ],
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
      ),
    );
  }
}

