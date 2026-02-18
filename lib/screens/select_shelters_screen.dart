import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../theme.dart';
import 'search_screen_style.dart';

/// RescueGroups v5 organizations search endpoint.
const String _kRescueGroupsOrgsSearchUrl =
    'https://api.rescuegroups.org/v5/public/orgs/search/rescue/?fields[orgs]=name,orgId';

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
