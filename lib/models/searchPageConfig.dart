import 'breed.dart';

enum CatClassification {
  saves,
  breed,
  zipCode,
  sort,
  admin,
  compatibility,
  personality,
  physical,
  basic
}

enum FilterType { simple, advanced, fit }

class filterOption {
  String name;
  dynamic choosenValue;
  String fieldName;
  bool display;
  bool list;
  CatClassification classification;
  int sequence;
  List<listOption> options;
  List<int> choosenListValues;
  bool imported;
  FilterType filterType;

  /// If non-null, this filter can appear in the status chip bar. Higher = higher priority.
  int? statusPriority;
  /// Group key for combining chips (e.g. "location" => zip + distance as one chip).
  String? statusGroup;
  /// Optional label for the chip instead of deriving from filter value.
  String? statusLabelOverride;

  /// When true, this filter is rendered as a slider (e.g. personality traits).
  bool slider;

  filterOption(
      this.name,
      this.choosenValue,
      this.fieldName,
      this.display,
      this.list,
      this.classification,
      this.sequence,
      this.options,
      this.choosenListValues,
      this.imported,
      this.filterType, {
    this.statusPriority,
    this.statusGroup,
    this.statusLabelOverride,
    this.slider = false,
  });
}

/// State for the "Match Style" chip (preset name, Custom, or Not set).
class MatchStyleState {
  final String displayLabel;
  final bool isSet;

  const MatchStyleState._(this.displayLabel, this.isSet);

  /// No match style selected; chip is omitted.
  static const MatchStyleState notSet = MatchStyleState._('Not set', false);
  /// User customized filters; chip shows "🎯 Custom".
  static const MatchStyleState custom = MatchStyleState._('🎯 Custom', true);
  /// Preset selected; chip shows e.g. "🎯 Private Thinker".
  static MatchStyleState preset(String name) =>
      MatchStyleState._('🎯 $name', true);
}

/// Model for one status chip (label, sort order, optional group, tap action).
class ChipModel {
  final String label;
  final int priority;
  final String? group;
  final void Function()? onTap;

  const ChipModel({
    required this.label,
    required this.priority,
    this.group,
    this.onTap,
  });
}

class listOption {
  String displayName;
  dynamic search;
  int value;
  List<String> searchTerms;

  listOption(this.displayName, this.search, this.value,
      {List<String>? searchTerms})
      : searchTerms = searchTerms ?? const [];
}

/// Returns true if the filter has a non-default, active value (should count toward chips).
bool isFilterActive(filterOption f) {
  // Multi-select list (e.g. breeds): active only if at least one real option selected (not Any/Change)
  if (f.list && f.choosenListValues.isNotEmpty) {
    final anyValues = <int>{};
    for (final o in f.options) {
      if (_isAnyOption(o) || o.displayName == 'Change...') anyValues.add(o.value);
    }
    final hasNonAny = f.choosenListValues.any((v) => !anyValues.contains(v));
    if (!hasNonAny) return false;
    return true;
  }

  final v = f.choosenValue;
  if (v == null || (v is String && v.trim().isEmpty)) return false;

  final s = v.toString().trim();
  // List/single-select: "Any" or "Any Type" = inactive
  if (s.equalsIgnoreCase('Any') || s.equalsIgnoreCase('Any Type')) return false;

  // Boolean-style (Yes/No/Any): if options contain "Any", treat that as inactive
  if (f.options.isNotEmpty) {
    try {
      final anyOpt = f.options.firstWhere((listOption o) => _isAnyOption(o));
      final anySearch = anyOpt.search?.toString().trim() ?? '';
      if (s.equalsIgnoreCase(anySearch)) return false;
    } catch (_) {}
  }

  return true;
}

bool _isAnyOption(listOption o) {
  if (o.displayName == 'Any') return true;
  final search = o.search?.toString().trim().toLowerCase() ?? '';
  return search == 'any' || search == 'any type';
}

extension _StringEquals on String {
  bool equalsIgnoreCase(String other) =>
      toLowerCase() == other.toLowerCase();
}

