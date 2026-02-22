import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../theme.dart';
import 'search_screen_style.dart';

/// RescueGroups v5 organizations search endpoint (name contains).
const String _kRescueGroupsOrgsSearchUrl =
    'https://api.rescuegroups.org/v5/public/orgs/search/rescue/?fields[orgs]=name,orgId';

/// Org search by name (contains), with distance when filterRadius is provided.
String _orgsSearchByNameUrl(String view) =>
    'https://api.rescuegroups.org/v5/public/orgs/search/$view/?fields[orgs]=name,orgId,about,services,distance,lat,lon&sort=orgs.distance&limit=100';

/// RescueGroups v5 organizations search by distance from postal code (ordered by distance).
/// [view] is the API view name: 'shelter' or 'rescue'.
String _orgsSearchByDistanceUrl(String view) =>
    'https://api.rescuegroups.org/v5/public/orgs/search/$view/?fields[orgs]=name,orgId,distance,lat,lon,city,state,about,services&sort=orgs.distance&limit=100';

/// Single endpoint (no org type in path). Returns all orgs in one request; isRescue from orgs.type when present.
const String _kOrgsSearchByDistanceBaseUrl =
    'https://api.rescuegroups.org/v5/public/orgs/search?fields[orgs]=name,orgId,distance,lat,lon,city,state,about,services,type&sort=orgs.distance&limit=100';

/// Result of an org search by distance (for use by Shelters Near You screen).
class OrgByDistanceResult {
  final String orgId;
  final String name;
  final double distanceMiles;
  final double? lat;
  final double? lon;
  /// True = rescue, false = shelter/shelters, null = other (unknown type).
  final bool? isRescue;
  final String? about;
  final String? services;

  OrgByDistanceResult({
    required this.orgId,
    required this.name,
    required this.distanceMiles,
    this.lat,
    this.lon,
    this.isRescue = true,
    this.about,
    this.services,
  });
}

/// Result of org search by name. Includes distance/lat/lon when filterRadius is used.
class OrgByNameResult {
  final String orgId;
  final String name;
  final String? about;
  final String? services;
  final bool isRescue;
  final double distanceMiles;
  final double? lat;
  final double? lon;

  OrgByNameResult({
    required this.orgId,
    required this.name,
    this.about,
    this.services,
    this.isRescue = true,
    this.distanceMiles = 0,
    this.lat,
    this.lon,
  });
}

/// Search orgs by name (contains) in both shelter and rescue views. Pass [postalcode] and [miles] to get distance; results sorted by distance ascending.
Future<List<OrgByNameResult>> searchOrganizationsByNameBothViews(
  String query, {
  required String postalcode,
  int miles = 2000,
}) async {
  final q = query.trim();
  if (q.isEmpty) return [];

  final apiKey = AppConfig.rescueGroupsApiKey;
  if (apiKey.isEmpty) throw Exception('RescueGroups API key not configured');

  final zip = postalcode.trim();
  if (zip.length < 5) return [];

  final body = {
    'data': {
      'filters': [
        {'fieldName': 'orgs.name', 'operation': 'contains', 'criteria': q},
      ],
      'filterProcessing': '1',
      'filterRadius': {
        'postalcode': zip.length >= 5 ? zip.substring(0, 5) : zip,
        'miles': miles,
      },
    },
  };

  final seen = <String>{};
  final List<OrgByNameResult> results = [];
  int shelterCount = 0;
  int rescueCount = 0;

  Future<void> addPage(String view) async {
    final isRescue = view == 'rescue';
    try {
      final response = await http.post(
        Uri.parse(_orgsSearchByNameUrl(view)),
        headers: {
          'Content-Type': 'application/vnd.api+json',
          'Authorization': apiKey,
        },
        body: json.encode(body),
      );
      if (response.statusCode != 200) return;
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      final data = jsonResponse['data'];
      if (data == null || data is! List) return;
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final attrs = item['attributes'] as Map<String, dynamic>?;
        final id = item['id']?.toString() ?? attrs?['orgId']?.toString();
        final name = attrs?['name']?.toString() ?? '';
        if (id == null || id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        double distanceMiles = 0;
        final dist = attrs?['distance'];
        if (dist != null) {
          if (dist is int) distanceMiles = dist.toDouble();
          else if (dist is num) distanceMiles = dist.toDouble();
        }
        double? lat;
        double? lon;
        final latVal = attrs?['lat'];
        final lonVal = attrs?['lon'];
        if (latVal != null && latVal is num) lat = latVal.toDouble();
        if (lonVal != null && lonVal is num) lon = lonVal.toDouble();
        results.add(OrgByNameResult(
          orgId: id,
          name: name,
          about: attrs?['about']?.toString(),
          services: attrs?['services']?.toString(),
          isRescue: isRescue,
          distanceMiles: distanceMiles,
          lat: lat,
          lon: lon,
        ));
        if (isRescue) {
          rescueCount++;
        } else {
          shelterCount++;
        }
      }
    } catch (_) {}
  }

  // Query shelter view first; if it returns nothing, try "shelters" (plural) like distance-based load.
  await addPage('shelter');
  if (shelterCount == 0) {
    await addPage('shelters');
  }
  await addPage('rescue');

  print('📊 Name search "$q": $shelterCount shelter(s), $rescueCount rescue(s)');
  results.sort((a, b) => a.distanceMiles.compareTo(b.distanceMiles));
  return results;
}

