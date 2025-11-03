import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catapp/models/searchPageConfig.dart';
import 'package:catapp/ExampleCode/RescueGroupsQuery.dart';
import 'package:catapp/screens/globals.dart';
import 'package:catapp/models/breed.dart';
import 'package:catapp/screens/breedSelection.dart';
import 'package:catapp/services/search_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  final Map<CatClassification, List<filterOption>> categories;
  final List<filterOption> filteringOptions;
  final String userID;

  const SearchScreen({
    Key? key,
    required this.categories,
    required this.filteringOptions,
    required this.userID,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  late TextEditingController controller2;
  late TextEditingController _zipCodeController;
  late ScrollController _scrollController;
  late FocusNode _zipCodeFocusNode;

  // Track which filters are currently being animated
  final Map<String, bool> _animatingFilters = {};
  // Keys for each filter row to enable scrolling to them
  final Map<String, GlobalKey> _filterKeys = {};
  // Keys for each filter category (ExpansionTile) to enable scrolling
  final Map<CatClassification, GlobalKey> _categoryKeys = {};
  // Track which categories are expanded
  final Map<CatClassification, bool> _expandedCategories = {};
  // Track which specific option values are being highlighted
  final Map<String, dynamic> _highlightedOptions = {}; // Key: "fieldName:value"
  // Track ZIP code validation state
  bool _zipCodeValidated = false;
  bool? _zipCodeIsValid;

  @override
  void initState() {
    super.initState();
    controller2 = TextEditingController();
    _zipCodeController = TextEditingController();
    _zipCodeFocusNode = FocusNode();
    _scrollController = ScrollController();

    // Listen to focus changes for ZIP code validation
    _zipCodeFocusNode.addListener(_onZipCodeFocusChange);

    // Load saved zip code if available
    _loadZipCode();

    // Initialize filter values to prevent type errors
    _initializeFilterValues();

    // Load saved search state after initialization
    _loadSearchState();

    // Initialize keys for all filters and categories
    for (var filter in widget.filteringOptions) {
      _filterKeys[filter.fieldName] = GlobalKey();
    }

    // Initialize keys and expansion state for all categories
    for (var classification in CatClassification.values) {
      _categoryKeys[classification] = GlobalKey();
      _expandedCategories[classification] = false; // Start collapsed
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controller2.dispose();
    _zipCodeController.dispose();
    _zipCodeFocusNode.removeListener(_onZipCodeFocusChange);
    _zipCodeFocusNode.dispose();
    super.dispose();
  }

  /// Handle ZIP code validation when field loses focus
  Future<void> _onZipCodeFocusChange() async {
    // Only validate when losing focus (not gaining focus)
    if (!_zipCodeFocusNode.hasFocus) {
      final zip = _zipCodeController.text.trim();

      // Reset validation state if field is empty
      if (zip.isEmpty) {
        setState(() {
          _zipCodeValidated = false;
          _zipCodeIsValid = null;
        });
        return;
      }

      // Show error icon if ZIP is less than 5 digits
      if (zip.length < 5) {
        setState(() {
          _zipCodeValidated = true;
          _zipCodeIsValid = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('ZIP code must be 5 digits.'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // If not exactly 5 digits, skip validation (shouldn't happen due to maxLength, but handle gracefully)
      if (zip.length != 5) {
        setState(() {
          _zipCodeValidated = false;
          _zipCodeIsValid = null;
        });
        return;
      }

      final server = FelineFinderServer.instance;

      try {
        final isValid = await server.isZipCodeValid(zip);

        setState(() {
          _zipCodeValidated = true;
          _zipCodeIsValid = isValid;
        });

        if (isValid == true) {
          // Save to server and preferences
          server.zip = zip;

          // Find and update the filter
          final zipFilter = widget.filteringOptions.firstWhere(
            (f) => f.fieldName == 'zipCode',
            orElse: () => widget.filteringOptions.first,
          );
          if (zipFilter.fieldName == 'zipCode') {
            zipFilter.choosenValue = zip;
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('zipCode', zip);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('ZIP code saved: $zip'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Show error message for invalid ZIP
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Invalid ZIP code. Please enter a valid US ZIP code.'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('ZIP validation error: $e');
        setState(() {
          _zipCodeValidated = true;
          _zipCodeIsValid = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Error validating ZIP code. Please try again.'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // When gaining focus, reset validation state
      setState(() {
        _zipCodeValidated = false;
        _zipCodeIsValid = null;
      });
    }
  }

  /// Load saved zip code from SharedPreferences and server
  Future<void> _loadZipCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedZip = prefs.getString('zipCode');
      final serverZip = FelineFinderServer.instance.zip;

      // Use saved zip if available, otherwise use server zip
      final zipCode = savedZip ?? (serverZip != "?" ? serverZip : "");

      if (zipCode.isNotEmpty) {
        _zipCodeController.text = zipCode;
        // Also update the filter's choosenValue if it exists
        final zipFilter = widget.filteringOptions.firstWhere(
          (f) => f.fieldName == 'zipCode',
          orElse: () => widget.filteringOptions.first,
        );
        if (zipFilter.fieldName == 'zipCode') {
          zipFilter.choosenValue = zipCode;
        }
      }
    } catch (e) {
      print('Error loading zip code: $e');
    }
  }

  /// Load saved search state (AI query and filter values)
  Future<void> _loadSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load AI search query
      final savedQuery = prefs.getString('lastSearchQuery');
      if (savedQuery != null && savedQuery.isNotEmpty) {
        controller2.text = savedQuery;
      }

      // Load filter values
      final savedFiltersJson = prefs.getString('lastSearchFilters');
      if (savedFiltersJson != null && savedFiltersJson.isNotEmpty) {
        final Map<String, dynamic> savedFilters = jsonDecode(savedFiltersJson);

        for (var filter in widget.filteringOptions) {
          // Skip saved searches category
          if (filter.classification == CatClassification.saves) {
            continue;
          }

          final fieldName = filter.fieldName;

          if (filter.list) {
            // Load list filter values
            if (savedFilters.containsKey('$fieldName:list')) {
              final List<dynamic> savedValues = savedFilters['$fieldName:list'];
              filter.choosenListValues =
                  savedValues.map((v) => v as int).toList();
            }
          } else {
            // Load single value
            if (savedFilters.containsKey(fieldName)) {
              final savedValue = savedFilters[fieldName];
              // Handle different types (String, bool, int)
              if (savedValue is String) {
                filter.choosenValue = savedValue;
                // Also update ZIP code controller if this is the zipCode filter
                if (fieldName == 'zipCode' && savedValue.isNotEmpty) {
                  _zipCodeController.text = savedValue;
                }
              } else if (savedValue is bool) {
                filter.choosenValue = savedValue;
              } else if (savedValue is int) {
                filter.choosenValue = savedValue;
              } else {
                filter.choosenValue = savedValue.toString();
                // Also update ZIP code controller if this is the zipCode filter
                if (fieldName == 'zipCode' &&
                    savedValue.toString().isNotEmpty) {
                  _zipCodeController.text = savedValue.toString();
                }
              }
            }
          }
        }

        // Update UI to reflect loaded state
        setState(() {});
      }
    } catch (e) {
      print('Error loading search state: $e');
    }
  }

  /// Save current search state (AI query and filter values)
  Future<void> _saveSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save AI search query
      final query = controller2.text.trim();
      await prefs.setString('lastSearchQuery', query);

      // Save filter values
      final Map<String, dynamic> filtersToSave = {};

      for (var filter in widget.filteringOptions) {
        // Skip saved searches category
        if (filter.classification == CatClassification.saves) {
          continue;
        }

        final fieldName = filter.fieldName;

        if (filter.list) {
          // Save list filter values
          if (filter.choosenListValues.isNotEmpty) {
            filtersToSave['$fieldName:list'] = filter.choosenListValues;
          }
        } else {
          // Save single value (skip if null, empty, or "Any")
          if (filter.choosenValue != null &&
              filter.choosenValue != "" &&
              filter.choosenValue != "Any" &&
              filter.choosenValue != "Any Type") {
            // Convert to appropriate type for JSON
            if (filter.choosenValue is bool) {
              filtersToSave[fieldName] = filter.choosenValue;
            } else if (filter.choosenValue is int) {
              filtersToSave[fieldName] = filter.choosenValue;
            } else {
              filtersToSave[fieldName] = filter.choosenValue.toString();
            }
          }
        }
      }

      // Save as JSON string
      final filtersJson = jsonEncode(filtersToSave);
      await prefs.setString('lastSearchFilters', filtersJson);

      print(
          '✅ Saved search state: query="$query", filters=${filtersToSave.length}');
    } catch (e) {
      print('Error saving search state: $e');
    }
  }

  void _initializeFilterValues() {
    print('Initializing ${widget.filteringOptions.length} filter options');
    for (var filter in widget.filteringOptions) {
      print(
          'Processing filter: ${filter.name}, choosenValue: ${filter.choosenValue}, options: ${filter.options.length}');

      if (filter.list) {
        // For list filters (chip options), initialize with "Any" option selected
        if (filter.choosenListValues.isEmpty) {
          // Find the "Any" option (always the last option)
          var anyOption = filter.options.last;
          filter.choosenListValues = [anyOption.value];
          print('Set ${filter.name} list to Any option: ${anyOption.value}');
        }
      } else {
        // For single-select filters (skip zipCode as it's a text input)
        if (filter.fieldName == 'zipCode') {
          // Zip code is handled separately, don't set default "Any" value
          print('Skipping zipCode initialization (text input field)');
        } else if (filter.choosenValue == null || filter.choosenValue == "") {
          // Find the "Any" option and set it as default
          if (filter.options.isNotEmpty) {
            var anyOption = filter.options.firstWhere(
              (option) => option.search == "Any" || option.search == "Any Type",
              orElse: () => filter.options.first,
            );
            filter.choosenValue = anyOption.search;
            print('Set ${filter.name} to Any option: ${filter.choosenValue}');
          }
        } else {
          // Ensure choosenValue is compatible with the options
          if (filter.options.isNotEmpty) {
            var matchingOption = filter.options.firstWhere(
              (option) => option.search == filter.choosenValue,
              orElse: () => filter.options.firstWhere(
                (option) =>
                    option.search == "Any" || option.search == "Any Type",
                orElse: () => filter.options.first,
              ),
            );
            filter.choosenValue = matchingOption.search;
          }
        }
      }
    }
  }

  Widget _buildQuickSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Color(0xFF2196F3), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller2,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.search,
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => _performQuickSearchDirect(),
                  decoration: InputDecoration(
                    hintText: "What Do You Want In A Cat",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Color(0xFF2196F3).withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _performQuickSearch(),
                  icon: Icon(Icons.search, color: Colors.white),
                  label: Text("Show Me", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _clearAllFilters(),
                  icon: Icon(Icons.clear, color: Color(0xFF2196F3)),
                  label:
                      Text("Clear", style: TextStyle(color: Color(0xFF2196F3))),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Color(0xFF2196F3)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCategory(
      String title, IconData icon, CatClassification classification) {
    List<filterOption> filters = widget.categories[classification] ?? [];
    final isExpanded = _expandedCategories[classification] ?? false;

    // Find the "Sort By" filter to check its value (needed for both filtering and key)
    final sortByFilter = widget.filteringOptions.firstWhere(
      (f) => f.fieldName == 'sortBy',
      orElse: () => widget.filteringOptions.first,
    );

    // Show all sort category filters regardless of "Sort By" selection

    return Container(
      key: _categoryKeys[classification],
      margin: EdgeInsets.only(bottom: 16),
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
      child: ExpansionTile(
        key: ValueKey(
            '$classification-${isExpanded ? 'expanded' : 'collapsed'}-${classification == CatClassification.sort ? sortByFilter.choosenValue : ''}'),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedCategories[classification] = expanded;
          });
        },
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF2196F3), size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
            fontFamily: 'Poppins',
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: filters
                  .map((filter) => _buildFilterRow(filter, classification))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
      filterOption filter, CatClassification classification) {
    final isAnimating = _isFilterAnimating(filter);
    final filterKey = _filterKeys[filter.fieldName];

    return Container(
      key: filterKey,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAnimating
              ? Color(0xFF2196F3).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAnimating ? Color(0xFF2196F3) : Colors.grey[200]!,
            width: isAnimating ? 2 : 1,
          ),
          boxShadow: isAnimating
              ? [
                  BoxShadow(
                    color: Color(0xFF2196F3).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    filter.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isAnimating ? Color(0xFF2196F3) : Colors.grey[800],
                    ),
                  ),
                ),
                if (isAnimating)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (value * 0.2),
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFF2196F3),
                          size: 24,
                        ),
                      );
                    },
                  ),
              ],
            ),
            SizedBox(height: 8),
            if (filter.fieldName == "zipCode")
              _buildZipCodeInput(filter)
            else if (filter.classification == CatClassification.breed)
              _buildBreedSelector(filter)
            else if (filter.list)
              _buildChipSelector(filter)
            else
              _buildDropdownSelector(filter),
          ],
        ),
      ),
    );
  }

  Widget _buildZipCodeInput(filterOption filter) {
    final server = FelineFinderServer.instance;

    // Get current value from controller or filter
    final currentZip = _zipCodeController.text.isNotEmpty
        ? _zipCodeController.text
        : (filter.choosenValue?.toString() ??
            (server.zip != "?" && server.zip.isNotEmpty ? server.zip : ""));

    if (currentZip.isNotEmpty && _zipCodeController.text.isEmpty) {
      _zipCodeController.text = currentZip;
    }

    // Determine which icon to show based on validation state
    Widget? suffixIcon;
    if (_zipCodeValidated) {
      final zipLength = _zipCodeController.text.length;
      if (_zipCodeIsValid == true && zipLength == 5) {
        // Show green check mark for valid ZIP
        suffixIcon = Icon(Icons.check_circle, color: Colors.green, size: 24);
      } else if (_zipCodeIsValid == false) {
        // Show red error circle for invalid ZIP (either invalid format or invalid code)
        suffixIcon = Icon(Icons.cancel, color: Colors.red, size: 24);
      }
    }

    return TextField(
      controller: _zipCodeController,
      focusNode: _zipCodeFocusNode,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: "Enter ZIP code",
        prefixIcon: Icon(Icons.location_on, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _zipCodeValidated && _zipCodeIsValid == false
                ? Colors.red
                : Color(0xFF2196F3).withOpacity(0.3),
            width: _zipCodeValidated && _zipCodeIsValid == false ? 2 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _zipCodeValidated && _zipCodeIsValid == false
                ? Colors.red
                : Color(0xFF2196F3).withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _zipCodeValidated && _zipCodeIsValid == false
                ? Colors.red
                : Color(0xFF2196F3),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLength: 5,
      onChanged: (value) {
        // Update filter value as user types
        filter.choosenValue = value.trim();
        // Reset validation state when user starts typing again
        if (_zipCodeValidated) {
          setState(() {
            _zipCodeValidated = false;
            _zipCodeIsValid = null;
          });
        }
      },
      onEditingComplete: () {
        // Move focus away to trigger validation on blur
        _zipCodeFocusNode.unfocus();
      },
    );
  }

  Widget _buildBreedSelector(filterOption filter) {
    // Get selected breed names for display
    String selectedBreedsText = "Any breed";
    if (filter.choosenListValues.isNotEmpty &&
        !filter.choosenListValues.contains(0)) {
      List<String> selectedNames = [];
      for (var breedRid in filter.choosenListValues) {
        // Find breed by rid (BreedSelectionScreen uses rid)
        try {
          final breed = breeds.firstWhere((b) => b.rid == breedRid);
          selectedNames.add(breed.name);
        } catch (e) {
          print('⚠️ Breed with RID $breedRid not found');
        }
      }
      if (selectedNames.isNotEmpty) {
        selectedBreedsText = selectedNames.length == 1
            ? selectedNames.first
            : "${selectedNames.length} breeds selected";
      }
    }

    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          var result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BreedSelectionScreen(
                selectedBreeds: filter.choosenListValues,
              ),
            ),
          );
          if (result != null) {
            setState(() {
              filter.choosenListValues = result;
            });
          }
        },
        icon: Icon(Icons.pets, color: Colors.white),
        label: Text(
          selectedBreedsText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF2196F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildChipSelector(filterOption filter) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filter.options.map((option) {
        bool isSelected = filter.choosenListValues.contains(option.value);
        bool isAnyOption =
            option.search == "Any" || option.search == "Any Type";
        // Check if this specific option is being highlighted
        final highlightKey = '${filter.fieldName}:${option.value}';
        final isHighlighted = _highlightedOptions.containsKey(highlightKey);

        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: FilterChip(
            label: Text(option.displayName),
            selected: isSelected || isHighlighted,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  if (isAnyOption) {
                    // If "Any" is selected, clear all other selections and only select "Any"
                    filter.choosenListValues = [option.value];
                  } else {
                    // If any other option is selected, remove "Any" and add this option
                    var anyOption = filter.options.firstWhere(
                      (opt) => opt.search == "Any" || opt.search == "Any Type",
                      orElse: () => filter.options.last,
                    );
                    filter.choosenListValues.remove(anyOption.value);
                    filter.choosenListValues.add(option.value);
                  }
                } else {
                  // If deselecting, just remove the option
                  filter.choosenListValues.remove(option.value);

                  // If no options are selected, select "Any"
                  if (filter.choosenListValues.isEmpty) {
                    var anyOption = filter.options.firstWhere(
                      (opt) => opt.search == "Any" || opt.search == "Any Type",
                      orElse: () => filter.options.last,
                    );
                    filter.choosenListValues = [anyOption.value];
                  }
                }
              });
            },
            selectedColor: (isSelected || isHighlighted)
                ? Color(0xFF2196F3).withOpacity(isHighlighted ? 0.5 : 0.2)
                : Color(0xFF2196F3).withOpacity(0.2),
            checkmarkColor: Color(0xFF2196F3),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: (isSelected || isHighlighted)
                  ? Color(0xFF2196F3)
                  : Colors.grey[300]!,
              width:
                  (isSelected || isHighlighted) ? (isHighlighted ? 3 : 2) : 1,
            ),
            avatar: isHighlighted
                ? Icon(Icons.check_circle, color: Color(0xFF2196F3), size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownSelector(filterOption filter) {
    try {
      // Handle different value types (String, bool, int)
      dynamic currentValue = filter.choosenValue;

      // Convert current value to string for comparison
      String? currentValueStr;
      if (currentValue == null) {
        currentValueStr = null;
      } else if (currentValue is bool) {
        currentValueStr = currentValue.toString();
      } else {
        currentValueStr = currentValue.toString();
      }

      if (currentValueStr == null || currentValueStr.isEmpty) {
        // Set to first option if no value is selected
        if (filter.options.isNotEmpty) {
          currentValueStr = filter.options.first.search.toString();
          currentValue = filter.options.first.search;
        }
      }

      // Verify the current value exists in options
      bool valueExists = filter.options
          .any((option) => option.search.toString() == currentValueStr);
      if (!valueExists && filter.options.isNotEmpty) {
        currentValueStr = filter.options.first.search.toString();
        currentValue = filter.options.first.search;
      }

      // Check if the current value is being highlighted
      final highlightKey = '${filter.fieldName}:${currentValue}';
      final isHighlighted = _highlightedOptions.containsKey(highlightKey) ||
          (currentValueStr != null &&
              _highlightedOptions
                  .containsKey('${filter.fieldName}:$currentValueStr'));

      return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isHighlighted
                ? Color(0xFF2196F3)
                : Color(0xFF2196F3).withOpacity(0.3),
            width: isHighlighted ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: Color(0xFF2196F3).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentValueStr,
            isExpanded: true,
            items: filter.options.map((option) {
              final optionHighlightKey = '${filter.fieldName}:${option.value}';
              final isOptionHighlighted =
                  _highlightedOptions.containsKey(optionHighlightKey);

              return DropdownMenuItem<String>(
                value: option.search.toString(),
                child: Row(
                  children: [
                    if (isOptionHighlighted)
                      Icon(Icons.check_circle,
                          color: Color(0xFF2196F3), size: 18),
                    if (isOptionHighlighted) SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.displayName,
                        style: TextStyle(
                          color: isOptionHighlighted ? Color(0xFF2196F3) : null,
                          fontWeight: isOptionHighlighted
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                // Convert back to original type if needed
                if (filter.options.isNotEmpty) {
                  var originalOption = filter.options.firstWhere(
                    (option) => option.search.toString() == newValue,
                    orElse: () => filter.options.first,
                  );
                  filter.choosenValue = originalOption.search;
                } else {
                  filter.choosenValue = newValue;
                }

                // If this is the "Sort By" filter, trigger rebuild of sort category
                if (filter.fieldName == 'sortBy') {
                  // Force rebuild by updating state - the filter category will rebuild
                  // and show/hide conditional filters based on new selection
                }
              });
            },
          ),
        ),
      );
    } catch (e) {
      print('Error building dropdown for filter ${filter.name}: $e');
      // Return a simple text widget as fallback
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Error loading ${filter.name}',
            style: TextStyle(color: Colors.red)),
      );
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => saveSearch(),
              icon: Icon(Icons.bookmark_outline, color: Color(0xFF2196F3)),
              label: Text("Save Search",
                  style: TextStyle(color: Color(0xFF2196F3))),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Color(0xFF2196F3)),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  print("=== FIND CATS BUTTON PRESSED ===");
                  // Save search state before navigating
                  await _saveSearchState();
                  var filters = generateFilters();
                  print("Generated ${filters.length} filters");
                  Navigator.pop(context, filters);
                } catch (e) {
                  print("Error in Find Cats button: $e");
                  Navigator.pop(context, []);
                }
              },
              icon: Icon(Icons.search, color: Colors.white),
              label: Text("Find Cats",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2196F3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performQuickSearch() async {
    final query = controller2.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a search query'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing your search...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Parse query with AI
      final filterData = await SearchAIService().parseSearchQuery(query);

      // DEBUG: Check what AI returned
      print('🔍 AI Response received:');
      print('🔍 Full response: $filterData');
      print('🔍 Has filters key: ${filterData.containsKey('filters')}');
      print('🔍 Has location key: ${filterData.containsKey('location')}');
      if (filterData.containsKey('filters')) {
        print('🔍 Filters data: ${filterData['filters']}');
        print(
            '🔍 Filters count: ${(filterData['filters'] as Map?)?.length ?? 0}');
      }
      if (filterData.containsKey('location')) {
        print('🔍 Location data: ${filterData['location']}');
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Apply filters with animation
      await _applyAIFilters(filterData, animate: true);
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      _showError('Failed to process search: ${e.toString()}');
    }
  }

  /// Perform quick search and navigate directly to results (no animation)
  Future<void> _performQuickSearchDirect() async {
    final query = controller2.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a search query'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing your search...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Parse query with AI
      final filterData = await SearchAIService().parseSearchQuery(query);

      // Close loading dialog
      Navigator.of(context).pop();

      // Apply filters without animation and navigate directly
      await _applyAIFilters(filterData, animate: false, navigateDirect: true);
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      _showError('Failed to process search: ${e.toString()}');
    }
  }

  void _clearAllFilters() {
    // Reset all filters to their default "Any" values
    for (var filter in widget.filteringOptions) {
      // Skip saved searches category
      if (filter.classification == CatClassification.saves) {
        continue;
      }

      // Special handling for zipCode (text input field)
      if (filter.fieldName == 'zipCode') {
        filter.choosenValue = "";
        _zipCodeController.clear();
        _zipCodeValidated = false;
        _zipCodeIsValid = null;
        continue;
      }

      // Special handling for breed filters (use value 0 for "Any")
      if (filter.list && filter.classification == CatClassification.breed) {
        filter.choosenListValues = [0]; // 0 is the "Any" value for breeds
        continue;
      }

      // Handle other list filters
      if (filter.list) {
        // Find and select "Any" option
        var anyOption = filter.options.firstWhere(
          (opt) => opt.search == "Any" || opt.search == "Any Type",
          orElse: () => filter.options.isNotEmpty
              ? filter.options.last
              : filter.options.first,
        );
        filter.choosenListValues = [anyOption.value];
      } else {
        // For single-select filters, find and select "Any" option
        if (filter.options.isNotEmpty) {
          var anyOption = filter.options.firstWhere(
            (opt) => opt.search == "Any" || opt.search == "Any Type",
            orElse: () => filter.options.first,
          );
          filter.choosenValue = anyOption.search;
        } else {
          // If no options, set to empty
          filter.choosenValue = "";
        }
      }
    }

    // Clear the AI search text field
    controller2.clear();

    // Update UI
    setState(() {});

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('All filters cleared'),
          ],
        ),
        backgroundColor: Color(0xFF2196F3),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Add method to apply filters from AI response
  Future<void> _applyAIFilters(
    Map<String, dynamic> filterData, {
    bool animate = true,
    bool navigateDirect = false,
  }) async {
    print(
        '🎯 _applyAIFilters called with: $filterData, animate: $animate, navigateDirect: $navigateDirect');

    // Edge case: Null or empty response
    if (filterData.isEmpty ||
        (!filterData.containsKey('filters') &&
            !filterData.containsKey('location'))) {
      print('❌ Filter data is empty or missing keys');
      _showError(
          'No filters could be parsed from your search. Please try rephrasing.');
      return;
    }

    final location = filterData['location'] as Map<String, dynamic>?;
    final filters = filterData['filters'] as Map<String, dynamic>?;

    print('🎯 Location: $location');
    print('🎯 Filters: $filters');
    print('🎯 Filters is empty: ${filters?.isEmpty ?? true}');
    print('🎯 Location is empty: ${location?.isEmpty ?? true}');

    if ((filters == null || filters.isEmpty) &&
        (location == null || location.isEmpty)) {
      print('❌ Both filters and location are empty/null');
      _showError(
          'Could not understand your search. Please try being more specific.');
      return;
    }

    List<filterOption> filtersToUpdate = [];
    List<String> appliedFilters = []; // Track what was applied
    List<String> failedFilters = []; // Track what failed

    // Handle location with error handling
    if (location != null && location.isNotEmpty) {
      try {
        if (location.containsKey('distance')) {
          final distanceFilter = widget.filteringOptions.firstWhere(
            (f) => f.fieldName == 'distance',
            orElse: () => widget.filteringOptions.first,
          );

          // Edge case: Filter not found
          if (distanceFilter.fieldName == 'distance') {
            final distanceValue = location['distance'].toString();

            // Edge case: Try to find closest matching distance option
            listOption? matchingOption = _findClosestOption(
              distanceFilter.options,
              distanceValue,
              isNumeric: true,
            );

            if (matchingOption != null) {
              filtersToUpdate.add(distanceFilter);
              distanceFilter.choosenValue = matchingOption.search;
              appliedFilters.add('Distance: ${matchingOption.displayName}');
            } else {
              failedFilters.add('Distance ($distanceValue)');
            }
          }
        }

        // Handle ZIP code using the new zipCode filter
        if (location.containsKey('zip')) {
          final zip = location['zip'].toString().trim();
          if (zip.isNotEmpty && _isValidZipCodeFormat(zip)) {
            final zipFilter = widget.filteringOptions.firstWhere(
              (f) => f.fieldName == 'zipCode',
              orElse: () => widget.filteringOptions.first,
            );

            if (zipFilter.fieldName == 'zipCode') {
              // Validate and save zip code
              try {
                final isValid =
                    await FelineFinderServer.instance.isZipCodeValid(zip);
                if (isValid == true) {
                  zipFilter.choosenValue = zip;
                  _zipCodeController.text = zip;
                  FelineFinderServer.instance.zip = zip;

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('zipCode', zip);

                  filtersToUpdate.add(zipFilter);
                  appliedFilters.add('ZIP Code: $zip');
                  print('✅ ZIP code applied: $zip');
                } else {
                  failedFilters.add('ZIP Code ($zip - invalid)');
                  print('❌ Invalid ZIP code: $zip');
                }
              } catch (e) {
                print('Error validating ZIP code: $e');
                failedFilters.add('ZIP Code ($zip)');
              }
            }
          } else {
            print('⚠️ Invalid ZIP code format: $zip');
            failedFilters.add('ZIP Code (invalid format)');
          }
        }
      } catch (e) {
        print('Error applying location filters: $e');
        failedFilters.add('Location');
      }
    }

    // Field name mapping with validation
    final fieldNameMapping = {
      'breed': 'animals.breedPrimaryId',
      'sizeGroup': 'animals.sizeGroup',
      'ageGroup': 'animals.ageGroup',
      'sex': 'animals.sex',
      'coatLength': 'animals.coatLength',
      'affectionate': 'animals.affectionate',
      'playful': 'animals.playful',
      'energyLevel': 'animals.energyLevel',
      'activityLevel': 'animals.activityLevel',
      'exerciseNeeds': 'animals.exerciseNeeds',
      'vocalLevel': 'animals.vocalLevel',
      'newPeopleReaction': 'animals.newPeopleReaction',
      'isHousetrained': 'animals.isHousetrained',
      'isDogsOk': 'animals.isDogsOk',
      'isCatsOk': 'animals.isCatsOk',
      'isKidsOk': 'animals.isKidsOk',
      'ownerExperience': 'animals.ownerExperience',
      'indoorOutdoor': 'animals.indoorOutdoor',
      'colorDetails': 'animals.colorDetails',
      'eyeColor': 'animals.eyeColor',
      'tailType': 'animals.tailType',
      'groomingNeeds': 'animals.groomingNeeds',
      'sheddingLevel': 'animals.sheddingLevel',
      'obedienceTraining': 'animals.obedienceTraining',
      'earType': 'animals.earType',
      'hypoallergenic': 'animals.hypoallergenic',
      'hasAllergies': 'animals.hasAllergies',
      'hearingImpaired': 'animals.hearingImpaired',
      'ongoingMedical': 'animals.ongoingMedical',
      'specialDiet': 'animals.specialDiet',
      'isAltered': 'animals.altered',
      'isDeclawed': 'animals.declawed',
      'isMicrochipped': 'animals.isMicrochipped',
      'isBreedMixed': 'animals.breedMixed',
      'isSpecialNeeds': 'animals.isSpecialNeeds',
      'isCurrentVaccinations': 'animals.isCurrentVaccinations',
      'updatedDate': 'animals.updatedDate',
    };

    // Process each filter with comprehensive error handling
    if (filters != null && filters.isNotEmpty) {
      print('🎯 Processing ${filters.length} filters from AI');
      filters.forEach((aiField, value) {
        print('🎯 Processing filter: $aiField = $value');
        try {
          // Edge case: Skip null, empty, or "Any" values (but allow arrays)
          if (value == null) {
            return;
          }

          // Handle arrays for OR conditions (e.g., ["Black", "White"])
          if (value is List) {
            if (value.isEmpty) return;

            // First, find the filter to understand its type
            final fieldName = fieldNameMapping[aiField];
            if (fieldName == null) {
              print('Unknown AI field: $aiField');
              failedFilters.add(aiField);
              return;
            }

            final filter = widget.filteringOptions.firstWhere(
              (f) => f.fieldName == fieldName,
              orElse: () => filterOption('', '', '', false, false,
                  CatClassification.basic, 0, [], [], false, FilterType.simple),
            );

            if (filter.fieldName != fieldName || filter.options.isEmpty) {
              print('Filter not found or has no options: $fieldName');
              failedFilters.add(aiField);
              return;
            }

            print('🎯 Found array value for $aiField: $value (OR condition)');
            // Process each value in the array
            String appliedName = filter.name;
            List<String> successfullyApplied = [];
            List<String> failedValues = [];

            for (var singleValue in value) {
              // Extract the actual value from the array item
              dynamic actualValue = singleValue;

              // Handle case where value might be a string representation
              if (singleValue is String) {
                actualValue = singleValue.trim();
                // Skip if it's the string representation of an array
                if (actualValue.startsWith('[') && actualValue.endsWith(']')) {
                  print(
                      '   ⚠️ Skipping array string representation: $actualValue');
                  continue;
                }
              }

              if (actualValue == null ||
                  actualValue.toString().trim().isEmpty ||
                  actualValue.toString().trim().toLowerCase() == 'any') {
                continue;
              }

              print(
                  '   🎯 Processing array item: $actualValue (type: ${actualValue.runtimeType})');

              if (filter.list) {
                final applied = _applyListFilter(filter, actualValue, aiField);
                if (applied) {
                  successfullyApplied.add(actualValue.toString());
                  print('   ✅ Successfully applied: $actualValue');
                } else {
                  failedValues.add(actualValue.toString());
                  print('   ❌ Failed to apply: $actualValue');
                }
              } else {
                // For single-select filters, just use the first value
                if (actualValue == value.first) {
                  final applied =
                      _applySingleFilter(filter, actualValue, aiField);
                  if (applied) {
                    successfullyApplied.add(actualValue.toString());
                  } else {
                    failedValues.add(actualValue.toString());
                  }
                }
              }
            }

            print('🎯 Array processing complete for $aiField:');
            print('   ✅ Successfully applied: $successfullyApplied');
            print('   ❌ Failed: $failedValues');
            print(
                '   📊 Current choosenListValues: ${filter.choosenListValues}');
            print('   📊 Original array had ${value.length} items: $value');

            // Check if filter was actually modified (values were added to choosenListValues)
            final hasAppliedValues =
                filter.list && filter.choosenListValues.isNotEmpty;
            final anyOption = filter.options.firstWhere(
              (opt) => opt.search == "Any" || opt.search == "Any Type",
              orElse: () => filter.options.isNotEmpty
                  ? filter.options.last
                  : filter.options.first,
            );
            final hasNonAnyValues = hasAppliedValues &&
                !filter.choosenListValues.every((v) => v == anyOption.value);

            // If at least one value was applied successfully OR filter has non-"Any" values, add it
            if ((successfullyApplied.isNotEmpty || hasNonAnyValues) &&
                filter.list) {
              // Avoid duplicate entries
              if (!filtersToUpdate.contains(filter)) {
                filtersToUpdate.add(filter);
                print('   ✅ Added filter to filtersToUpdate list');
              } else {
                print(
                    '   ⚠️ Filter already in filtersToUpdate list (skipping duplicate)');
              }

              final valuesList = successfullyApplied.isNotEmpty
                  ? successfullyApplied.join(", ")
                  : filter.choosenListValues
                      .where((v) => v != anyOption.value)
                      .map((v) {
                      try {
                        final opt =
                            filter.options.firstWhere((o) => o.value == v);
                        return opt.displayName;
                      } catch (e) {
                        return v.toString();
                      }
                    }).join(", ");
              appliedFilters.add('$appliedName: $valuesList');
              if (failedValues.isNotEmpty) {
                print(
                    '   ⚠️ Some values in array failed, but ${successfullyApplied.length} succeeded');
              }
            } else {
              // All failed or no values
              failedFilters.add(
                  '$appliedName (${failedValues.isEmpty ? "all values failed" : failedValues.join(", ")})');
            }
            return; // Already processed array
          }

          // Handle single values (non-array)
          if (value.toString().trim().isEmpty ||
              value.toString().trim().toLowerCase() == 'any' ||
              value.toString().trim().toLowerCase() == 'null') {
            return;
          }

          // Edge case: Field name not in mapping
          final fieldName = fieldNameMapping[aiField];
          if (fieldName == null) {
            print('Unknown AI field: $aiField');
            failedFilters.add(aiField);
            return;
          }

          // Edge case: Filter not found in filteringOptions
          final filter = widget.filteringOptions.firstWhere(
            (f) => f.fieldName == fieldName,
            orElse: () => filterOption('', '', '', false, false,
                CatClassification.basic, 0, [], [], false, FilterType.simple),
          );

          if (filter.fieldName != fieldName || filter.options.isEmpty) {
            print('Filter not found or has no options: $fieldName');
            failedFilters.add(aiField);
            return;
          }

          // Apply filter based on type
          bool applied = false;
          String appliedName = filter.name;

          if (filter.list) {
            applied = _applyListFilter(filter, value, aiField);
          } else {
            applied = _applySingleFilter(filter, value, aiField);
          }

          if (applied) {
            // Avoid duplicate entries
            if (!filtersToUpdate.contains(filter)) {
              filtersToUpdate.add(filter);
              print('✅ Added filter to filtersToUpdate: ${filter.name}');
            } else {
              print(
                  '⚠️ Filter already in filtersToUpdate (skipping duplicate): ${filter.name}');
            }
            appliedFilters
                .add('$appliedName: ${_getDisplayValue(filter, value)}');
          } else {
            failedFilters.add('$appliedName ($value)');
            print('❌ Filter application failed: $appliedName = $value');
          }
        } catch (e, stackTrace) {
          print('Error applying filter $aiField = $value: $e');
          print('Stack trace: $stackTrace');
          failedFilters.add(aiField);
        }
      });
    }

    // Edge case: No filters could be applied
    print('🎯 Filters to update count: ${filtersToUpdate.length}');
    print('🎯 Applied filters: $appliedFilters');
    print('🎯 Failed filters: $failedFilters');

    if (filtersToUpdate.isEmpty) {
      print('❌ No filters could be applied');
      if (failedFilters.isNotEmpty) {
        print('❌ Failed filters list: $failedFilters');
        _showError(
            'Could not match these filters: ${failedFilters.join(", ")}. Please try different terms.');
      } else {
        print('❌ No failed filters, but also no successful filters');
        _showError(
            'No valid filters found. Please try rephrasing your search.');
      }
      return;
    }

    // Show partial success message if some filters failed
    if (failedFilters.isNotEmpty) {
      print('⚠️ Some filters failed, but ${filtersToUpdate.length} succeeded');
      _showWarning(
          'Some filters could not be applied: ${failedFilters.join(", ")}');
    } else {
      print('✅ All filters applied successfully!');
    }

    // Update UI to show applied filters
    setState(() {
      // Force rebuild to ensure filter values are visible
    });

    // Save search state after filters are applied
    await _saveSearchState();

    // If navigating directly, skip animation and go straight to results
    if (navigateDirect) {
      await Future.delayed(
          Duration(milliseconds: 100)); // Brief delay for UI update

      // Generate filters and navigate back
      try {
        print("=== GENERATING FILTERS FOR DIRECT NAVIGATION ===");
        var filters = generateFilters();
        print("Generated ${filters.length} filters");
        Navigator.pop(context, filters);
      } catch (e) {
        print("Error in direct navigation: $e");
        Navigator.pop(context, []);
      }
      return;
    }

    // Animate setting all filters (only if animate is true)
    if (animate) {
      print(
          '🎯 Starting filter animation with ${filtersToUpdate.length} filters');

      // Small delay to let the UI update
      await Future.delayed(Duration(milliseconds: 100));

      // Now start the animation
      await _animateFilterUpdates(filtersToUpdate, appliedFilters);
    } else {
      // Just update the UI without animation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Applied ${appliedFilters.length} filters'),
          backgroundColor: Color(0xFF2196F3),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Apply list filter (chips/multi-select) with fuzzy matching
  /// Supports adding multiple values for OR conditions
  bool _applyListFilter(filterOption filter, dynamic value, String aiField) {
    try {
      if (filter.classification == CatClassification.breed) {
        // Breed filter with fuzzy matching
        final breedName = value.toString().trim();
        print('      🔍 Looking for breed: "$breedName"');
        final breed = _findBreedByName(breedName);

        if (breed != null && breed.rid > 0) {
          print(
              '      ✅ Found breed: ${breed.name} (ID: ${breed.id}, RID: ${breed.rid})');

          // Remove "Any" option if present
          var anyOption = filter.options.firstWhere(
            (opt) => opt.search == "Any" || opt.search == "Any Type",
            orElse: () => filter.options.isNotEmpty
                ? filter.options.last
                : filter.options.first,
          );
          filter.choosenListValues.remove(anyOption.value);

          // Add the breed RID (not ID) - BreedSelectionScreen uses rid
          if (!filter.choosenListValues.contains(breed.rid)) {
            filter.choosenListValues.add(breed.rid);
            print(
                '      ✅ Added breed RID ${breed.rid} to choosenListValues. New list: ${filter.choosenListValues}');
          } else {
            print(
                '      ⚠️ Breed RID ${breed.rid} already in choosenListValues');
          }
          return true;
        } else {
          print('      ❌ Breed not found for: "$breedName"');
        }
        return false;
      } else {
        // Other list filters with fuzzy matching
        final searchValue = value.toString().trim();
        final matchingOption = _findClosestOption(
          filter.options,
          searchValue,
          isNumeric: false,
        );

        if (matchingOption != null) {
          var anyOption = filter.options.firstWhere(
            (opt) => opt.search == "Any" || opt.search == "Any Type",
            orElse: () => filter.options.isNotEmpty
                ? filter.options.last
                : filter.options.first,
          );

          // Remove "Any" option if present
          filter.choosenListValues.remove(anyOption.value);

          // Add the matching option if not already selected (supports multiple for OR)
          if (!filter.choosenListValues.contains(matchingOption.value)) {
            filter.choosenListValues.add(matchingOption.value);
          }
          return true;
        }
        return false;
      }
    } catch (e) {
      print('Error in _applyListFilter: $e');
      return false;
    }
  }

  /// Apply single-select filter (dropdown) with fuzzy matching
  bool _applySingleFilter(filterOption filter, dynamic value, String aiField) {
    try {
      final searchValue = value.toString().trim();
      final matchingOption = _findClosestOption(
        filter.options,
        searchValue,
        isNumeric: false,
      );

      if (matchingOption != null) {
        filter.choosenValue = matchingOption.search;
        return true;
      }
      return false;
    } catch (e) {
      print('Error in _applySingleFilter: $e');
      return false;
    }
  }

  /// Find closest matching option with fuzzy matching
  listOption? _findClosestOption(
    List<listOption> options,
    String searchValue, {
    bool isNumeric = false,
  }) {
    if (options.isEmpty) return null;

    final normalizedSearch = searchValue.toLowerCase().trim();

    // Edge case: Exact match (case-insensitive)
    try {
      final exactMatch = options.firstWhere(
        (opt) =>
            opt.search.toString().toLowerCase() == normalizedSearch ||
            opt.displayName.toLowerCase() == normalizedSearch,
      );
      if (exactMatch.search != "Any" && exactMatch.search != "Any Type") {
        return exactMatch;
      }
    } catch (e) {
      // Continue to next matching strategy
    }

    // Edge case: Numeric matching for distance
    if (isNumeric) {
      final searchNum = int.tryParse(normalizedSearch);
      if (searchNum != null) {
        // Find closest numeric match
        listOption? closest;
        int? closestDiff;

        for (var option in options) {
          final optionNum = int.tryParse(option.search.toString());
          if (optionNum != null) {
            final diff = (optionNum - searchNum).abs();
            if (closestDiff == null || diff < closestDiff) {
              closestDiff = diff;
              closest = option;
            }
          }
        }

        if (closest != null) {
          return closest;
        }
      }
    }

    // Edge case: Partial match (contains)
    try {
      final partialMatch = options.firstWhere(
        (opt) =>
            opt.search.toString().toLowerCase().contains(normalizedSearch) ||
            opt.displayName.toLowerCase().contains(normalizedSearch) ||
            normalizedSearch.contains(opt.search.toString().toLowerCase()) ||
            normalizedSearch.contains(opt.displayName.toLowerCase()),
      );
      if (partialMatch.search != "Any" && partialMatch.search != "Any Type") {
        return partialMatch;
      }
    } catch (e) {
      // Continue to variations
    }

    // Edge case: Common variations mapping
    final variations = _getCommonVariations(normalizedSearch);
    for (var variation in variations) {
      try {
        final match = options.firstWhere(
          (opt) =>
              opt.search.toString().toLowerCase() == variation ||
              opt.displayName.toLowerCase() == variation,
        );
        if (match.search != "Any" && match.search != "Any Type") {
          return match;
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  /// Find breed by name with fuzzy matching
  Breed? _findBreedByName(String breedName) {
    if (breeds.isEmpty) return null;

    final normalized = breedName.toLowerCase().trim();
    print(
        '      🔍 Searching for breed: "$breedName" (normalized: "$normalized")');

    // Exact match (highest priority)
    try {
      final exactMatch = breeds.firstWhere(
        (b) => b.name.toLowerCase() == normalized,
      );
      print('      ✅ Exact match found: ${exactMatch.name}');
      return exactMatch;
    } catch (e) {
      print('      ⚠️ No exact match');
      // Continue to fuzzy match
    }

    final searchWords =
        normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final isMultiWord = searchWords.length > 1;

    if (isMultiWord) {
      // Multi-word search (e.g., "devon rex")
      // Find breeds that contain ALL words in the correct order
      List<Breed> candidates = [];

      for (var breed in breeds) {
        final breedLower = breed.name.toLowerCase();
        // Check if all search words appear in the breed name
        final allWordsMatch =
            searchWords.every((word) => breedLower.contains(word));
        if (allWordsMatch) {
          candidates.add(breed);
        }
      }

      if (candidates.isNotEmpty) {
        // Sort by score and return best match
        candidates.sort((a, b) {
          final aScore = _calculateMatchScore(
              a.name.toLowerCase(), normalized, searchWords);
          final bScore = _calculateMatchScore(
              b.name.toLowerCase(), normalized, searchWords);
          return bScore.compareTo(aScore); // Higher score first
        });
        print(
            '      ✅ Found multi-word match: ${candidates.first.name} (${candidates.length} candidates)');
        return candidates.first;
      }
      print('      ⚠️ No multi-word match');
    } else {
      // Single-word search (e.g., "siamese", "abyssinian")
      // Use strict word boundary matching to avoid false matches
      final word = searchWords.first;

      // Try exact word match first (word boundaries)
      try {
        final exactWordMatch = breeds.firstWhere(
          (b) {
            final breedLower = b.name.toLowerCase();
            // Match whole word only (not substring)
            return RegExp(r'\b' + RegExp.escape(word) + r'\b')
                .hasMatch(breedLower);
          },
        );
        print('      ✅ Found exact word match: ${exactWordMatch.name}');
        return exactWordMatch;
      } catch (e) {
        print('      ⚠️ No exact word match');
      }

      // Fallback: partial match but prefer if it's at the start
      List<Breed> candidates = [];
      for (var breed in breeds) {
        final breedLower = breed.name.toLowerCase();
        if (breedLower.contains(word)) {
          // Prefer matches where word is at the start
          if (breedLower.startsWith(word)) {
            candidates.insert(0, breed);
          } else {
            candidates.add(breed);
          }
        }
      }

      if (candidates.isNotEmpty) {
        print('      ✅ Found partial match: ${candidates.first.name}');
        return candidates.first;
      }
    }

    // Final fallback: any partial match
    try {
      final breedContainsMatch = breeds.firstWhere(
        (b) => b.name.toLowerCase().contains(normalized),
      );
      print(
          '      ✅ Found breed containing search term: ${breedContainsMatch.name}');
      return breedContainsMatch;
    } catch (e) {
      print('      ⚠️ No partial match');
      // Continue to variations
    }

    // Common breed name variations
    final breedVariations = {
      'persian': ['persian', 'persian cat'],
      'siamese': ['siamese', 'siamese cat'],
      'maine coon': ['maine coon', 'mainecoon', 'maine-coon'],
      'ragdoll': ['ragdoll', 'rag doll', 'rag-doll'],
      'british shorthair': ['british shorthair', 'british short hair', 'bsh'],
      'scottish fold': ['scottish fold', 'scottish-fold'],
      'american shorthair': ['american shorthair', 'american short hair'],
      'devon rex': ['devon rex', 'devonrex'],
      'cornish rex': ['cornish rex', 'cornishrex'],
      'selkirk rex': ['selkirk rex', 'selkirkrex'],
    };

    for (var entry in breedVariations.entries) {
      if (entry.value.contains(normalized)) {
        try {
          return breeds.firstWhere(
            (b) => b.name.toLowerCase() == entry.key,
          );
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  /// Calculate match score for breed matching
  int _calculateMatchScore(
      String breedLower, String searchNormalized, List<String> searchWords) {
    int score = 0;

    // Exact match gets highest score
    if (breedLower == searchNormalized) {
      return 100;
    }

    // Full phrase match
    if (breedLower.contains(searchNormalized)) {
      score += 20;
    }

    // Word boundary matches (exact words)
    for (var word in searchWords) {
      if (RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(breedLower)) {
        score += 10;
      } else if (breedLower.contains(word)) {
        score += 5;
      }
    }

    // Prefer matches at the start
    if (breedLower.startsWith(searchWords.first)) {
      score += 5;
    }

    return score;
  }

  /// Get common value variations
  List<String> _getCommonVariations(String value) {
    final variations = <String>[value];

    // Gender variations
    if (value.contains('male') || value.contains('boy')) {
      variations.addAll(['male', 'm']);
    }
    if (value.contains('female') || value.contains('girl')) {
      variations.addAll(['female', 'f']);
    }

    // Age variations
    if (value.contains('kitten') || value.contains('baby')) {
      variations.add('baby');
    }
    if (value.contains('senior') || value.contains('old')) {
      variations.add('senior');
    }
    if (value.contains('adult') && !value.contains('young')) {
      variations.add('adult');
    }

    // Size variations
    if (value.contains('small') || value.contains('tiny')) {
      variations.add('small');
    }
    if (value.contains('large') || value.contains('big')) {
      if (value.contains('extra') || value.contains('x-')) {
        variations.add('x-large');
      } else {
        variations.add('large');
      }
    }

    // Yes/No variations
    if (value.contains('yes') || value.contains('y')) {
      variations.add('yes');
    }
    if (value.contains('no') || value.contains('n')) {
      variations.add('no');
    }

    return variations;
  }

  /// Get display value for a filter
  String _getDisplayValue(filterOption filter, dynamic value) {
    if (filter.list) {
      if (filter.classification == CatClassification.breed) {
        final breed = _findBreedByName(value.toString());
        return breed?.name ?? value.toString();
      } else {
        final option = _findClosestOption(filter.options, value.toString());
        return option?.displayName ?? value.toString();
      }
    } else {
      final option = _findClosestOption(filter.options, value.toString());
      return option?.displayName ?? value.toString();
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// Validate ZIP code format (basic format check, full validation is done via API)
  bool _isValidZipCodeFormat(String zip) {
    // US ZIP code validation (5 digits or 5+4 format)
    final zipRegex = RegExp(r'^\d{5}(-\d{4})?$');
    return zipRegex.hasMatch(zip);
  }

  /// Show warning message
  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Enhanced animation with visible filter updates
  Future<void> _animateFilterUpdates(
    List<filterOption> filters,
    List<String> appliedFilters,
  ) async {
    if (filters.isEmpty) {
      print('⚠️ No filters to animate');
      return;
    }

    print('🎬 Starting animation for ${filters.length} filters');
    HapticFeedback.mediumImpact();
    final animationDuration = Duration(milliseconds: 800);
    final staggerDelay = Duration(milliseconds: 400);
    final scrollDuration = Duration(milliseconds: 500);
    final expansionDelay = Duration(milliseconds: 400);

    // Clear previous animations and highlights
    setState(() {
      _animatingFilters.clear();
      _highlightedOptions.clear();
    });

    // Wait a frame to ensure previous state is cleared
    await Future.delayed(Duration(milliseconds: 50));

    // Animate each filter one by one
    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      final filterKey = filter.fieldName;
      final classification = filter.classification;
      final categoryKey = _categoryKeys[classification];
      final filterRowKey = _filterKeys[filterKey];

      print(
          '🎬 Animating filter ${i + 1}/${filters.length}: ${filter.name} (${filter.fieldName})');
      print('   Classification: $classification');

      // Step 1: Scroll to the category section
      if (categoryKey != null && categoryKey.currentContext != null) {
        print('   📍 Step 1: Scrolling to category');
        await Scrollable.ensureVisible(
          categoryKey.currentContext!,
          duration: scrollDuration,
          curve: Curves.easeInOut,
          alignment: 0.1, // Position category near top
        );
        await Future.delayed(
            Duration(milliseconds: 150)); // Wait for scroll to settle
        print('   ✅ Scrolled to category');
      } else {
        print('   ⚠️ Category key or context is null');
      }

      // Step 2: Expand the category if it's not already expanded
      final isCurrentlyExpanded = _expandedCategories[classification] ?? false;
      print('   📂 Step 2: Category expanded: $isCurrentlyExpanded');
      if (!isCurrentlyExpanded) {
        print('   🔓 Expanding category...');
        // Force rebuild by updating state
        setState(() {
          _expandedCategories[classification] = true;
        });

        // Wait a bit for the state update to take effect
        await Future.delayed(Duration(milliseconds: 100));

        // Trigger another rebuild to ensure ExpansionTile gets the new state
        setState(() {
          // Just trigger rebuild - state already set to true
        });

        await Future.delayed(expansionDelay); // Wait for expansion animation
        print('   ✅ Category expanded');
      } else {
        print('   ✓ Category already expanded');
      }

      // Step 3: Scroll to the specific filter row
      if (filterRowKey != null && filterRowKey.currentContext != null) {
        print('   📍 Step 3: Scrolling to filter row');
        await Scrollable.ensureVisible(
          filterRowKey.currentContext!,
          duration: scrollDuration,
          curve: Curves.easeInOut,
          alignment: 0.2, // Position filter 20% from top
        );
        await Future.delayed(
            Duration(milliseconds: 150)); // Wait for scroll to settle
        print('   ✅ Scrolled to filter row');
      } else {
        print('   ⚠️ Filter row key or context is null');
      }

      // Step 4: Highlight the filter row and the specific option value
      print('   ✨ Step 4: Highlighting filter and option');
      setState(() {
        _animatingFilters[filterKey] = true;

        // Find and highlight the selected option value
        if (filter.list) {
          // For list filters, highlight the selected option(s)
          print(
              '      List filter - chosen values: ${filter.choosenListValues}');
          if (filter.choosenListValues.isNotEmpty) {
            for (var value in filter.choosenListValues) {
              final highlightKey = '${filterKey}:$value';
              _highlightedOptions[highlightKey] = true;
              print('      Highlighting option: $highlightKey');
            }
          }
        } else {
          // For single-select filters, highlight the chosen value
          print('      Single filter - chosen value: ${filter.choosenValue}');
          if (filter.choosenValue != null) {
            // Find the option that matches the chosenValue
            try {
              final matchingOption = filter.options.firstWhere(
                (opt) =>
                    opt.search.toString() == filter.choosenValue.toString(),
              );
              final highlightKey = '${filterKey}:${matchingOption.value}';
              _highlightedOptions[highlightKey] = true;
              print(
                  '      Highlighting option: $highlightKey (value: ${matchingOption.value})');

              // Also add highlight for search value (for dropdown compatibility)
              final searchHighlightKey = '${filterKey}:${filter.choosenValue}';
              _highlightedOptions[searchHighlightKey] = true;
            } catch (e) {
              // If option not found, try direct value matching
              final highlightKey = '${filterKey}:${filter.choosenValue}';
              _highlightedOptions[highlightKey] = true;
              print('      Highlighting option (fallback): $highlightKey');
            }
          }
        }
      });
      print('   ✅ Highlighted - animating...');

      // Haptic feedback for each filter
      HapticFeedback.selectionClick();

      // Step 5: Wait for highlight animation
      await Future.delayed(animationDuration);
      print('   ✅ Highlight animation complete');

      // Step 6: Keep the highlight for a moment, then remove only the option highlight
      // (Keep the section expanded and filter row visible)
      setState(() {
        // Remove the option highlight but keep the filter row highlight briefly
        _highlightedOptions.clear();
      });

      await Future.delayed(Duration(milliseconds: 300));

      // Step 7: Remove filter row highlight (section stays expanded)
      setState(() {
        _animatingFilters[filterKey] = false;
      });
      print('   ✅ Filter animation complete');

      // Stagger delay before next filter
      if (i < filters.length - 1) {
        await Future.delayed(staggerDelay);
      }
    }

    HapticFeedback.lightImpact();

    // Show success message with applied filters
    final message = appliedFilters.length <= 3
        ? '✓ Applied: ${appliedFilters.join(", ")}'
        : '✓ Applied ${appliedFilters.length} filters';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF2196F3),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Check if a filter is currently being animated
  bool _isFilterAnimating(filterOption filter) {
    return _animatingFilters[filter.fieldName] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Find Your Perfect Cat"),
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2196F3).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Quick Search Section
              _buildQuickSearchCard(),
              SizedBox(height: 20),

              // Filter Categories
              _buildFilterCategory(
                  "Basic Info", Icons.info_outline, CatClassification.basic),
              _buildFilterCategory(
                  "Breed & Appearance", Icons.pets, CatClassification.breed),
              _buildFilterCategory(
                  "Personality", Icons.face, CatClassification.personality),
              _buildFilterCategory("Compatibility", Icons.favorite,
                  CatClassification.compatibility),
              _buildFilterCategory(
                  "Physical Traits", Icons.scale, CatClassification.physical),
              _buildFilterCategory(
                  "Sort Options", Icons.sort, CatClassification.sort),
              _buildFilterCategory(
                  "Saved Searches", Icons.save_alt, CatClassification.saves),

              SizedBox(height: 100), // Space for bottom buttons
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  void saveSearch() {
    // Implement save search functionality
    print("Save search functionality");
  }

  List<Filters> generateFilters() {
    DateTime date = DateTime.now();

    List<Filters> filters = [];
    filters.add(Filters(
        fieldName: "species.singular", operation: "equals", criteria: ["cat"]));

    print("=== GENERATING FILTERS ===");
    print("Processing ${widget.filteringOptions.length} filter options");
    for (var item in widget.filteringOptions) {
      if (item.classification == CatClassification.saves) {
        continue;
      }
      if (item.classification == CatClassification.sort) {
        if (item.fieldName == "sortBy") {
          if (item.choosenValue == "date") {
            sortMethod = "-animals.updatedDate";
          } else {
            sortMethod = "animals.distance";
          }
        } else if (item.fieldName == "distance") {
          if (item.choosenValue == "" || item.choosenValue == "Any") {
            distance = 1000;
          } else {
            distance = int.parse(item.choosenValue);
          }
        } else if (item.fieldName == "animals.updatedDate") {
          if (!(item.choosenValue == "" || item.choosenValue == "Any")) {
            if (item.choosenValue == "Day") {
              updatedSince = 0;
              date = date.subtract(const Duration(days: 1));
            } else if (item.choosenValue == "Week") {
              updatedSince = 1;
              date = date.subtract(const Duration(days: 7));
            } else if (item.choosenValue == "Month") {
              updatedSince = 2;
              date = date.subtract(const Duration(days: 30));
            } else if (item.choosenValue == "Year") {
              updatedSince = 3;
              date = date.subtract(const Duration(days: 365));
            }
            filters.add(Filters(
                fieldName: "animals.updatedDate",
                operation: "greaterthan",
                criteria: [
                  date.year.toString() +
                      "-" +
                      date.month.toString() +
                      "-" +
                      date.day.toString() +
                      "T00:00:00Z"
                ]));
          } else {
            updatedSince = 4;
          }
        }
        continue;
      }
      if (item.list) {
        // Special handling for breed filters
        if (item.classification == CatClassification.breed) {
          // Check if "Any" is selected (value 0)
          if (!item.choosenListValues.contains(0) &&
              item.choosenListValues.isNotEmpty) {
            List<String> breedIds = [];
            for (var breedRid in item.choosenListValues) {
              // Find breed by rid (values are stored as rid)
              try {
                final breed = breeds.firstWhere((b) => b.rid == breedRid);
                breedIds.add(breed.rid.toString());
              } catch (e) {
                print('⚠️ Breed with RID $breedRid not found for filter');
              }
            }
            if (breedIds.isNotEmpty) {
              filters.add(Filters(
                  fieldName: item.fieldName,
                  operation: "equals",
                  criteria: breedIds));
            }
          }
        } else {
          // Check if "Any" option is selected (skip if so)
          var anyOption = item.options.firstWhere(
            (opt) => opt.search == "Any" || opt.search == "Any Type",
            orElse: () => item.options.last,
          );

          if (!item.choosenListValues.contains(anyOption.value)) {
            List<String> OptionsList = [];
            for (var choosenValue in item.choosenListValues) {
              OptionsList.add(item.options
                  .where((element) => element.value == choosenValue)
                  .first
                  .search
                  .toString());
            }
            if (OptionsList.isNotEmpty) {
              filters.add(Filters(
                  fieldName: item.fieldName,
                  operation: "equals",
                  criteria: OptionsList));
            }
          }
        }
      } else {
        // Handle different value types
        dynamic value = item.choosenValue;

        // Skip if value is null, empty, or explicitly "Any"
        if (value == null ||
            value == "" ||
            value == "Any" ||
            value == "Any Type") {
          continue;
        }

        // Convert value to string for additional checks
        String stringValue = value.toString().trim();

        // Skip if string value is empty or matches "Any" (case-insensitive)
        if (stringValue.isEmpty ||
            stringValue.toLowerCase() == "any" ||
            stringValue.toLowerCase() == "any type") {
          continue;
        }

        // Check if the value corresponds to an "Any" option in the options list
        if (item.options.isNotEmpty) {
          // Find the option that matches the chosen value
          var matchingOption = item.options.firstWhere(
            (opt) => opt.value == value || opt.search == stringValue,
            orElse: () => item.options.first,
          );

          // If the matching option is "Any" or "Any Type", skip this filter
          if (matchingOption.search == "Any" ||
              matchingOption.search == "Any Type") {
            continue;
          }
        }

        print("Adding filter: ${item.fieldName} = $stringValue");
        filters.add(Filters(
            fieldName: item.fieldName,
            operation: "equals",
            criteria: [stringValue]));
      }
    }
    print("=== FINAL FILTERS ===");
    print("Total filters: ${filters.length}");
    for (var filter in filters) {
      print(
          "Filter: ${filter.fieldName} ${filter.operation} ${filter.criteria}");
    }
    return filters;
  }
}
