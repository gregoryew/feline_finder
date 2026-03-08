import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'package:visibility_detector/visibility_detector.dart';

import '../theme.dart';
import '../network_utils.dart';
import '../models/zippopotam.dart';
import '../config.dart';
import 'globals.dart' as globals;
import 'search.dart';
import 'select_shelters_screen.dart';
import '../ExampleCode/RescueGroupsQuery.dart';
import '../models/searchPageConfig.dart' as searchConfig;

/// Display model for one shelter or rescue on the Shelters Near You screen.
class ShelterListItem {
  final String orgId;
  final String name;
  final double distanceMiles;
  final String? imageUrl;
  final int catsAvailable;
  final String activeText; // e.g. "Data Updated this week"
  final String repliesText; // e.g. "Usually replies in 24h"
  final List<String> tags; // e.g. ["Foster-Based", "Non-Profit"]
  final bool verified; // green check vs blue "?"
  final double? lat;
  final double? lon;
  /// True if from rescues view, false if from shelters view. Null for legacy items (treated as rescue).
  final bool? isRescue;
  /// True if the org has at least one available kitten (Baby age group).
  final bool hasKittens;
  /// True if org about/services text indicates no-kill (heuristic).
  final bool hasNoKill;
  /// True if org about/services text suggests foster homes (heuristic).
  final bool hasFosterHomes;

  ShelterListItem({
    required this.orgId,
    required this.name,
    required this.distanceMiles,
    this.imageUrl,
    this.catsAvailable = 0,
    this.activeText = 'Data Updated this month',
    this.repliesText = 'Usually replies in 24h',
    this.tags = const [],
    this.verified = false,
    this.lat,
    this.lon,
    this.isRescue = true,
    this.hasKittens = false,
    this.hasNoKill = false,
    this.hasFosterHomes = false,
  });
}

class SheltersNearYouScreen extends StatefulWidget {
  const SheltersNearYouScreen({Key? key}) : super(key: key);

  @override
  State<SheltersNearYouScreen> createState() => _SheltersNearYouScreenState();
}

/// Default map center when user location is unknown (Mountain View, CA).
const double _kDefaultMapLat = 37.3861;
const double _kDefaultMapLon = -122.0839;

class _SheltersNearYouScreenState extends State<SheltersNearYouScreen> {
  String _locationDisplay = 'Getting location…';
  double? _userLat;
  double? _userLon;
  bool _locationLoading = true;
  List<ShelterListItem> _shelters = [];
  bool _sheltersLoading = true;
  Set<String> _savedOrgIds = {};
  GoogleMapController? _mapController;
  bool _mapReady = false;

  /// Cache for distance-based results. Invalid when location or 24h expiry change.
  List<ShelterListItem>? _cachedShelters;
  String? _cacheZip;
  DateTime? _cacheTime;
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Static cache so shelter list survives when this widget's State is recreated (e.g. tab switch without IndexedStack, or navigation).
  static List<ShelterListItem>? _staticCachedShelters;
  static String? _staticCacheZip;
  static DateTime? _staticCacheTime;

  static const String _savedSheltersKey = 'shelters_near_you_saved_org_ids';
  static const String _savedLocationKey = 'shelters_near_you_location';

  /// Returns data-updated label from most recent cat update date: today / this week / this month / not recent.
  static String _activeTextFromDate(DateTime? updatedDate) {
    if (updatedDate == null) return 'Data not updated recently';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updatedDay = DateTime(updatedDate.year, updatedDate.month, updatedDate.day);
    if (updatedDay == today) return 'Data Updated today';
    final diff = today.difference(updatedDay).inDays;
    if (diff >= 1 && diff < 7) return 'Data Updated this week';
    if (updatedDate.year == now.year && updatedDate.month == now.month) return 'Data Updated this month';
    return 'Data not updated recently';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedShelters();
    _loadLocation();
    _loadShelters();
  }