/// Heuristic: true if [about] or [services] text suggests no-kill (e.g. "no-kill", "no kill"). Avoids "not a no-kill".
bool isNoKillFromText(String? about, String? services) {
  String text = '${about ?? ''} ${services ?? ''}'.toLowerCase();
  if (text.isEmpty) return false;
  final noKill = text.contains('no-kill') || text.contains('no kill');
  if (!noKill) return false;
  final idx = text.contains('no-kill') ? text.indexOf('no-kill') : text.indexOf('no kill');
  final before = idx > 0 ? text.substring(0, idx).trim() : '';
  final negated = before.endsWith('not') || before.endsWith("n't") || before.endsWith('aren\'t');
  return !negated;
}

/// Heuristic: true if [about] or [services] text suggests foster homes (e.g. "foster", "foster-based", "foster home").
bool hasFosterHomesFromText(String? about, String? services) {
  String text = '${about ?? ''} ${services ?? ''}'.toLowerCase();
  if (text.isEmpty) return false;
  return text.contains('foster') ||
      text.contains('foster-based') ||
      text.contains('foster home') ||
      text.contains('foster care');
}

/// Single request to orgs search (no view in path). Returns all orgs by distance; isRescue defaults to true when type is unknown.
Future<List<OrgByDistanceResult>> searchOrganizationsByDistanceSingle({
  required String postalcode,
  int miles = 200,
}) async {
  final apiKey = AppConfig.rescueGroupsApiKey;
  if (apiKey.isEmpty) throw Exception('RescueGroups API key not configured');
  final zip = postalcode.trim();
  if (zip.isEmpty || zip.length < 5) return [];

  final body = {
    'data': {
      'filterRadius': {
        'postalcode': zip.length >= 5 ? zip.substring(0, 5) : zip,
        'miles': miles,
      },
    },
  };

  print('🔍 Org search by distance (single): postalcode=$zip, miles=$miles');

  final response = await http.post(
    Uri.parse(_kOrgsSearchByDistanceBaseUrl),
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Authorization': apiKey,
    },
    body: json.encode(body),
  );

  print('📥 Org by-distance response: status=${response.statusCode}');

  if (response.statusCode != 200) {
    throw Exception('Org search failed: ${response.statusCode} ${response.body}');
  }

  final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
  final data = jsonResponse['data'];
  if (data == null || data is! List) return [];

  final List<OrgByDistanceResult> results = [];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final attrs = item['attributes'] as Map<String, dynamic>?;
    final id = item['id']?.toString() ?? attrs?['orgId']?.toString();
    final name = attrs?['name']?.toString() ?? '';
    if (id == null || id.isEmpty) continue;
    final dist = attrs?['distance'];
    double distanceMiles = 0.0;
    if (dist != null) {
      if (dist is int) distanceMiles = dist.toDouble();
      else if (dist is double) distanceMiles = dist;
      else if (dist is num) distanceMiles = dist.toDouble();
    }
    double? lat;
    double? lon;
    final latVal = attrs?['lat'];
    final lonVal = attrs?['lon'];
    if (latVal != null && latVal is num) lat = latVal.toDouble();
    if (lonVal != null && lonVal is num) lon = lonVal.toDouble();
    final about = attrs?['about']?.toString();
    final services = attrs?['services']?.toString();
    final typeStr = attrs?['type']?.toString().toLowerCase() ?? '';
    final bool? isRescue = typeStr == 'rescue'
        ? true
        : (typeStr == 'shelter' || typeStr == 'shelters')
            ? false
            : null;
    results.add(OrgByDistanceResult(
      orgId: id,
      name: name,
      distanceMiles: distanceMiles,
      lat: lat,
      lon: lon,
      isRescue: isRescue,
      about: about,
      services: services,
    ));
  }
  return results;
}

