import 'package:flutter/material.dart';
import '../../ExampleCode/petTileData.dart';
import '../../theme.dart';
import 'gold_trait_pill.dart';

class GoldPetCard extends StatelessWidget {
  final PetTileData tile;
  final List<String> favorites;

  const GoldPetCard({
    Key? key,
    required this.tile,
    required this.favorites,
  }) : super(key: key);

  bool get _hasImage =>
      tile.smallPicture != null && tile.smallPicture!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 5.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: AppTheme.purpleGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFramedImage(),
          const SizedBox(height: 8),
          _buildNameAndBreed(),
          const SizedBox(height: 10),
          _buildTraits(),
          const SizedBox(height: 10),
          _buildLocation(),
        ],
      ),
    );
  }

  Widget _buildFramedImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available width: card width minus margins and padding
        // Card has 5px horizontal margin, 6px container margin, 2px border on each side
        final availableWidth = constraints.maxWidth - 12 - 4; // 6px margin * 2 + 2px border * 2
        final imageWidth = availableWidth;
        
        return Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFB07A26),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                if (!_hasImage)
                  Container(
                    width: imageWidth,
                    height: imageWidth * 0.75, // Default aspect ratio for placeholder
                    child: _buildNoImagePlaceholder(),
                  )
                else
                  Image.network(
                    tile.smallPicture!,
                    width: imageWidth,
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: imageWidth,
                        height: imageWidth * 0.75,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: imageWidth,
                        height: imageWidth * 0.75,
                        child: _buildNoImagePlaceholder(),
                      );
                    },
                  ),

                // Favorite icon
                Positioned(
                  top: 8,
                  left: 8,
                  child: Visibility(
                    visible: favorites.contains(tile.id),
                    child: Image.asset(
                      "assets/Icons/favorited_icon_resized.png",
                    ),
                  ),
                ),

                // Video icon
                Positioned(
                  top: 8,
                  right: 8,
                  child: Visibility(
                    visible: tile.hasVideos ?? false,
                    child: Image.asset(
                      "assets/Icons/video_icon_resized.png",
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      color: AppTheme.deepPurple.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 60,
            color: AppTheme.goldBase.withOpacity(0.7),
          ),
          const SizedBox(height: 12),
          Text(
            "Sorry No Image",
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontSizeM,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameAndBreed() {
    final name = (tile.name ?? "No Name").toUpperCase();
    final breed = tile.primaryBreed ?? "";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: AppTheme.fontSizeXXL,
              fontFamily: AppTheme.fontFamily,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                  color: AppTheme.goldBase.withOpacity(0.6),
                ),
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
          if (breed.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              breed,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: AppTheme.fontSizeM,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTraits() {
    final traits = <String>[];

    if (tile.status != null && tile.status!.trim().isNotEmpty) {
      traits.add(tile.status!);
    }
    if (tile.age != null && tile.age!.trim().isNotEmpty) {
      traits.add(tile.age!);
    }
    if (tile.sex != null && tile.sex!.trim().isNotEmpty) {
      traits.add(tile.sex!);
    }
    if (tile.size != null && tile.size!.trim().isNotEmpty) {
      traits.add(tile.size!);
    }

    if (traits.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: traits.map((t) => GoldTraitPill(label: t)).toList(),
      ),
    );
  }

  Widget _buildLocation() {
    final location = tile.cityState;
    if (location == null || location.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 24,
            color: AppTheme.goldHighlight,
            shadows: [
              Shadow(
                color: AppTheme.goldBase.withOpacity(0.8),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              location.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeM,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: AppTheme.fontFamily,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
