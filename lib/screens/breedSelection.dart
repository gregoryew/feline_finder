import 'package:flutter/material.dart';
import 'package:catapp/models/breed.dart';
import '../theme.dart';
import '../widgets/design_system.dart';

class BreedSelectionScreen extends StatefulWidget {
  final List<int> selectedBreeds;

  const BreedSelectionScreen({
    Key? key,
    required this.selectedBreeds,
  }) : super(key: key);

  @override
  State<BreedSelectionScreen> createState() => _BreedSelectionScreenState();
}

class _BreedSelectionScreenState extends State<BreedSelectionScreen> {
  late List<int> selectedBreeds;
  bool anySelected = true;
  late TextEditingController _searchController;
  List<Breed> _filteredBreeds = [];
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    selectedBreeds = List.from(widget.selectedBreeds);
    // If no breeds are selected or only "Any" is selected, set anySelected to true
    // If specific breeds are selected (not just "Any"), set anySelected to false
    anySelected = selectedBreeds.isEmpty ||
        (selectedBreeds.length == 1 && selectedBreeds.contains(0));
    
    _searchController = TextEditingController();
    _filteredBreeds = List.from(breeds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBreeds(String query) {
    setState(() {
      _hasSearchText = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredBreeds = List.from(breeds);
      } else {
        _filteredBreeds = breeds.where((breed) =>
            breed.name.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  void _toggleBreed(int breedId) {
    setState(() {
      if (breedId == 0) {
        // "Any" option selected
        anySelected = true;
        selectedBreeds = [0];
      } else {
        // Specific breed selected
        anySelected = false;
        if (selectedBreeds.contains(breedId)) {
          selectedBreeds.remove(breedId);
          // If no breeds selected, select "Any"
          if (selectedBreeds.isEmpty) {
            anySelected = true;
            selectedBreeds = [0];
          }
        } else {
          // Remove "Any" option if it exists and add the specific breed
          selectedBreeds.remove(0);
          selectedBreeds.add(breedId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: "Select Breeds",
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, selectedBreeds);
            },
            child: const Text(
              "Done",
              style: TextStyle(
                color: AppTheme.offWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.deepPurple.withOpacity(0.1),
              AppTheme.offWhite,
            ],
          ),
        ),
        child: Column(
          children: [
            // Selection summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.purpleGradient,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pets,
                    color: AppTheme.deepPurple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      anySelected
                          ? "Any breed selected"
                          : "${selectedBreeds.length} breed${selectedBreeds.length == 1 ? '' : 's'} selected",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepPurple,
                      ),
                    ),
                  ),
                  if (!anySelected)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          anySelected = true;
                          selectedBreeds = [0];
                        });
                      },
                      child: const Text("Clear All"),
                    ),
                ],
              ),
            ),

            // Search box for filtering breeds
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.purpleGradient,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterBreeds,
                decoration: InputDecoration(
                  hintText: 'Search breeds...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.deepPurple),
                  suffixIcon: _hasSearchText
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterBreeds('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    borderSide: BorderSide(color: AppTheme.goldBase, width: AppTheme.borderWidth),
                  ),
                  filled: true,
                  fillColor: AppTheme.offWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // Breeds list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredBreeds.length + 1, // +1 for "Any" option
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "Any" option
                    return _buildAnyOption();
                  } else {
                    // Breed option
                    final breed = _filteredBreeds[index - 1];
                    return _buildBreedOption(breed);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnyOption() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleBreed(0),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: anySelected ? null : AppTheme.purpleGradient,
              color: anySelected ? AppTheme.deepPurple : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: anySelected ? AppTheme.goldBase : Colors.grey[300]!,
                width: anySelected ? AppTheme.borderWidth : 1,
              ),
              boxShadow: anySelected ? AppTheme.goldenGlow : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Any icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: anySelected ? null : AppTheme.purpleGradient,
                    color: anySelected ? AppTheme.offWhite : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.all_inclusive,
                    color: anySelected ? const Color(0xFF2196F3) : const Color(0xFF2196F3),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Any Breed",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: anySelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Show all breeds",
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              anySelected ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (anySelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.offWhite,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreedOption(Breed breed) {
    bool isSelected = selectedBreeds.contains(breed.rid);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleBreed(breed.rid),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Breed photo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[300],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/Cartoon/${breed.name.replaceAll(' ', '_')}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.pets,
                          color: Colors.white,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        breed.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? const Color(0xFF2196F3) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.deepPurple,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