/// Calls RescueGroups organizations search with filterRadius (postalcode + miles).
/// [view] must be 'shelter' or 'rescue'. Returns orgs ordered by distance (nearest first).
Future<List<OrgByDistanceResult>> searchOrganizationsByDistance({
  required String postalcode,
  int miles = 200,
  required String view,
}) async {
  final apiKey = AppConfig.rescueGroupsApiKey;
  if (apiKey.isEmpty) {
    throw Exception('RescueGroups API key not configured');
  }
  final zip = postalcode.trim();
  if (zip.isEmpty || zip.length < 5) {
    return [];
  }
  final isRescue = view == 'rescue';

  final body = {
    'data': {
      'filterRadius': {
        'postalcode': zip.length >= 5 ? zip.substring(0, 5) : zip,
        'miles': miles,
      },
    },
  };

  print('🔍 Org search by distance: view=$view, postalcode=$zip, miles=$miles');

  final response = await http.post(
    Uri.parse(_orgsSearchByDistanceUrl(view)),
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Authorization': apiKey,
    },
    body: json.encode(body),
  );

  print('📥 Org by-distance ($view) response: status=${response.statusCode}');

  if (response.statusCode != 200) {
    throw Exception('Org search failed: ${response.statusCode} ${response.body}');
  }

  final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
  final data = jsonResponse['data'];
  if (data == null || data is! List) return [];

  final List<OrgByDistanceResult> results = [];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final attrs = item['attributes'] as Map<String, dynamic>?;
    final id = item['id']?.toString() ?? attrs?['orgId']?.toString();
    final name = attrs?['name']?.toString() ?? '';
    if (id == null || id.isEmpty) continue;
    final dist = attrs?['distance'];
    double distanceMiles = 0.0;
    if (dist != null) {
      if (dist is int) distanceMiles = dist.toDouble();
      else if (dist is double) distanceMiles = dist;
      else if (dist is num) distanceMiles = dist.toDouble();
    }
    double? lat;
    double? lon;
    final latVal = attrs?['lat'];
    final lonVal = attrs?['lon'];
    if (latVal != null && latVal is num) lat = latVal.toDouble();
    if (lonVal != null && lonVal is num) lon = lonVal.toDouble();
    final about = attrs?['about']?.toString();
    final services = attrs?['services']?.toString();
    results.add(OrgByDistanceResult(
      orgId: id,
      name: name,
      distanceMiles: distanceMiles,
      lat: lat,
      lon: lon,
      isRescue: isRescue,
      about: about,
      services: services,
    ));
  }
  return results;
}

/// RescueGroups v5 animals search (available cats only) to count cats per org. Supports page= for pagination.
String _animalsSearchCountUrl(int page) =>
    'https://api.rescuegroups.org/v5/public/animals/search/available?fields[animals]=id&fields[orgs]=id&include=orgs&sort=animals.distance&limit=250&page=$page';

/// Per-org info: most recently updated cat's thumbnail and updated date (for Shelters Near You cards).
class RecentCatInfo {
  final String? thumbnailUrl;
  final DateTime? updatedDate;

