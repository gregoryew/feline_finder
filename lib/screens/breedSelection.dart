import 'package:flutter/material.dart';
import 'package:catapp/models/breed.dart';

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

  @override
  void initState() {
    super.initState();
    selectedBreeds = List.from(widget.selectedBreeds);
    // If no breeds are selected or only "Any" is selected, set anySelected to true
    // If specific breeds are selected (not just "Any"), set anySelected to false
    anySelected = selectedBreeds.isEmpty ||
        (selectedBreeds.length == 1 && selectedBreeds.contains(0));
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
      appBar: AppBar(
        title: Text("Select Breeds"),
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, selectedBreeds);
            },
            child: Text(
              "Done",
              style: TextStyle(
                color: Colors.white,
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
              Color(0xFF2196F3).withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Selection summary
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pets,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      anySelected
                          ? "Any breed selected"
                          : "${selectedBreeds.length} breed${selectedBreeds.length == 1 ? '' : 's'} selected",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2196F3),
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
                      child: Text("Clear All"),
                    ),
                ],
              ),
            ),

            // Breeds list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: breeds.length + 1, // +1 for "Any" option
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "Any" option
                    return _buildAnyOption();
                  } else {
                    // Breed option
                    final breed = breeds[index - 1];
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
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleBreed(0),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: anySelected ? Color(0xFF2196F3) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: anySelected ? Color(0xFF2196F3) : Colors.grey[300]!,
                width: anySelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
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
                    color: anySelected
                        ? Colors.white
                        : Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.all_inclusive,
                    color: anySelected ? Color(0xFF2196F3) : Color(0xFF2196F3),
                    size: 32,
                  ),
                ),
                SizedBox(width: 16),
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
                      SizedBox(height: 4),
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
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
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
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleBreed(breed.rid),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Color(0xFF2196F3).withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Color(0xFF2196F3) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
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
                          color: Colors.grey[600],
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 12),
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
                              isSelected ? Color(0xFF2196F3) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Color(0xFF2196F3),
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