/// Builds status chips for the search screen: active filters with statusPriority set,
/// optional Match Style chip, grouped by statusGroup, sorted by priority, capped at maxChips.
List<ChipModel> buildStatusChips({
  required List<filterOption> filters,
  required MatchStyleState matchStyle,
  int maxChips = 4,
  void Function()? onMoreTap,
}) {
  final List<ChipModel> result = [];
  final active = filters.where((f) => isFilterActive(f) && f.statusPriority != null).toList();
  final Map<String, List<filterOption>> byGroup = {};

  for (final f in active) {
    final group = f.statusGroup;
    if (group != null && group.isNotEmpty) {
      byGroup.putIfAbsent(group, () => []).add(f);
    } else {
      byGroup.putIfAbsent(f.name, () => []).add(f);
    }
  }

  // Build one chip per group (or single filter)
  for (final entry in byGroup.entries) {
    final groupKey = entry.key;
    final groupFilters = entry.value;
    final priority = groupFilters.map((f) => f.statusPriority!).reduce((a, b) => a > b ? a : b);
    String label;
    if (groupKey == 'location') {
      filterOption? zipFilter;
      filterOption? distFilter;
      for (final f in groupFilters) {
        if (f.fieldName == 'zipCode') zipFilter = f;
        if (f.fieldName == 'distance') distFilter = f;
      }
      final zipVal = zipFilter?.choosenValue?.toString().trim();
      final distVal = distFilter?.choosenValue?.toString().trim();
      final hasZip = zipVal != null && zipVal.isNotEmpty && !zipVal.equalsIgnoreCase('Any');
      final hasDist = distVal != null && distVal.isNotEmpty && !distVal.equalsIgnoreCase('Any');
      final parts = <String>[];
      if (hasZip) parts.add(zipVal!);
      if (hasDist) parts.add('$distVal mi');
      label = parts.isEmpty ? '📍 Location' : '📍 ${parts.join(' · ')}';
    } else {
      final f = groupFilters.first;
      final override = f.statusLabelOverride;
      if (override != null && override.isNotEmpty) {
        // Ensure every chip with statusPriority has an emoji
        label = '${_emojiForFilter(f)} $override';
      } else {
        label = _chipLabelForFilter(f);
      }
    }
    result.add(ChipModel(
      label: label,
      priority: priority,
      group: groupKey,
    ));
  }

  // Match Style chip (priority 100)
  if (matchStyle.isSet) {
    result.add(ChipModel(label: matchStyle.displayLabel, priority: 100, onTap: null));
  }

  result.sort((a, b) {
    final cmp = b.priority.compareTo(a.priority);
    if (cmp != 0) return cmp;
    return a.label.compareTo(b.label);
  });

  final showMore = result.length > maxChips;
  final visible = showMore ? result.take(maxChips - 1).toList() : result;
  if (showMore) {
    final n = result.length - (maxChips - 1);
    visible.add(ChipModel(
      label: '+$n more',
      priority: 0,
      onTap: onMoreTap,
    ));
  }
  return visible;
}

String _chipLabelForFilter(filterOption f) {
  final emoji = _emojiForFilter(f);
  if (f.list && f.choosenListValues.isNotEmpty) {
    final opts = f.options.where((o) => f.choosenListValues.contains(o.value)).toList();
    // Breed chip: show first chosen breed name, then " +" if more than one
    if (f.fieldName == 'animals.breedPrimaryId') {
      final firstVal = f.choosenListValues.first;
      if (firstVal == 0) return '$emoji ${f.name}'; // "Any" or placeholder
      String? firstName;
      if (opts.isNotEmpty) {
        try {
          firstName = opts.firstWhere((o) => o.value == firstVal).displayName;
        } catch (_) {
          firstName = _breedNameByIdOrRid(firstVal);
        }
      } else {
        firstName = _breedNameByIdOrRid(firstVal);
      }
      if (firstName == null) return '$emoji ${f.name}';
      return f.choosenListValues.length > 1 ? '$emoji $firstName +' : '$emoji $firstName';
    }
    if (opts.isEmpty) return '$emoji ${f.name}';
    final names = opts.map((o) => o.displayName).join(', ');
    return '$emoji $names';
  }
  final v = f.choosenValue?.toString().trim() ?? '';
  if (v.isEmpty) return '$emoji ${f.name}';
  listOption? match;
  for (final o in f.options) {
    if (o.search?.toString().trim() == v) {
      match = o;
      break;
    }
  }
  final display = match?.displayName ?? v;
  return '$emoji $display';
}