  RecentCatInfo({this.thumbnailUrl, this.updatedDate});
}

/// RescueGroups v5 animals search: available cats with org + picture. Supports page= for pagination.
String _animalsSearchRecentUrl(int page) =>
    'https://api.rescuegroups.org/v5/public/animals/search/available?fields[animals]=id,updatedDate&fields[orgs]=id&include=orgs,pictures&sort=animals.distance&limit=250&page=$page';

/// Returns a map of orgId -> RecentCatInfo (thumbnail URL and updatedDate of most recently updated cat for that org).
Future<Map<String, RecentCatInfo>> getMostRecentCatPerOrg({
  required String postalcode,
  int miles = 200,
}) async {
  final apiKey = AppConfig.rescueGroupsApiKey;
  if (apiKey.isEmpty) return {};

  final zip = postalcode.trim();
  if (zip.isEmpty || zip.length < 5) return {};

  final body = {
    'data': {
      'filterRadius': {
        'postalcode': zip.length >= 5 ? zip.substring(0, 5) : zip,
        'miles': miles,
      },
      'filters': [
        {'fieldName': 'species.singular', 'operation': 'equal', 'criteria': ['cat']},
      ],
    },
  };

  final List<Map<String, dynamic>> allData = [];
  final List<dynamic> allIncluded = [];
  for (int page = 1; page <= 2; page++) {
    final response = await http.post(
      Uri.parse(_animalsSearchRecentUrl(page)),
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Authorization': apiKey,
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      if (page == 1) {
        print('📷 Most recent cat per org: API returned ${response.statusCode}');
        if (response.statusCode == 400 && response.body.isNotEmpty) {
          print('📷 400 body: ${response.body}');
        }
        return {};
      }
      break;
    }

    final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
    final data = jsonResponse['data'];
    final included = jsonResponse['included'];
    if (data is List) {
      for (final e in data) {
        if (e is Map<String, dynamic>) allData.add(e);
      }
    }
    if (included is List) allIncluded.addAll(included);
    if (data is! List || data.isEmpty) break;
  }

  if (allData.isEmpty) {
    print('📷 Most recent cat per org: no data');
    return {};
  }

  // Sort by updatedDate descending so first occurrence per org is the most recently updated cat.
  final dataList = allData;
  dataList.sort((a, b) {
    final aStr = (a['attributes'] as Map<String, dynamic>?)?['updatedDate']?.toString();
    final bStr = (b['attributes'] as Map<String, dynamic>?)?['updatedDate']?.toString();
    if (aStr == null && bStr == null) return 0;
    if (aStr == null) return 1;
    if (bStr == null) return -1;
    try {
      final aDate = DateTime.parse(aStr);
      final bDate = DateTime.parse(bStr);
      return bDate.compareTo(aDate);
    } catch (_) {
      return 0;
    }
  });

  final Map<String, Map<String, dynamic>> includedById = {};
  for (final item in allIncluded) {
    if (item is! Map<String, dynamic>) continue;
    final id = item['id']?.toString();
    if (id != null) includedById[id] = item;
  }

  final Map<String, RecentCatInfo> result = {};
  for (final item in dataList) {
    if (item is! Map<String, dynamic>) continue;
    final rels = item['relationships'] as Map<String, dynamic>?;
    final orgsData = rels?['orgs']?['data'];
    // JSON:API to-one can be single object; to-many is array.
    final Map<String, dynamic>? firstOrg;
    if (orgsData is Map<String, dynamic>) {
      firstOrg = orgsData;
    } else if (orgsData is List && orgsData.isNotEmpty && orgsData.first is Map<String, dynamic>) {
      firstOrg = orgsData.first as Map<String, dynamic>;
    } else {
      continue;
    }
    final orgId = firstOrg['id']?.toString();
    if (orgId == null || orgId.isEmpty || result.containsKey(orgId)) continue;

    DateTime? updatedDate;
    final attrs = item['attributes'] as Map<String, dynamic>?;
    final updatedStr = attrs?['updatedDate']?.toString();
    if (updatedStr != null) {
      try {
        updatedDate = DateTime.parse(updatedStr);
      } catch (_) {}
    }

    String? thumbnailUrl;
    final picturesData = rels?['pictures']?['data'];
    final Map<String, dynamic>? firstPic;
    if (picturesData is Map<String, dynamic>) {
      firstPic = picturesData;
    } else if (picturesData is List && picturesData.isNotEmpty && picturesData.first is Map<String, dynamic>) {
      firstPic = picturesData.first as Map<String, dynamic>;
    } else {
      firstPic = null;
    }
    if (firstPic != null) {
      final picId = firstPic['id']?.toString();
      if (picId != null) {
        final inc = includedById[picId];
        if (inc != null) {
          final incAttrs = inc['attributes'] as Map<String, dynamic>?;
          final small = incAttrs?['small'] as Map<String, dynamic>?;
          thumbnailUrl = small?['url']?.toString() ?? (incAttrs?['large'] as Map<String, dynamic>?)?['url']?.toString() ?? (incAttrs?['original'] as Map<String, dynamic>?)?['url']?.toString();
        }
      }
    }

    result[orgId] = RecentCatInfo(thumbnailUrl: thumbnailUrl, updatedDate: updatedDate);
  }
  if (result.isNotEmpty) {
    print('📷 Most recent cat per org: ${result.length} orgs (thumbnails and updatedDate)');
  }
  return result;
}

