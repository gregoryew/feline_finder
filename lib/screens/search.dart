import 'package:flutter/material.dart';
import 'package:catapp/models/searchPageConfig.dart';
import 'package:catapp/ExampleCode/RescueGroupsQuery.dart';
import 'package:catapp/screens/globals.dart';
import 'package:catapp/models/breed.dart';
import 'package:catapp/screens/breedSelection.dart';

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

  @override
  void initState() {
    super.initState();
    controller2 = TextEditingController();

    // Initialize filter values to prevent type errors
    _initializeFilterValues();
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
        // For single-select filters
        if (filter.choosenValue == null || filter.choosenValue == "") {
          // Find the "Any" option and set it as default
          var anyOption = filter.options.firstWhere(
            (option) => option.search == "Any" || option.search == "Any Type",
            orElse: () => filter.options.first,
          );
          filter.choosenValue = anyOption.search;
          print('Set ${filter.name} to Any option: ${filter.choosenValue}');
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

  @override
  void dispose() {
    controller2.dispose();
    super.dispose();
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
                  decoration: InputDecoration(
                    hintText: "Search by name, breed, or keywords...",
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
                  label: Text("Quick Search",
                      style: TextStyle(color: Colors.white)),
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
                  onPressed: () => _showAdvancedFilters(),
                  icon: Icon(Icons.tune, color: Color(0xFF2196F3)),
                  label: Text("Advanced",
                      style: TextStyle(color: Color(0xFF2196F3))),
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

    return Container(
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
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            filter.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          if (filter.classification == CatClassification.breed)
            _buildBreedSelector(filter)
          else if (filter.list)
            _buildChipSelector(filter)
          else
            _buildDropdownSelector(filter),
        ],
      ),
    );
  }

  Widget _buildBreedSelector(filterOption filter) {
    // Get selected breed names for display
    String selectedBreedsText = "Any breed";
    if (filter.choosenListValues.isNotEmpty &&
        !filter.choosenListValues.contains(0)) {
      List<String> selectedNames = [];
      for (var breedId in filter.choosenListValues) {
        if (breedId > 0 && breedId <= breeds.length) {
          selectedNames.add(breeds[breedId - 1].name);
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

        return FilterChip(
          label: Text(option.displayName),
          selected: isSelected,
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
          selectedColor: Color(0xFF2196F3).withOpacity(0.2),
          checkmarkColor: Color(0xFF2196F3),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected ? Color(0xFF2196F3) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
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

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFF2196F3).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentValueStr,
            isExpanded: true,
            items: filter.options.map((option) {
              return DropdownMenuItem<String>(
                value: option.search.toString(),
                child: Text(option.displayName),
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
              onPressed: () {
                try {
                  print("=== FIND CATS BUTTON PRESSED ===");
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

  void _performQuickSearch() {
    // Implement quick search functionality
    Navigator.pop(context, generateFilters());
  }

  void _showAdvancedFilters() {
    // Show all filter categories expanded
    setState(() {
      // This could expand all categories or show a different view
    });
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
                  "Location", Icons.location_on, CatClassification.zipCode),
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

    int filtersAdded = 0;
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
            for (var breedId in item.choosenListValues) {
              if (breedId > 0 && breedId <= breeds.length) {
                breedIds.add(breeds[breedId - 1].rid.toString());
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
        if (value == "Any" ||
            value == "Any Type" ||
            value == "" ||
            value == null) {
          continue;
        }

        // Convert value to string for the API
        String stringValue = value.toString();
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