String _emojiForFilter(filterOption f) {
  if (f.fieldName == 'zipCode' || f.statusGroup == 'location') return '📍';
  if (f.fieldName == 'animals.breedPrimaryId') return '🐱';
  if (f.fieldName == 'animals.ageGroup') return '📅';
  if (f.fieldName == 'animals.sex') return '⚥';
  if (f.fieldName == 'animals.indoorOutdoor') return '🏠';
  if (f.fieldName == 'animals.isDogsOk' || f.fieldName == 'animals.isCatsOk' || f.fieldName == 'animals.isKidsOk') return '🐾';
  if (f.fieldName == 'animals.isSpecialNeeds') return '❤️';
  return '🔖';
}

/// Look up breed name by id or rid (choosenListValues may store either depending on screen).
String? _breedNameByIdOrRid(int value) {
  try {
    final b = breeds.firstWhere((b) => b.id == value || b.rid == value);
    return b.name;
  } catch (_) {
    return null;
  }
}

/// Optional persistent copy of filter options (e.g. after loading a saved search).
/// When non-empty, adopt grid and other consumers can use this instead of [filteringOptions].
List<filterOption> persistentFilteringOptions = [];

List<filterOption> filteringOptions = [
  filterOption(
    "Save",
    "",
    "Save",
    true,
    false,
    CatClassification.saves,
    1,
    [], 
    [], 
    false,
    FilterType.simple
  ),
  filterOption(
      "Breed",
      "",
      "animals.breedPrimaryId",
      true,
      true,
      CatClassification.breed,
      2,
      [listOption("Change...", "Change", 0)],
      [],
      false,
      FilterType.simple,
      statusPriority: 90,
  ),
  filterOption(
      "Sort By",
      "distance",
      "sortBy",
      false,
      false,
      CatClassification.sort,
      3,
      [
        listOption("Most Recent", "date", 1),
        listOption("Distance", "distance", 0)
      ],
      [],
      false,
      FilterType.advanced
  ),
  filterOption(
    "Zip Code",
    "",
    "zipCode",
    true,
    false,
    CatClassification.sort,
    4,
    [],
    [],
    false,
    FilterType.advanced,
  ),
  filterOption(
      "Distance",
      "",
      "distance",
      false,
      false,
      CatClassification.sort,
      5,
      [
        listOption("5", "5", 0),
        listOption("20", "20", 1),
        listOption("50", "50", 2),
        listOption("100", "100", 3),
        listOption("200", "200", 4),
        listOption("Any", "Any", 5)
      ],
      [],
      false,
      FilterType.advanced,
  ),
  filterOption(
      "Updated Since",
      "",
      "animals.updatedDate",
      false,
      false,
      CatClassification.sort,
      6,
      [
        listOption("Day", "Day", 0),
        listOption("Week", "Week", 1),
        listOption("Month", "Month", 2),
        listOption("Year", "Year", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced
  ),
  //Basic
  filterOption(
      "Size",
      "",
      "animals.sizeGroup",
      true,
      true,
      CatClassification.basic,
      7,
      [
        listOption("Small", "Small", 0),
        listOption("Medium", "Medium", 1),
        listOption("Large", "Large", 2),
        listOption("X-Large", "X-Large", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.simple
  ),
  filterOption(
      "Age",
      "",
      "animals.ageGroup",
      true,
      true,
      CatClassification.basic,
      8,
      [
        listOption("Kitten", "Baby", 0),
        listOption("Young", "Young", 1),
        listOption("Adult", "Adult", 2),
        listOption("Senior", "Senior", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.simple,
      statusPriority: 85,
  ),
  filterOption(
      "Sex",
      "",
      "animals.sex",
      true,
      false,
      CatClassification.basic,
      9,
      [
        listOption("Male", "Male", 0),
        listOption("Female", "Female", 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.simple,
      statusPriority: 80,
  ),
  filterOption(
      "Coat Length",
      "",
      "animals.coatLength",
      false,
      true,
      CatClassification.basic,
      10,
      [
        listOption("Short", "Short", 0),
        listOption("Medium", "Medium", 1),
        listOption("Long", "Long", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced
  ),
  filterOption(
       "Current on vaccations",
       "",
       "animals.isCurrentVaccinations",
       false,
       false,
       CatClassification.admin,
       11,
       [
         listOption("Yes", true, 0),
         listOption("No", false, 1),
         listOption("Any", "", 2)
       ],
       [],
       false,
       FilterType.advanced
  ),
  filterOption(
      "In/Outdoor",
      "",
      "animals.indoorOutdoor",
      true,
      false,
      CatClassification.compatibility,
      12,
      [
        listOption("Indoor", "Indoor Only", 0),
        listOption("Both", "Indoor/Outdoor", 1),
        listOption("Outdoor", "Outdoor Only", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.simple,
      statusPriority: 70,
  ),
  filterOption(
      "Apartment OK",
      "",
      "animals.isYardRequired",
      true,
      false,
      CatClassification.compatibility,
      12,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.simple,
      statusPriority: 70,
  ),
  filterOption(
      "OK with dogs",
      "",
      "animals.isDogsOk",
      true,
      false,
      CatClassification.compatibility,
      13,
      [
        listOption("Yes", true, 0),
        listOption("No",  false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.simple,
      statusPriority: 67,
  ),
  filterOption(
      "OK with cats",
      "",
      "animals.isCatsOk",
      true,
      false,
      CatClassification.compatibility,
      14,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.simple,
      statusPriority: 66,
  ),
  filterOption(
    "Companion Cat?",
    "",
    "animals.NeedsCompanionAnimal",
    false,
    false, 
    CatClassification.compatibility,
    15,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)],
    [],
    false,
    FilterType.advanced
  ),
  filterOption(
       "Adults",
       "",
       "animals.adultSexesOk",
       false,
       false,
       CatClassification.compatibility,
       16,
       [
         listOption("All", "All", 0),
         listOption("Men", "Men Only", 1),
         listOption("Women", "Women Only", 2),
         listOption("Any", "Any", 3)
       ],
       [],
       false,
       FilterType.advanced
  ),
  filterOption(
      "OK with kids",
      "",
      "animals.isKidsOk",
      true,
      false,
      CatClassification.compatibility,
      17,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.simple,
      statusPriority: 65,
  ),
  //Personality
  filterOption(
      "Energy Level",
      "",
      "energyLevel",
      true,
      true,
      CatClassification.personality,
      18,
      [
        listOption("Any", "0", 0),
        listOption("Very Low", "1", 1),
        listOption("Low", "2", 2),
        listOption("Medium", "3", 3),
        listOption("High", "4", 4),
        listOption("Very High", "5", 5),
      ],
      [0],
      false,
      FilterType.advanced,
      slider: true
  ),
  filterOption(
    "Playfulness",
    "",
    "playfulness", 
    true,
    true, 
    CatClassification.personality,
    19,
    [
      listOption("Any", "0", 0),
      listOption("Very Low", "1", 1),
      listOption("Low", "2", 2),
      listOption("Medium", "3", 3),
      listOption("High", "4", 4),
      listOption("Very High", "5", 5),
    ],
    [0],
    false,
    FilterType.advanced,
    slider: true
  ),
  filterOption(
      "Affectionate",
      "",
      "affectionate",
      true,
      true,
      CatClassification.personality,
      20,
      [
        listOption("Any", "0", 0),
        listOption("Very Low", "1", 1),
        listOption("Low", "2", 2),
        listOption("Medium", "3", 3),
        listOption("High", "4", 4),
        listOption("Very High", "5", 5),
      ],
      [0],
      false,
      FilterType.advanced,
      slider: true,
  ),
  filterOption(
    "Independence",
    "",
    "independence",
    true,
    true, 
    CatClassification.personality,
    21,
    [
      listOption("Any", "0", 0),
      listOption("Very Independent", "1", 1),
      listOption("Independent", "2", 2),
      listOption("Balanced", "3", 3),
      listOption("Somewhat Dependent", "4", 4),
      listOption("Very Dependent", "5", 5),
    ],
    [0],
    false,
    FilterType.advanced,
    slider: true,
  ),
  filterOption(
    "Sociability",
    "",
    "sociability",
    true,
    true, 
    CatClassification.personality,
    22,
    [
      listOption("Any", "0", 0),
      listOption("Very Unsocial", "1", 1),
      listOption("Unsocial", "2", 2),
      listOption("Moderate", "3", 3),
      listOption("Social", "4", 4),
      listOption("Very Social", "5", 5),
    ],
    [0],
    false,
    FilterType.advanced,
    slider: true,
  ),
  filterOption(
       "Vocalization",
       "",
       "vocalLevel",
       true,
       true,
       CatClassification.personality,
       24,
       [
         listOption("Any", "0", 0),
         listOption("Very Quiet", "1", 1),
         listOption("Quiet", "2", 2),
         listOption("Moderate", "3", 3),
         listOption("Talkative", "4", 4),
         listOption("Very Talkative", "5", 5),
       ],
       [0],
       false,
       FilterType.advanced,
       slider: true
  ),
  filterOption(
    "Confidence",
    "",
    "confidence",
    true,
    true,
    CatClassification.personality,
    25,
    [
      listOption("Any", "0", 0),
      listOption("Very Unconfident", "1", 1),
      listOption("Unconfident", "2", 2),
      listOption("Moderate", "3", 3),
      listOption("Confident", "4", 4),
      listOption("Very Confident", "5", 5),
    ],
    [0],
    false,
    FilterType.advanced,
    slider: true
  ),  
  filterOption(
    "Sensitivity",
    "",
    "sensitivity",
    true,
    true,
    CatClassification.personality,
    26,
    [
      listOption("Any", "0", 0),
      listOption("Very Unsensitive", "1", 1),
      listOption("Unsensitive", "2", 2),
      listOption("Moderate", "3", 3),
      listOption("Sensitive", "4", 4),
      listOption("Very Sensitive", "5", 5),
    ],
    [0],
    false,
    FilterType.advanced,
    slider: true
  ),
  filterOption(
    "Adaptability",
    "",
    "adaptability",
    true,
    true,
    CatClassification.personality,
    27,
    [
      listOption("Any", "0", 0),
      listOption("Very Unadaptable", "1", 1),
      listOption("Unadaptable", "2", 2),
      listOption("Moderate", "3", 3),
      listOption("Adaptable", "4", 4),
      listOption("Very Adaptable", "5", 5),
    ],
    [0],
    false,
    FilterType.advanced,
    slider: true
  ),
  filterOption(
    "Intelligence",
    "",
    "intelligence",
    true,
    true,
    CatClassification.personality,
    28,
    [
      listOption("Any", "0", 0),
      listOption("Dim", "1", 1),
      listOption("Below Average", "2", 2),
      listOption("Average", "3", 3),
      listOption("Above Average", "4", 4),
      listOption("Bright", "5", 5),
    ],
    [0],
    false,
    FilterType.advanced,
    slider: true
  ),
  filterOption(
    "New People",
    "",
    "animals.newPeopleReaction",
    false,
    true,
    CatClassification.personality,
    29,
    [
      listOption("Cautious", "Cautious", 1),
      listOption("Friendly", "Friendly", 2),
      listOption("Protective", "Protective", 3),
      listOption("Aggressive", "Aggressive", 4),
      listOption("Any", "", 5),
    ],
    [0],
    false,
    FilterType.advanced
  ),
  filterOption(
    "Calmness",
    "Any",
    "animals.descriptionText",
    true,
    false,
    CatClassification.personality,
    28,
    [
      listOption("Yes", "Yes", 2, searchTerms: [
        'calm',
        'calmness',
        'quiet',
        'relaxed',
        'laid back',
        'mellow',
        'easygoing',
      ]),
      listOption("No", "No", 1, searchTerms: [
        'active',
        'energetic',
        'high energy',
        'hyper',
        'rambunctious',
        'rowdy',
        'wild',
        'busy',
      ]),
      listOption("Any", "Any", 0),
    ],
    [0],
    false,
    FilterType.advanced,
  ),
  filterOption(
    "Gentleness",
    "Any",
    "animals.descriptionText",
    true,
    false,
    CatClassification.personality,
    29,
    [
      listOption("Yes", "Yes", 2, searchTerms: [
        'gentle',
        'gentleness',
        'soft',
        'sweet',
        'mild',
        'kind',
        'gentle nature',
        'gentle cat',
      ]),
      listOption("No", "No", 1, searchTerms: [
        'feisty',
        'spicy',
        'rough',
        'rowdy',
        'boisterous',
        'assertive',
        'intense',
        'scrappy',
      ]),
      listOption("Any", "Any", 0),
    ],
    [0],
    false,
    FilterType.advanced,
  ),
  filterOption(
    "Lap Cat",
    "Any",
    "animals.descriptionText",
    true,
    false,
    CatClassification.personality,
    30,
    [
      listOption("Yes", "Yes", 2, searchTerms: [
        'lap',
        'lap lover',
        'lap cat',
        'lapcat',
        'cuddly',
        'snuggly',
        'loves laps',
        'on your lap',
        'affectionate',
      ]),
      listOption("No", "No", 1, searchTerms: [
        'independent',
        'aloof',
        'not a lap cat',
        'not cuddly',
        'not affectionate',
        'keeps to self',
        'prefers space',
        'not snuggly',
      ]),
      listOption("Any", "Any", 0),
    ],
    [0],
    false,
    FilterType.advanced,
  ),
  filterOption(
    "Likes toys",
    "Any",
    "animals.descriptionText",
    true,
    false,
    CatClassification.personality,
    31,
    [
      listOption("Yes", "Yes", 2, searchTerms: [
        'likes toys',
        'playful',
        'toys',
        'loves toys',
        'playfulness',
        'enjoys play',
      ]),
      listOption("No", "No", 1, searchTerms: [
        'not playful',
        'low play',
        'ignores toys',
        'uninterested in toys',
        'laid back',
        'couch potato',
        'sedate',
        'lazy',
      ]),
      listOption("Any", "Any", 0),
    ],
    [0],
    false,
    FilterType.advanced,
  ),
  filterOption(
    "Timid / shy",
    "Any",
    "animals.descriptionText",
    true,
    false,
    CatClassification.personality,
    32,
    [
      listOption("Yes", "Yes", 2, searchTerms: [
        'timid',
        'shy',
        'cautious',
        'reserved',
        'skittish',
        'nervous',
        'fearful',
        'hesitant',
      ]),
      listOption("No", "No", 1, searchTerms: [
        'outgoing',
        'confident',
        'social',
        'friendly',
        'bold',
        'brave',
        'fearless',
        'gregarious',
      ]),
      listOption("Any", "Any", 0),
    ],
    [0],
    false,
    FilterType.advanced,
  ),
  filterOption(
    "Curious",
    "Any",
    "animals.descriptionText",
    true,
    false,
    CatClassification.personality,
    33,
    [
      listOption("Yes", "Yes", 2, searchTerms: [
        'curious',
        'exploratory',
        'explores',
        'mischievous',
        'inquisitive',
        'gets into things',
        'adventurous',
      ]),
      listOption("No", "No", 1, searchTerms: [
        'laid back',
        'low-key',
        'mellow',
        'reserved',
        'homebody',
        'content to lounge',
        'not curious',
        'uninterested',
      ]),
      listOption("Any", "Any", 0),
    ],
    [0],
    false,
    FilterType.advanced,
  ),
  filterOption(
    "Outgoing",
    "Any",
    "animals.descriptionText",
    true,
    false,
    CatClassification.personality,
    34,
    [
      listOption("Yes", "Yes", 1, searchTerms: [
        'outgoing',
        'friendly',
        'social',
        'sociable',
        'socialized',
        'socializing',
      ]),
      listOption("No", "No", 2, searchTerms: [
        'shy',
        'reserved',
        'withdrawn',
      ]),
      listOption("Any", "Any", 0),
    ],
    [0],
    false,
    FilterType.advanced,
  ),
  //physical
  filterOption(
       "Housetrained",
       "",
       "animals.isHousetrained",
       false,
       false,
       CatClassification.physical,
       34,
       [
         listOption("Yes", true, 0),
         listOption("No", false, 1),
         listOption("Any", "", 2)
       ],
       [],
       false,
       FilterType.advanced
  ),
  filterOption(
      "Color",
      "",
      "animals.colorDetails",
      false,
      true,
      CatClassification.physical,
      34,
      [
        listOption("Black", "Black", 0),
        listOption("Gray", "Gray", 2),
        listOption("Brown/Choc", "Brown or Chocolate", 3),
        listOption("B&W", "Black and White", 4),
        listOption("Blue", "Blue", 6),
        listOption("Salt & Pep", "Salt & Pepper", 7),
        listOption("Cream", "Cream", 8),
        listOption("Ivory", "Ivory", 9),
        listOption("Red", "Red Tabby", 10),
        listOption("Spotted Tabby/Leopard Spotted",
            "Spotted Tabby/Leopard Spotted", 11),
        listOption("Tan", "Tan", 12),
        listOption("Fawn", "Fawn", 13),
        listOption("White", "White", 15),
        listOption("Any", "Any", 16)
      ],
      [],
      false,
      FilterType.advanced
  ),
  filterOption(
      "Eye color",
      "",
      "animals.eyeColor",
      false,
      true,
      CatClassification.physical,
      35,
      [
        listOption("Black", "Black", 0),
        listOption("Blue", "Blue", 1),
        listOption("Blue-brown", "Blue-brown", 2),
        listOption("Brown", "Brown", 3),
        listOption("Copper", "Copper", 4),
        listOption("Gold", "Gold", 5),
        listOption("Gray", "Gray", 6),
        listOption("Green", "Green", 7),
        listOption("Hazlenut", "Hazlenut", 8),
        listOption("Mixed", "Mixed", 9),
        listOption("Pink", "Pink", 10),
        listOption("Yellow", "Yellow", 11),
        listOption("Any", "Any", 12)
      ],
      [],
      false,
      FilterType.advanced
  ),
  filterOption(
      "Grooming needs",
      "",
      "animals.groomingNeeds",
      false,
      true,
      CatClassification.physical,
      36,
      [
        listOption("Not Req", "Not Required", 0),
        listOption("Low", "Low", 1),
        listOption("Medium", "Moderate", 2),
        listOption("High", "High", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced
  ),
  filterOption(
      "Shedding amount",
      "",
      "animals.sheddingLevel",
      false,
      true,
      CatClassification.physical,
      37,
      [
        listOption("Some", "Moderate", 0),
        listOption("None", "None", 1),
        listOption("High", "High", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced
  ),
  filterOption(
      "Altered",
      "",
      "animals.isAltered",
      true,
      false,
      CatClassification.physical,
      38,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.simple
  ),
  filterOption(
      "Microchipped",
      "",
      "animals.isMicrochipped",
      false,
      false,
      CatClassification.physical,
      39,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.advanced
  ),
  filterOption(
      "Mixed breed",
      "",
      "animals.isBreedMixed",
      false,
      false,
      CatClassification.physical,
      40,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.simple
  ),
  filterOption(
      "Has special needs",
      "",
      "animals.isSpecialNeeds",
      false,
      false,
      CatClassification.physical,
      41,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "", 2)
      ],
      [],
      false,
      FilterType.advanced,
      statusPriority: 60,
  )
];