/// Returns the set of org IDs that have at least one available kitten (Baby age group) within [miles] of [postalcode].
Future<Set<String>> getOrgIdsWithKittens({
  required String postalcode,
  int miles = 200,
}) async {
  final apiKey = AppConfig.rescueGroupsApiKey;
  if (apiKey.isEmpty) return {};

  final zip = postalcode.trim();
  if (zip.isEmpty || zip.length < 5) return {};

  final body = {
    'data': {
      'filterRadius': {
        'postalcode': zip.length >= 5 ? zip.substring(0, 5) : zip,
        'miles': miles,
      },
      'filters': [
        {'fieldName': 'species.singular', 'operation': 'equal', 'criteria': ['cat']},
        {'fieldName': 'animals.ageGroup', 'operation': 'equal', 'criteria': ['Baby']},
      ],
    },
  };

  final response = await http.post(
    Uri.parse(_animalsSearchCountUrl(1)),
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Authorization': apiKey,
    },
    body: json.encode(body),
  );

  if (response.statusCode != 200) return {};

  final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
  final data = jsonResponse['data'];
  if (data == null || data is! List) return {};

  final Set<String> orgIds = {};
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final rels = item['relationships'] as Map<String, dynamic>?;
    final orgsData = rels?['orgs']?['data'];
    final Map<String, dynamic>? firstOrg;
    if (orgsData is Map<String, dynamic>) {
      firstOrg = orgsData;
    } else if (orgsData is List && orgsData.isNotEmpty && orgsData.first is Map<String, dynamic>) {
      firstOrg = orgsData.first as Map<String, dynamic>;
    } else {
      continue;
    }
    final orgId = firstOrg?['id']?.toString();
    if (orgId != null && orgId.isNotEmpty) orgIds.add(orgId);
  }
  return orgIds;
}

