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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, selectedBreeds);
      },
      child: Scaffold(
        appBar: GradientAppBar(
          title: "Select Breeds",
        ),
        body: Container(
        decoration: BoxDecoration(
          color: AppTheme.royalPurple,
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
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      anySelected
                          ? "Select one or more breeds"
                          : "${selectedBreeds.length} breed${selectedBreeds.length == 1 ? '' : 's'} selected",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!anySelected)
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          anySelected = true;
                          selectedBreeds = [0];
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.goldBase, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20), // Pill shape
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: const Size(0, 32), // Small height
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "Clear All",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                itemCount: _filteredBreeds.length,
                itemBuilder: (context, index) {
                  final breed = _filteredBreeds[index];
                  return _buildBreedOption(breed);
                },
              ),
            ),

            // Done button - always visible at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.purpleGradient,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, selectedBreeds);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldBase,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAnyOption() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleBreed(0),
        borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: anySelected ? null : AppTheme.purpleGradient,
                    color: anySelected ? AppTheme.offWhite : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.all_inclusive,
                    color: anySelected ? const Color(0xFF2196F3) : const Color(0xFF2196F3),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Any Breed",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: anySelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (anySelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.deepPurple,
                    size: 20,
                  ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildBreedOption(Breed breed) {
    bool isSelected = selectedBreeds.contains(breed.rid);

    // Gold gradient for selected breeds
    final goldGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.goldHighlight,
        AppTheme.goldBase,
        AppTheme.goldShadow,
      ],
    );

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
              // Gold gradient for selected, white for unselected
              gradient: isSelected ? goldGradient : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.goldBase : Colors.grey[300]!,
                width: isSelected ? 3 : 1, // Thicker border when selected
              ),
              boxShadow: isSelected 
                ? [
                    // Golden glow effect
                    BoxShadow(
                      color: AppTheme.goldBase.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: AppTheme.goldBase.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : [
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
                    // Add border to image when selected
                    border: isSelected 
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/Cartoon/${breed.pictureHeadShotName.replaceAll(' ', '_')}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        final imagePath = 'assets/Cartoon/${breed.pictureHeadShotName.replaceAll(' ', '_')}.png';
                        print("❌ Failed to load image: $imagePath for breed: ${breed.name} (pictureHeadShotName: ${breed.pictureHeadShotName})");
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppTheme.goldBase,
                      size: 24, // Larger checkmark
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