  Set<Marker> get _shelterMarkers {
    final Set<Marker> markers = {};
    for (var i = 0; i < _shelters.length; i++) {
      final s = _shelters[i];
      if (s.lat == null || s.lon == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(s.orgId),
          position: LatLng(s.lat!, s.lon!),
          infoWindow: InfoWindow(
            title: s.name,
            snippet: s.distanceMiles == 0 ? '${s.catsAvailable} cats' : '${s.distanceMiles.toStringAsFixed(1)} mi · ${s.catsAvailable} cats',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );
    }
    return markers;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSavedShelters() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_savedSheltersKey);
    if (list != null && mounted) {
      setState(() => _savedOrgIds = list.toSet());
    }
  }

  Future<void> _saveShelter(String orgId) async {
    _savedOrgIds = {..._savedOrgIds, orgId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedSheltersKey, _savedOrgIds.toList());
    if (mounted) setState(() {});
  }

  Future<void> _unsaveShelter(String orgId) async {
    _savedOrgIds = _savedOrgIds.where((id) => id != orgId).toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedSheltersKey, _savedOrgIds.toList());
    if (mounted) setState(() {});
  }

  /// Sync location display and shelter list from canonical zip (e.g. after user changed zip on another screen).
  /// Call when this screen becomes visible so we stay in sync. Shows city (and state) for the zip when available.
  Future<void> _syncLocationFromCanonicalZip() async {
    final server = globals.FelineFinderServer.instance;
    await server.loadZipCodeFromPrefs();
    final currentZip = server.zip;
    String display = 'Location unknown';
    if (currentZip.isNotEmpty && currentZip != '?' && currentZip.length >= 5) {
      final placeName = await _getPlaceNameAndStateForZip(currentZip);
      display = placeName ?? 'ZIP $currentZip';
    }
    final zipChanged = _cacheZip != null && _cacheZip != currentZip;
    if (!mounted) return;
    setState(() {
      _locationDisplay = display;
    });
    if (zipChanged && currentZip.isNotEmpty && currentZip != '?' && currentZip.length >= 5) {
      _loadShelters();
    }
  }

  /// Public entry point so HomeScreen can trigger zip sync when switching to Shelters tab.
  Future<void> syncZipFromCanonical() async {
    await _syncLocationFromCanonicalZip();
  }

  Future<void> _loadLocation() async {
    setState(() => _locationLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_savedLocationKey);
      if (saved != null && saved.isNotEmpty) {
        if (mounted) setState(() {
          _locationDisplay = saved;
          _locationLoading = false;
        });
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final server = globals.FelineFinderServer.instance;
        if (server.zip.isNotEmpty && server.zip != '?') {
          final placeName = await _getPlaceNameAndStateForZip(server.zip);
          _locationDisplay = placeName ?? 'ZIP ${server.zip}';
        } else {
          _locationDisplay = 'Location unknown';
        }
        if (mounted) setState(() => _locationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        final server = globals.FelineFinderServer.instance;
        if (server.zip.isNotEmpty && server.zip != '?') {
          final placeName = await _getPlaceNameAndStateForZip(server.zip);
          _locationDisplay = placeName ?? 'ZIP ${server.zip}';
        } else {
          _locationDisplay = 'Location unknown';
        }
        if (mounted) setState(() => _locationLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String display = 'Location unknown';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          if (p.locality != null && p.locality!.isNotEmpty) p.locality,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea,
        ];
        display = parts.join(', ');
      }
      if (mounted) {
        setState(() {
          _locationDisplay = display;
          _userLat = position.latitude;
          _userLon = position.longitude;
          _locationLoading = false;
        });
      }
    } catch (e) {
      final server = globals.FelineFinderServer.instance;
      if (server.zip.isNotEmpty && server.zip != '?') {
        final placeName = await _getPlaceNameAndStateForZip(server.zip);
        _locationDisplay = placeName ?? 'ZIP ${server.zip}';
      } else {
        _locationDisplay = 'Location unknown';
      }
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  /// Fetches place name and state abbreviation for a valid ZIP via zippopotam (same service as validation).
  Future<String?> _getPlaceNameAndStateForZip(String zip) async {
    try {
      final response = await http.get(Uri.parse('https://api.zippopotam.us/us/$zip'));
      if (response.statusCode != 200) return null;
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>?;
      if (jsonData == null || jsonData.isEmpty) return null;
      final places = Zippopotam.fromJson(jsonData);
      if (places.places.isEmpty) return null;
      final p = places.places.first;
      final name = p.placeName.trim();
      final state = (p.stateAbbreviation.isNotEmpty ? p.stateAbbreviation : p.state).trim();
      if (name.isEmpty && state.isEmpty) return null;
      if (name.isNotEmpty && state.isNotEmpty) return '$name, $state';
      return name.isNotEmpty ? name : state;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onEditLocation() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.deepPurple,
        title: Text(
          'Enter ZIP code',
          style: TextStyle(color: AppTheme.goldBase, fontFamily: AppTheme.fontFamily),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'ZIP code',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.goldBase),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.goldHighlight, width: 2),
            ),
          ),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.goldBase)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Search', style: TextStyle(color: AppTheme.goldBase)),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final zipTrimmed = result.trim();
    if (zipTrimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ZIP code cannot be blank. Please enter a valid ZIP code.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (zipTrimmed.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ZIP code must be 5 digits.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (zipTrimmed.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ZIP code must be exactly 5 digits.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final server = globals.FelineFinderServer.instance;
    try {
      final isValid = await server.isZipCodeValid(zipTrimmed);
      if (isValid == true) {
        final oldZip = (server.zip ?? '').trim();
        if (zipTrimmed != oldZip) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('lastSearchShelterOrgIds');
          await prefs.remove('lastSearchShelterNames');
          final filtersJsonString = prefs.getString('lastSearchFiltersList');
          if (filtersJsonString != null && filtersJsonString.isNotEmpty) {
            final filtersJson = jsonDecode(filtersJsonString) as List<dynamic>;
            final updated = filtersJson.where((f) => (f as Map)['fieldName'] != 'orgs.id').toList();
            await prefs.setString('lastSearchFiltersList', jsonEncode(updated));
            await prefs.setString('lastSearchFilterProcessing', '');
          }
        }
        await server.setZipCode(zipTrimmed);
        final display = await _getPlaceNameAndStateForZip(zipTrimmed);
        if (mounted) {
          setState(() {
            _locationDisplay = display ?? 'ZIP $zipTrimmed';
          });
          _cacheZip = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_savedLocationKey, _locationDisplay);
        }
        _loadShelters();
      } else if (isValid == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Network error. Please check your internet connection and try again.',
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('ZIP code "$zipTrimmed" is not valid. Please enter a valid US ZIP code.'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (isNetworkError(e)) {
          showNetworkErrorSnackBar(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error validating ZIP code. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Load shelter list: RescueGroups org search by distance from zip (SharedPreferences), ordered by distance.
  /// Uses cache when location and chips unchanged and cache is under 24h old.
  Future<void> _loadShelters() async {
    setState(() => _sheltersLoading = true);
    try {
      List<ShelterListItem> list = [];
      final server = globals.FelineFinderServer.instance;
      await server.loadZipCodeFromPrefs();
      String zipCode = server.zip;
      if (zipCode.isEmpty || zipCode == '?' || zipCode.length < 5) {
        zipCode = AppConfig.defaultZipCode;
      }
      zipCode = zipCode.trim();
      if (zipCode.length > 5) zipCode = zipCode.substring(0, 5);

      // Prefer in-memory cache, then static cache (survives State recreation)
      final memoryCacheValid = _cachedShelters != null &&
          _cacheZip == zipCode &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheExpiry;
      final staticCacheValid = _staticCachedShelters != null &&
          _staticCacheZip == zipCode &&
          _staticCacheTime != null &&
          DateTime.now().difference(_staticCacheTime!) < _cacheExpiry;

      if (memoryCacheValid) {
        if (mounted) {
          setState(() {
            _shelters = _cachedShelters!;
            _sheltersLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsIfNeeded());
        }
        return;
      }
      if (staticCacheValid) {
        _cachedShelters = _staticCachedShelters;
        _cacheZip = _staticCacheZip;
        _cacheTime = _staticCacheTime;
        if (mounted) {
          setState(() {
            _shelters = _cachedShelters!;
            _sheltersLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsIfNeeded());
        }
        return;
      }

      final apiKey = AppConfig.rescueGroupsApiKey;
      if (apiKey.isNotEmpty && zipCode.length >= 5) {
        const radiusMiles = 200;
        List<OrgByDistanceResult> combined = [];
        try {
          combined = await searchOrganizationsByDistanceSingle(
            postalcode: zipCode,
            miles: radiusMiles,
          );
          combined.sort((a, b) => a.distanceMiles.compareTo(b.distanceMiles));
          print('📊 Shelters Near You: ${combined.length} org(s) (single endpoint)');
        } catch (e) {
          print('Org by-distance search failed: $e');
          if (mounted && isNetworkError(e)) showNetworkErrorSnackBar(context);
        }
        try {
          final catCounts = await getAvailableCatsCountByOrg(
            postalcode: zipCode,
            miles: radiusMiles,
          );
          final recentCats = await getMostRecentCatPerOrg(
            postalcode: zipCode,
            miles: radiusMiles,
          );
          final orgIdsWithKittens = await getOrgIdsWithKittens(postalcode: zipCode, miles: radiusMiles);
          for (final r in combined) {
            final catsAvailable = catCounts[r.orgId] ?? 0;
            if (catsAvailable == 0) continue;
            final recent = recentCats[r.orgId];
            final hasKittens = orgIdsWithKittens.contains(r.orgId);
            final hasNoKill = isNoKillFromText(r.about, r.services);
            final hasFosterHomes = hasFosterHomesFromText(r.about, r.services);
            final tags = <String>[
              if (hasKittens) 'Kittens',
              if (hasNoKill) 'No-Kill',
              if (hasFosterHomes) 'Foster Homes',
            ];
            list.add(ShelterListItem(
              orgId: r.orgId,
              name: r.name,
              distanceMiles: r.distanceMiles,
              lat: r.lat,
              lon: r.lon,
              catsAvailable: catsAvailable,
              imageUrl: recent?.thumbnailUrl,
              activeText: _activeTextFromDate(recent?.updatedDate),
              tags: tags,
              verified: false,
              isRescue: r.isRescue,
              hasKittens: hasKittens,
              hasNoKill: hasNoKill,
              hasFosterHomes: hasFosterHomes,
            ));
          }
        } catch (e) {
          print('Cat counts / recent cats / kittens by org failed: $e');
        }
      }
      if (list.isEmpty) {
        list = _demoShelters();
      }
      list.sort((a, b) => a.distanceMiles.compareTo(b.distanceMiles));
      final centerLat = _userLat ?? _kDefaultMapLat;
      final centerLon = _userLon ?? _kDefaultMapLon;
      list = _assignShelterCoordinates(list, centerLat, centerLon);
      _cachedShelters = list;
      _cacheZip = zipCode;
      _cacheTime = DateTime.now();
      _staticCachedShelters = list;
      _staticCacheZip = zipCode;
      _staticCacheTime = DateTime.now();
      if (mounted) {
        setState(() {
          _shelters = list;
          _sheltersLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsIfNeeded());
      }
    } catch (e) {
      if (mounted && isNetworkError(e)) showNetworkErrorSnackBar(context);
      final list = _demoShelters();
      final centerLat = _userLat ?? _kDefaultMapLat;
      final centerLon = _userLon ?? _kDefaultMapLon;
      if (mounted) {
        setState(() {
          _shelters = _assignShelterCoordinates(list, centerLat, centerLon);
          _sheltersLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsIfNeeded());
      }
    }
  }

  /// Assigns lat/lon to shelters that don't have them, spreading around [centerLat],[centerLon].
  List<ShelterListItem> _assignShelterCoordinates(
    List<ShelterListItem> list,
    double centerLat,
    double centerLon,
  ) {
    const radiusDeg = 0.012; // ~1.3 km spread
    return list.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      if (s.lat != null && s.lon != null) return s;
      final angle = i * 0.7;
      final lat = centerLat + radiusDeg * cos(angle);
      final lon = centerLon + radiusDeg * sin(angle);
      return ShelterListItem(
        orgId: s.orgId,
        name: s.name,
        distanceMiles: s.distanceMiles,
        imageUrl: s.imageUrl,
        catsAvailable: s.catsAvailable,
        activeText: s.activeText,
        repliesText: s.repliesText,
        tags: s.tags,
        verified: s.verified,
        lat: lat,
        lon: lon,
        isRescue: s.isRescue,
        hasKittens: s.hasKittens,
        hasNoKill: s.hasNoKill,
        hasFosterHomes: s.hasFosterHomes,
      );
    }).toList();
  }

  List<ShelterListItem> _demoShelters() {
    return [
      ShelterListItem(
        orgId: 'demo1',
        name: 'Happy Tails Rescue',
        distanceMiles: 2.11,
        imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=200&h=200&fit=crop',
        catsAvailable: 18,
        activeText: 'Data Updated this week',
        repliesText: 'Usually replies in 24h',
        tags: ['Foster-Based', 'Non-Profit', 'Kittens'],
        verified: true,
        isRescue: true,
        hasKittens: true,
        hasFosterHomes: true,
      ),
      ShelterListItem(
        orgId: 'demo2',
        name: 'Purrfect Paws Shelter',
        distanceMiles: 1.0,
        imageUrl: 'https://images.unsplash.com/photo-1573865526739-10089f7c8164?w=200&h=200&fit=crop',
        catsAvailable: 7,
        activeText: 'Data Updated this month',
        repliesText: 'Usually replies in 24h',
        tags: ['No-Kill', 'Community Partner'],
        verified: false,
        isRescue: false,
        hasKittens: false,
        hasNoKill: true,
        hasFosterHomes: false,
      ),
      ShelterListItem(
        orgId: 'demo3',
        name: 'Kitty Haven Adoption',
        distanceMiles: 33.5,
        imageUrl: 'https://images.unsplash.com/photo-1592194996308-7b43878e84a6?w=200&h=200&fit=crop',
        catsAvailable: 12,
        activeText: 'Data Updated this month',
        repliesText: 'Usually replies in 48h',
        tags: ['No-Kill', 'Kittens'],
        verified: false,
        isRescue: false,
        hasKittens: true,
        hasFosterHomes: false,
      ),
    ];
  }

  /// Apply shelter-only filter and switch to adoption list (when opened from main tab).
  void _viewCatsForShelter(ShelterListItem shelter) {
    globals.lastShelterFromSheltersTabOrgId = shelter.orgId;
    globals.lastShelterFromSheltersTabName = shelter.name;
    final result = FilterResult(
      [
        Filters(fieldName: 'species.singular', operation: 'equal', criteria: ['cat']),
        Filters(fieldName: 'orgs.id', operation: 'equal', criteria: [shelter.orgId]),
      ],
      '1 AND 2',
    );
    globals.onApplySearchAndSwitchToAdopt?.call(result);
  }

  /// Open search screen with this shelter selected (when opened from search screen).
  void _selectShelterAndReturnToSearch(ShelterListItem shelter) {
    globals.sheltersOpenedFromSearch = false;
    globals.onSelectShelterAndOpenSearch?.call(shelter.orgId, shelter.name);
  }

  /// Launch maps app for directions to [lat],[lng]. Same logic as toolbar on cat detail.
  Future<void> _launchDirections(BuildContext context, double lat, double lng) async {
    String url;
    String urlAppleMaps = 'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d';
    if (Platform.isAndroid) {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    } else {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
      final urlGoogleApp = 'comgooglemaps://?saddr=&daddr=$lat,$lng&directionsmode=driving';
      if (await canLaunchUrl(Uri.parse(urlGoogleApp))) {
        await launchUrl(Uri.parse(urlGoogleApp));
        return;
      }
    }
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else if (await canLaunchUrl(Uri.parse(urlAppleMaps))) {
      await launchUrl(Uri.parse(urlAppleMaps));
    } else if (!context.mounted) {
      return;
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Maps not available'),
          content: const Text('Could not open a maps app for directions.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('shelters_near_you_screen'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0) _syncLocationFromCanonicalZip();
      },
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.purpleGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLocationRow(),
              _buildMap(),
              Expanded(
                child: _sheltersLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.goldBase),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _shelters.length,
                        itemBuilder: (context, index) => _buildShelterCard(_shelters[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organizations Near You',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontSizeXL,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '(${_shelters.where((s) => s.isRescue == false).length}) Shelters (${_shelters.where((s) => s.isRescue == true).length}) Rescues (${_shelters.where((s) => s.isRescue == null).length}) Other',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontSizeM,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _locationDisplay,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontSizeM,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _locationLoading ? null : _onEditLocation,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.fontSizeM,
                        color: AppTheme.goldBase,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.goldBase, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LatLng get _mapCenter {
    if (_userLat != null && _userLon != null) {
      return LatLng(_userLat!, _userLon!);
    }
    return const LatLng(_kDefaultMapLat, _kDefaultMapLon);
  }

  Widget _buildMap() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.goldBase.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _mapCenter,
            zoom: 12.0,
          ),
          markers: _shelterMarkers,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            setState(() => _mapReady = true);
            _fitBoundsIfNeeded();
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  void _fitBoundsIfNeeded() {
    final withCoords = _shelters.where((s) => s.lat != null && s.lon != null).toList();
    if (withCoords.length < 2 || _mapController == null) return;
    LatLngBounds? bounds;
    for (final s in withCoords) {
      final p = LatLng(s.lat!, s.lon!);
      if (bounds == null) {
        bounds = LatLngBounds(southwest: p, northeast: p);
      } else {
        bounds = _expandBounds(bounds, p);
      }
    }
    if (bounds != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
    }
  }

  LatLngBounds _expandBounds(LatLngBounds b, LatLng p) {
    final sw = b.southwest;
    final ne = b.northeast;
    return LatLngBounds(
      southwest: LatLng(
        p.latitude < sw.latitude ? p.latitude : sw.latitude,
        p.longitude < sw.longitude ? p.longitude : sw.longitude,
      ),
      northeast: LatLng(
        p.latitude > ne.latitude ? p.latitude : ne.latitude,
        p.longitude > ne.longitude ? p.longitude : ne.longitude,
      ),
    );
  }

  Widget _buildShelterCard(ShelterListItem s) {
    final isSaved = _savedOrgIds.contains(s.orgId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      color: AppTheme.lightLavender.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: s.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: s.imageUrl!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.deepPurple.withOpacity(0.2),
                            child: const Icon(Icons.pets, color: AppTheme.goldBase),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.deepPurple.withOpacity(0.2),
                            child: const Icon(Icons.pets, color: AppTheme.goldBase),
                          ),
                        )
                      : Container(
                          width: 90,
                          height: 90,
                          color: AppTheme.deepPurple.withOpacity(0.2),
                          child: const Icon(Icons.pets, color: AppTheme.goldBase, size: 40),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.fontSizeL,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.goldBase.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s.isRescue == null ? 'Other' : (s.isRescue! ? 'Rescue' : 'Shelter'),
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeXS,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.deepPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _detailRow(Icons.location_on_outlined, s.distanceMiles == 0 ? '—' : '${s.distanceMiles.toStringAsFixed(2)} miles away'),
                      _detailRow(Icons.pets, '${s.catsAvailable} cats available'),
                      _detailRow(Icons.trending_up, s.activeText),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: s.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.goldBase.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeXS,
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (globals.sheltersOpenedFromSearch) {
                        _selectShelterAndReturnToSearch(s);
                      } else {
                        _viewCatsForShelter(s);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldBase,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                      ),
                    ),
                    child: Text(globals.sheltersOpenedFromSearch ? 'Select' : 'View Cats'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: s.lat != null && s.lon != null
                        ? () => _launchDirections(context, s.lat!, s.lon!)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldBase,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppTheme.goldBase.withOpacity(0.5),
                      disabledForegroundColor: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                      ),
                    ),
                    child: const Text('Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.deepPurple.withOpacity(0.8)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontSizeS,
              color: AppTheme.darkText,
            ),
          ),
        ],
      ),
    );
  }
}