/// Returns a map of orgId -> count of available cats within [miles] of [postalcode].
/// Used to filter shelter list to only orgs that have at least one cat and to show cat counts.
Future<Map<String, int>> getAvailableCatsCountByOrg({
  required String postalcode,
  int miles = 200,
}) async {
  final apiKey = AppConfig.rescueGroupsApiKey;
  if (apiKey.isEmpty) return {};

  final zip = postalcode.trim();
  if (zip.isEmpty || zip.length < 5) return {};

  final body = {
    'data': {
      'filterRadius': {
        'postalcode': zip.length >= 5 ? zip.substring(0, 5) : zip,
        'miles': miles,
      },
      'filters': [
        {'fieldName': 'species.singular', 'operation': 'equal', 'criteria': ['cat']},
      ],
    },
  };

  final Map<String, int> counts = {};
  for (int page = 1; page <= 2; page++) {
    final response = await http.post(
      Uri.parse(_animalsSearchCountUrl(page)),
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Authorization': apiKey,
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) break;

    final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
    final data = jsonResponse['data'];
    if (data == null || data is! List) break;

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final rels = item['relationships'] as Map<String, dynamic>?;
      final orgsData = rels?['orgs']?['data'];
      final Map<String, dynamic>? firstOrg;
      if (orgsData is Map<String, dynamic>) {
        firstOrg = orgsData;
      } else if (orgsData is List && orgsData.isNotEmpty && orgsData.first is Map<String, dynamic>) {
        firstOrg = orgsData.first as Map<String, dynamic>;
      } else {
        continue;
      }
      final orgId = firstOrg['id']?.toString();
      if (orgId != null && orgId.isNotEmpty) {
        counts[orgId] = (counts[orgId] ?? 0) + 1;
      }
    }
  }
  return counts;
}

/// Lightweight shelter model for this screen (orgId, name).
class ShelterResult {
  final String orgId;
  final String name;

  ShelterResult({required this.orgId, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShelterResult && orgId == other.orgId && name == other.name;

  @override
  int get hashCode => Object.hash(orgId, name);
}

/// Calls RescueGroups organizations search with a "contains" filter on org name.
Future<List<ShelterResult>> searchOrganizationsByName(String query) async {
  if (query.trim().isEmpty) return [];

  final apiKey = AppConfig.rescueGroupsApiKey;
  if (apiKey.isEmpty) {
    throw Exception('RescueGroups API key not configured');
  }

  // Same structure as animals search: filters at data.filters (not data.attributes.filters).
  // See RescueGroups docs: filter pointer is /data/filters/... so filters live under data.
  final body = {
    'data': {
      'filters': [
        {
          'fieldName': 'orgs.name',
          'operation': 'contains',
          'criteria': query.trim(),
        },
      ],
      'filterProcessing': '1',
    },
  };

  // Log query (request) for shelter search
  print('🔍 Shelter search request:');
  print('   URL: $_kRescueGroupsOrgsSearchUrl');
  print('   Body: ${json.encode(body)}');

  final response = await http.post(
    Uri.parse(_kRescueGroupsOrgsSearchUrl),
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Authorization': apiKey,
    },
    body: json.encode(body),
  );

  // Log response for shelter search
  print('📥 Shelter search response: status=${response.statusCode}');
  print('   Body: ${response.body}');

  if (response.statusCode != 200) {
    throw Exception('Search failed: ${response.statusCode} ${response.body}');
  }

  final jsonResponse = json.decode(response.body);
  final data = jsonResponse['data'];
  if (data == null || data is! List) return [];

  final List<ShelterResult> shelters = [];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final attrs = item['attributes'];
    final id = item['id']?.toString() ??
        (attrs is Map ? attrs['orgId']?.toString() : null);
    final name =
        attrs is Map ? (attrs['name']?.toString() ?? '') : '';
    if (id != null && id.isNotEmpty) {
      shelters.add(ShelterResult(orgId: id, name: name));
    }
  }
  return shelters;
}

class SelectSheltersScreen extends StatefulWidget {
  /// Previously selected org IDs (shown as selected when screen opens).
  final List<String> initialSelectedOrgIds;
  /// Names for each initial selected org (same order as [initialSelectedOrgIds]; empty string if unknown).
  final List<String> initialSelectedNames;

  const SelectSheltersScreen({
    Key? key,
    this.initialSelectedOrgIds = const [],
    this.initialSelectedNames = const [],
  }) : super(key: key);

  @override
  State<SelectSheltersScreen> createState() => _SelectSheltersScreenState();
}

