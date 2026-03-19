import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../ExampleCode/petTileData.dart';
import '../theme.dart';

class RankedCatCard extends StatelessWidget {
  final PetTileData tile;
  final List<String> favorites;
  final bool showVideoGlow;
  final void Function(String)? onVideoBadgeFirstSeen;
  final VoidCallback onTap;
  /// When true, show updated date (mm/dd/yyyy) below photo; when false, show miles.
  final bool sortByRecent;

  const RankedCatCard({
    Key? key,
    required this.tile,
    required this.favorites,
    required this.showVideoGlow,
    required this.onVideoBadgeFirstSeen,
    required this.onTap,
    this.sortByRecent = false,
  }) : super(key: key);

  bool get _hasImage =>
      tile.smallPicture != null && tile.smallPicture!.trim().isNotEmpty;

  bool get _isFavorited => tile.id != null && favorites.contains(tile.id);

  static const Map<String, String> _kTraitNameToAdjective = {
    'Energy Level': 'energetic',
    'Playfulness': 'playful',
    'Affection Level': 'cuddly',
    'Independence': 'independent',
    'Sociability': 'social',
    'Vocality': 'talkative',
    'Confidence': 'confident',
    'Sensitivity': 'gentle',
    'Adaptability': 'curious',
    'Intelligence': 'intelligent',
  };

  static String _capitalize(String s) {
    if (s.trim().isEmpty) return s;
    final t = s.trim();
    return '${t[0].toUpperCase()}${t.substring(1)}';
  }

  /// Formatted updated date mm/dd/yyyy, or null if unparseable.
  static String? _formatUpdatedDate(String? updatedDate) {
    if (updatedDate == null || updatedDate.isEmpty) return null;
    final dt = DateTime.tryParse(updatedDate);
    if (dt == null) return null;
    final d = dt.toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final y = d.year;
    return '$m/$day/$y';
  }

  List<String> _getTraitAdjectives() {
    final traits = tile.personalityFitTraits;
    if (traits == null || traits.isEmpty) return const [];

    final entries = traits.entries
        .where((e) => e.value != null)
        .toList()
      ..sort((a, b) => b.value!.compareTo(a.value!));

    return entries
        .take(2)
        .map((e) => _capitalize(_kTraitNameToAdjective[e.key] ?? e.key))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final name = (tile.name ?? 'No Name').trim();
    final breed = (tile.primaryBreed ?? '').trim();
    final matchScore = tile.personalityFitScore;
    final matchLabel = matchScore == null
        ? null
        : '${matchScore.round()}% Match';

    final suggestedType = (tile.suggestedCatTypeName ?? '').trim();
    final adjectives = _getTraitAdjectives();
    final standoutLine = [
      if (suggestedType.isNotEmpty) suggestedType,
      ...adjectives,
    ].join(' • ');

    final metaParts = <String>[
      (tile.age ?? '').trim(),
      (tile.sex ?? '').trim(),
      (tile.size ?? '').trim(),
    ].where((e) => e.isNotEmpty).toList();
    final metaLine = metaParts.join(' • ');

    final locationParts = <String>[
      (tile.organizationName ?? '').trim(),
      (tile.cityState ?? '').trim(),
    ].where((e) => e.isNotEmpty).toList();
    final locationLine = locationParts.join(' • ');

    final hasVideo = tile.hasVideos ?? false;

    final String? photoSubtitle = sortByRecent
        ? _formatUpdatedDate(tile.updatedDate)
        : (tile.distanceMiles != null
            ? '${tile.distanceMiles!.toStringAsFixed(1)} mi'
            : null);

    return VisibilityDetector(
      key: Key('ranked_video_${tile.id ?? ''}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.92 &&
            hasVideo &&
            onVideoBadgeFirstSeen != null &&
            tile.id != null &&
            tile.id!.isNotEmpty) {
          onVideoBadgeFirstSeen!(tile.id!);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 110,
                              height: 96,
                              child: _hasImage
                                  ? CachedNetworkImage(
                                      imageUrl: tile.smallPicture!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppTheme.deepPurple.withOpacity(0.12),
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: AppTheme.deepPurple.withOpacity(0.12),
                                        child: const Center(
                                          child: Icon(Icons.pets, color: AppTheme.deepPurple, size: 34),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: AppTheme.deepPurple.withOpacity(0.12),
                                      child: const Center(
                                        child: Icon(Icons.pets, color: AppTheme.deepPurple, size: 34),
                                      ),
                                    ),
                            ),
                          ),

                          // Save icon: no circle; outline heart in white, filled heart in solid red
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              _isFavorited ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorited ? Colors.red : Colors.white,
                              size: 28,
                            ),
                          ),

                          // Video badge: icon only (no circle)
                          if (hasVideo)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Image.asset(
                                'assets/Icons/video_icon_resized.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                            ),
                        ],
                      ),
                      if (photoSubtitle != null && photoSubtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            photoSubtitle,
                            style: TextStyle(
                              color: AppTheme.deepPurple.withOpacity(0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.deepPurple,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (matchLabel != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldBase.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppTheme.goldBase.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  matchLabel,
                                  style: TextStyle(
                                    color: AppTheme.deepPurple,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (breed.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 8),
                            child: Text(
                              breed,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.deepPurple.withOpacity(0.75),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        if (standoutLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              standoutLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.deepPurple.withOpacity(0.9),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),

                        if (metaLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              metaLine,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),

                        if (locationLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              locationLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

