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

enum FilterType { simple, advanced }

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
  List<String> synonyms;

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
    List<String>? synonyms,
  }) : synonyms = synonyms ?? const [];
}

class listOption {
  String displayName;
  dynamic search;
  int value;

  listOption(this.displayName, this.search, this.value);
}

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
      FilterType.simple
  ),
  filterOption(
      "Sort By",
      "",
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
    FilterType.advanced
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
      FilterType.advanced
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
      FilterType.simple
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
      FilterType.simple
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
         listOption("Yes", "Yes", 0),
         listOption("No", "No", 1),
         listOption("Any", "Any", 2)
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
      FilterType.simple
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
        listOption("Yes", "Yes", 0),
        listOption("No", "No", 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.simple
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
        listOption("Yes", "Yes", 0),
        listOption("No", "No", 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.simple
  ),
  filterOption(
       "Adults",
       "",
       "animals.adultSexesOk",
       false,
       false,
       CatClassification.compatibility,
       15,
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
      16,
      [
        listOption("Yes", "Yes", 0),
        listOption("No", "No", 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.simple
  ),
  //Personality
   filterOption(
       "New People",
       "",
       "animals.newPeopleReaction",
       false,
       true,
       CatClassification.personality,
       17,
       [
         listOption("Cautious", "Cautious", 0),
         listOption("Friendly", "Friendly", 1),
         listOption("Protective", "Protective", 2),
         listOption("Aggressive", "Aggressive", 3),
         listOption("Any", "Any", 4)
       ],
       [],
       false,
       FilterType.advanced
  ),
  filterOption(
      "Activity Level",
      "",
      "animals.activityLevel",
      true,
      true,
      CatClassification.personality,
      18,
      [
        listOption("None", "Not Active", 0),
        listOption("Low", "Slightly Active", 1),
        listOption("Medium", "Moderately Active", 2),
        listOption("High", "Highly Active", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.simple
  ),
  filterOption(
      "Energy level",
      "",
      "animals.energyLevel",
      true,
      true,
      CatClassification.personality,
      19,
      [
        listOption("Low", "Low", 0),
        listOption("Medium", "Moderate", 1),
        listOption("High", "High", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.simple
  ),
  filterOption(
       "Likes to vocalize",
       "animals.vocalLevel",
       false,
       true,
       CatClassification.personality,
       20,
       [
         listOption("Quiet", "Quiet", 0),
         listOption("Some", "Some", 1),
         listOption("Lots", "Lots", 2),
         listOption("Any", "Any", 3)
       ],
       [],
       false,
       FilterType.advanced
  ),
  filterOption(
      "Affectionate",
      "animals.description",
      true,
      false,
      CatClassification.personality,
      21,
      [
        listOption("Yes", "Yes", 0),
        listOption("Any", "Any", 1)
      ],
      [],
      false,
      FilterType.simple,
      ['affectionate', 'loving', 'cuddly', 'snuggly', 'friendly', 'devoted', 'social', 'socialable', 'socializable', 'socialize', 'socialized', 'socializing', 'socialized', 'socializing']
  ),
  filterOption(
    "Even-tempered",
    ""
    "animals.eventempered", 
    false,
    true,
    CatClassification.personality,
    22,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false, 
    FilterType.advanced
  )
  filterOption(
       "Housetrained",
       "",
       "animals.isHousetrained",
       false,
       false,
       CatClassification.personality,
       23,
       [
         listOption("Yes", "Yes", 0),
         listOption("No", "No", 1),
         listOption("Any", "Any", 2)
       ],
       [],
       false,
       FilterType.advanced
  ),
  filterOption(
    "Independent/aloof",
    "",
    "animals.description",
    false,
    false, 
    CatClassification.personality,
    24,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false, 
    FilterType.advanced,
    ['independent', 'aloof', 'standoffish', 'distant', 'unfriendly', 'unapproachable', 'uncommunicative', 'unfriendly', 'unapproachable', 'uncommunicative']
  ),
  filterOption(
    "Calmness",
    "", 
    "animals.description", 
    false,
    false,
    CatClassification.personality,
    25, 
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false, 
    FilterType.advanced,
    ['calm', 'quiet', 'laid back', 'relaxed']
  ),  
  filterOption(
    "Gentleness", 
    "",
    "animals.description",
    false,
    false,
    CatClassification.personality,
    26,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false, 
    FilterType.advanced,
    ['gentle', 'gentleness', 'soft', 'sweet', 'mild', 'kind']
  ),
  filterOption(
    "Lap Cat",
    "", 
    "animals.description",
    false,
    false,
    CatClassification.personality,
    27,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false,
    FilterType.advanced,
    ['lap cat', 'on your lap', 'loves laps']
  ),
  filterOption(
    "Companion Cat?",
    "",
    "animals.NeedsCompanionAnimal",
    false,
    false, 
    CatClassification.personality,
    28,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false,
    FilterType.advanced,
    ['companion cat', 'needs companion', 'wants companion', 'wants company']
  ),
  filterOption(
    "Playful",
    "", 
    "animals.description", 
    false,
    false, 
    CatClassification.personality,
    29,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false,
    FilterType.advanced,
    ['playful', 'energetic', 'lively', 'active', 'pounces', 'toys', 'zoomies']
  ),
  filterOption(
    "Likes toys",
    "", 
    "animals.description", 
    false,
    false, 
    CatClassification.personality,
    30,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false, 
    FilterType.advanced,
    ['toys', 'plays with toys', 'chews toys', 'loves toys']
  ),
  filterOption(
    "Timid / shy",
    "",
    "animals.description", 
    false,
    false,
    CatClassification.personality,
    31,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false,
    FilterType.advanced,
    ['shy', 'timid', 'fearful', 'reserved', 'skittish', 'nervous', 'hesitant']
  ),
  filterOption(
    "outgoing",
    "",
    "animals.description", 
    false,
    false,
    CatClassification.personality,
    32,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false,
    FilterType.advanced
    ['outgoing', 'friendly', 'social', 'socialable', 'socializable', 'socialize', 'socialized', 'socializing']
  ),
  filterOption(
    "mischievous",
    "",
    "animals.description", 
    false,
    false,
    CatClassification.personality,
    33,
    [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][],
    [],
    false,
    FilterType.advanced
    ['mischievous', 'curious', 'explores', 'gets into things', 'trouble']
  ),
  //physical
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
        listOption("Brown Tabby", "Brown Tabby", 1),
        listOption("Gray", "Gray", 2),
        listOption("Brown/Choc", "Brown or Chocolate", 3),
        listOption("B&W", "Black and White", 4),
        listOption("Tuxedo", "Tuxedo", 5),
        listOption("Blue", "Blue", 6),
        listOption("Salt & Pep", "Salt & Pepper", 7),
        listOption("Cream", "Cream", 8),
        listOption("Ivory", "Ivory", 9),
        listOption(
            "Gray Blue or Silver Tabby", "Gray Blue or Silver Tabby", 10),
        listOption("Red Tabby", "Red Tabby", 10),
        listOption("Spotted Tabby/Leopard Spotted",
            "Spotted Tabby/Leopard Spotted", 11),
        listOption("Tan", "Tan", 12),
        listOption("Fawn", "Fawn", 13),
        listOption("Tortoiseshell", "Tortoiseshell", 14),
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
        listOption("Any", "Any", 2)
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
        listOption("Any", "Any", 2)
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
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced
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
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced
  )
];