class _SelectSheltersScreenState extends State<SelectSheltersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ShelterResult> _results = [];
  List<ShelterResult> _selected = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedOrgIds.isNotEmpty) {
      _selected = List.generate(
        widget.initialSelectedOrgIds.length,
        (i) => ShelterResult(
          orgId: widget.initialSelectedOrgIds[i],
          name: i < widget.initialSelectedNames.length
              ? widget.initialSelectedNames[i]
              : '',
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a search term';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final list = await searchOrganizationsByName(query);
      final selectedIds = _selected.map((s) => s.orgId).toSet();
      final excludedSelected =
          list.where((s) => !selectedIds.contains(s.orgId)).toList();
      excludedSelected.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _results = excludedSelected;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _addToSelected(ShelterResult shelter) {
    if (_selected.any((s) => s.orgId == shelter.orgId)) return;
    setState(() {
      _selected = [..._selected, shelter];
      _results = _results.where((s) => s.orgId != shelter.orgId).toList();
    });
  }

  void _removeFromSelected(ShelterResult shelter) {
    setState(() {
      _selected = _selected.where((s) => s.orgId != shelter.orgId).toList();
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        final inResults = _results.any((s) => s.orgId == shelter.orgId);
        if (!inResults) {
          _results = [..._results, shelter];
          _results.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }
      }
    });
  }

  void _onDone() {
    final first = _selected.isEmpty ? null : _selected.first.name;
    final ids = _selected.map((s) => s.orgId).toList();
    final names = _selected.map((s) => s.name).toList();
    Navigator.of(context).pop(<String, dynamic>{
      'firstShelterName': first ?? '',
      'selectedOrgIds': ids,
      'selectedShelterNames': names,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: SearchScreenStyle.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Select Shelters',
            style: TextStyle(
              color: SearchScreenStyle.gold,
              fontWeight: FontWeight.w600,
              fontSize: AppTheme.fontSizeXXL,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: SearchScreenStyle.gold),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search shelters',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: SearchScreenStyle.fieldBackground,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: SearchScreenStyle.gold, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: SearchScreenStyle.gold, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: SearchScreenStyle.gold, width: 2),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: SearchScreenStyle.gold,
                        ),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _onSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SearchScreenStyle.purpleSurface,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: SearchScreenStyle.gold,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      elevation: 0,
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: SearchScreenStyle.gold.withOpacity(0.9),
                    fontSize: AppTheme.fontSizeM,
                  ),
                ),
              ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Center(
                  child: CircularProgressIndicator(
                    color: SearchScreenStyle.gold,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top half: Shelter Results (scrolls in its own area)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingM),
                          child: const Text(
                            'Shelter Results',
                            style: TextStyle(
                              color: SearchScreenStyle.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: AppTheme.fontSizeL,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Scrollbar(
                            thumbVisibility: true,
                            radius: const Radius.circular(4),
                            thickness: 6,
                            child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingM),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: SearchScreenStyle.gold.withOpacity(0.35),
                            ),
                            itemBuilder: (context, i) {
                              final s = _results[i];
                              return InkWell(
                                onTap: () => _addToSelected(s),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: AppTheme.fontSizeM,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: SearchScreenStyle.gold,
                                        ),
                                        onPressed: () => _addToSelected(s),
                                      ),
                                    ],
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
                  // Divider between the two halves
                  Divider(
                    height: 2,
                    thickness: 1,
                    color: SearchScreenStyle.gold.withOpacity(0.5),
                  ),
                  // Bottom half: Selected Shelters (scrolls in its own area)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingM),
                          child: const Text(
                            'Selected Shelters',
                            style: TextStyle(
                              color: SearchScreenStyle.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: AppTheme.fontSizeL,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Scrollbar(
                            thumbVisibility: true,
                            radius: const Radius.circular(4),
                            thickness: 6,
                            child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingM),
                            itemCount: _selected.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: SearchScreenStyle.gold.withOpacity(0.35),
                            ),
                            itemBuilder: (context, i) {
                              final s = _selected[i];
                              return InkWell(
                                onTap: () => _removeFromSelected(s),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: AppTheme.fontSizeM,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: SearchScreenStyle.gold,
                                        ),
                                        onPressed: () =>
                                            _removeFromSelected(s),
                                      ),
                                    ],
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
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: SearchScreenStyle.deepPurple.withOpacity(0.95),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onDone,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: SearchScreenStyle.purpleSurface,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: SearchScreenStyle.gold,
                        width: 1.5,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Use These'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
