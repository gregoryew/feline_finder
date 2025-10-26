
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
      this.filterType);
}

class listOption {
  String displayName;
  dynamic search;
  int value;

  listOption(this.displayName, this.search, this.value);
}

List<filterOption> persistentFilteringOptions = [];

List<filterOption> filteringOptions = [
  filterOption("Save", "Save", "Save", true, false, CatClassification.saves, 1,
      [listOption("New...", "New", 0)], [], false, FilterType.simple),
  filterOption(
      "Breed",
      "",
      "animals.breedPrimaryId",
      true,
      true,
      CatClassification.breed,
      1,
      [listOption("Change...", "Change", 0)],
      [],
      false,
      FilterType.simple),
/*
  filterOption("Zip Code", "ZipCode", "ZipCode", true, false,
      CatClassification.zipCode, 1, [], [], false, FilterType.simple),
*/
  filterOption(
      "Sort By",
      "",
      "sortBy",
      false,
      false,
      CatClassification.sort,
      2,
      [
        listOption("Most Recent", "date", 1),
        listOption("Distance", "distance", 0)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Distance",
      "",
      "distance",
      false,
      false,
      CatClassification.sort,
      3,
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
      FilterType.advanced),
  filterOption(
      "Updated Since",
      "",
      "animals.updatedDate",
      false,
      false,
      CatClassification.sort,
      4,
      [
        listOption("Day", "Day", 0),
        listOption("Week", "Week", 1),
        listOption("Month", "Month", 2),
        listOption("Year", "Year", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced),
  /*
  filterOption(
      "While Your Away",
      "",
      "While Your Away",
      false,
      false,
      CatClassification.sort,
      5,
      [listOption("Search", "Search", 1), listOption("Don't", "Don't", 0)],
      [],
      false,
      FilterType.advanced),
*/
  //Basic
  filterOption(
      "Size",
      "",
      "animals.sizeGroup",
      true,
      true,
      CatClassification.basic,
      30,
      [
        listOption("Small", "Small", 0),
        listOption("Medium", "Medium", 1),
        listOption("Large", "Large", 2),
        listOption("X-Large", "X-Large", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.simple),
  filterOption(
      "Age",
      "",
      "animals.ageGroup",
      true,
      true,
      CatClassification.basic,
      25,
      [
        listOption("Baby", "Baby", 0),
        listOption("Young", "Young", 1),
        listOption("Adult", "Adult", 2),
        listOption("Senior", "Senior", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.simple),
  filterOption(
      "Sex",
      "",
      "animals.sex",
      true,
      false,
      CatClassification.basic,
      31,
      [
        listOption("Male", "Male", 0),
        listOption("Female", "Female", 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.simple),
  filterOption(
      "Coat Length",
      "",
      "animals.coatLength",
      false,
      true,
      CatClassification.basic,
      32,
      [
        listOption("Short", "Short", 0),
        listOption("Medium", "Medium", 1),
        listOption("Long", "Long", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced),
  //Admin
  filterOption(
      "Adoption pending",
      "",
      "animals.isAdoptionPending",
      false,
      false,
      CatClassification.admin,
      6,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Courtesy Listing",
      "",
      "animals.isCourtesyListing",
      false,
      false,
      CatClassification.admin,
      6,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Found",
      "",
      "animals.isFound",
      false,
      false,
      CatClassification.admin,
      6,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Needs a Foster",
      "",
      "animals.isNeedingFoster",
      false,
      false,
      CatClassification.admin,
      7,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Allow sponsorship",
      "",
      "animals.isSponsorable",
      false,
      false,
      CatClassification.admin,
      8,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Current on vaccations",
      "",
      "animals.isCurrentVaccinations",
      false,
      false,
      CatClassification.admin,
      9,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),

  //compatibiity
  filterOption(
      "Requires a Yard",
      "",
      "animals.isYardRequired",
      false,
      false,
      CatClassification.compatibility,
      10,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "In/Outdoor",
      "",
      "animals.indoorOutdoor",
      false,
      false,
      CatClassification.compatibility,
      11,
      [
        listOption("Indoor", "Indoor Only", 0),
        listOption("Both", "Indoor/Outdoor", 1),
        listOption("Outdoor", "Outdoor Only", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "OK with dogs",
      "",
      "animals.isDogsOk",
      false,
      false,
      CatClassification.compatibility,
      12,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "OK with cats",
      "",
      "animals.isCatsOk",
      false,
      false,
      CatClassification.compatibility,
      13,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Seniors",
      "",
      "animals.isSeniorsOk",
      false,
      false,
      CatClassification.compatibility,
      14,
      [listOption("Yes", true, 0), listOption("Any", "Any", 1)],
      [],
      false,
      FilterType.advanced),
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
      FilterType.advanced),
  filterOption(
      "Farm Animals",
      "",
      "animals.isFarmAnimalsOk",
      false,
      false,
      CatClassification.compatibility,
      16,
      [listOption("Yes", true, 0), listOption("Any", "Any", 1)],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "OK with kids",
      "",
      "animals.isKidsOk",
      false,
      false,
      CatClassification.compatibility,
      17,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Owner experience needed",
      "",
      "animals.ownerExperience",
      false,
      false,
      CatClassification.compatibility,
      18,
      [
        listOption("None", "None", 0),
        listOption("Species", "Species", 1),
        listOption("Breed", "Breed", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Fence Needs",
      "",
      "animals.fenceNeeds",
      false,
      false,
      CatClassification.compatibility,
      18,
      [
        listOption("None", "Not required", 0),
        listOption("Any Type", "Any Type", 1),
        listOption("3 foot", "3 foot", 2),
        listOption("6 foot", "6 foot", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced),

  //Personality
  filterOption(
      "New People",
      "",
      "animals.newPeopleReaction",
      false,
      true,
      CatClassification.personality,
      19,
      [
        listOption("Cautious", "Cautious", 0),
        listOption("Friendly", "Friendly", 1),
        listOption("Protective", "Protective", 2),
        listOption("Aggressive", "Aggressive", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Activity Level",
      "",
      "animals.activityLevel",
      false,
      true,
      CatClassification.personality,
      20,
      [
        listOption("None", "Not Active", 0),
        listOption("Low", "Slightly Active", 1),
        listOption("Medium", "Moderately Active", 2),
        listOption("High", "Highly Active", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Energy level",
      "",
      "animals.energyLevel",
      false,
      true,
      CatClassification.personality,
      21,
      [
        listOption("Low", "Low", 0),
        listOption("Medium", "Moderate", 1),
        listOption("High", "High", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Exercise Needs",
      "",
      "animals.exerciseNeeds",
      false,
      true,
      CatClassification.personality,
      22,
      [
        listOption("Not Req", "Not Required", 0),
        listOption("Low", "Low", 1),
        listOption("Medium", "Moderate", 2),
        listOption("High", "High", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Obedience training",
      "",
      "animals.obedienceTraining",
      false,
      true,
      CatClassification.personality,
      23,
      [
        listOption("Needs", "Needs Training", 0),
        listOption("Basic", "Has Basic Training", 1),
        listOption("Well", "Well Trained", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Likes to vocalize",
      "",
      "animals.vocalLevel",
      false,
      true,
      CatClassification.personality,
      24,
      [
        listOption("Quiet", "Quiet", 0),
        listOption("Some", "Some", 1),
        listOption("Lots", "Lots", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced),
  //filterOption("Affectionate", "animalAffectionate", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)], FilterType.advanced))
  //filterOption("Crate trained", "animalCratetrained", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)], ft: FilterType.advanced))
  //filterOption("Eager to please", "animalEagerToPlease", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Tries to escape", "animalEscapes", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Even-tempered", "animalEventempered", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Likes to fetch", "animalFetches", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Gentle", "animalGentle", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Does well in a car", "animalGoodInCar", false, CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Goofy", "animalGoofy", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  filterOption(
      "Housetrained",
      "",
      "animals.isHousetrained",
      false,
      false,
      CatClassification.personality,
      25,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  //filterOption("Independent/aloof", "animalIndependent", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Intelligent", "animalIntelligent", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Lap pet", "animalLap", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Leash trained", "animalLeashtrained", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Companion Cat?", "animalNeedsCompanionAnimal", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Obedient", "animalObedient", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Playful", "animalPlayful", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Likes toys", "animalPlaysToys", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Predatory", "animalPredatory", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Territorial", "animalProtective", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Likes to swim", "animalSwims", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))
  //filterOption("Timid / shy", "animalTimid", false,  CatClassification.personality, [listOption("Yes","Yes", 0),listOption("Any","Any", 1)][], false, FilterType.advanced))

  //physical
  filterOption(
      "Ear type",
      "",
      "animals.earType",
      false,
      true,
      CatClassification.physical,
      26,
      [
        listOption("Cropped", "Cropped", 0),
        listOption("Droopy", "Droopy", 1),
        listOption("Erect", "Erect", 2),
        listOption("Long", "Long", 3),
        listOption("Missing", "Missing", 4),
        listOption("Notched", "Notched", 5),
        listOption("Rose", "Rose", 6),
        listOption("Semi-erect", "Semi-erect", 7),
        listOption("Tipped", "Tipped", 8),
        listOption("Natural/Uncropped", "Natural/Uncropped", 9),
        listOption("Any", "Any", 10)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Color",
      "",
      "animals.colorDetails",
      false,
      true,
      CatClassification.physical,
      27,
      [
        listOption("Black", "Black", 0),
        listOption("B&W", "Black and White", 1),
        listOption("Tuxedo", "Tuxedo", 2),
        listOption("Blue", "Blue", 3),
        listOption("Salt & Pep", "Salt & Pepper", 4),
        listOption("Brown/Choc", "Brown or Chocolate", 5),
        listOption("Brown Tabby", "Brown Tabby", 6),
        listOption("Calico/Dilute", "Calico or Dilute Calico", 7),
        listOption("Cream", "Cream", 8),
        listOption("Ivory", "Ivory", 9),
        listOption("Gray", "Gray", 10),
        listOption(
            "Gray Blue or Silver Tabby", "Gray Blue or Silver Tabby", 11),
        listOption("Red Tabby", "Red Tabby", 12),
        listOption("Spotted Tabby/Leopard Spotted",
            "Spotted Tabby/Leopard Spotted", 13),
        listOption("Tan", "Tan", 14),
        listOption("Fawn", "Fawn", 15),
        listOption("Tortoiseshell", "Tortoiseshell", 16),
        listOption("White", "White", 17),
        listOption("Any", "Any", 18)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Eye color",
      "",
      "animals.eyeColor",
      false,
      true,
      CatClassification.physical,
      28,
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
      FilterType.advanced),
  filterOption(
      "Tail type",
      "",
      "animals.tailType",
      false,
      true,
      CatClassification.physical,
      29,
      [
        listOption("Bare", "Bare", 0),
        listOption("Bob", "Bob", 1),
        listOption("Curled", "Curled", 2),
        listOption("Docked", "Docked", 3),
        listOption("Kinked", "Kinked", 4),
        listOption("Long", "Long", 5),
        listOption("Missing", "Missing", 6),
        listOption("Short", "Short", 7),
        listOption("Any", "Any", 8)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Grooming needs",
      "",
      "animals.groomingNeeds",
      false,
      true,
      CatClassification.physical,
      33,
      [
        listOption("Not Req", "Not Required", 0),
        listOption("Low", "Low", 1),
        listOption("Medium", "Moderate", 2),
        listOption("High", "High", 3),
        listOption("Any", "Any", 4)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Shedding amount",
      "",
      "animals.sheddingLevel",
      false,
      true,
      CatClassification.physical,
      34,
      [
        listOption("Some", "Moderate", 0),
        listOption("None", "None", 1),
        listOption("High", "High", 2),
        listOption("Any", "Any", 3)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Altered",
      "",
      "animals.isAltered",
      false,
      false,
      CatClassification.physical,
      35,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Declawed",
      "",
      "animals.isDeclawed",
      false,
      false,
      CatClassification.physical,
      36,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  //filterOption( "Has allergies",  "animalHasAllergies", false, CatClassification.physical, [listOption( "Yes", "Yes",  0),listOption( "Any", "Any",  1)], FilterType.Advanced),
  //filterOption( "Hearing impaired",  "animalHearingImpaired", false, CatClassification.physical, [listOption( "Yes", "Yes",  0),listOption( "Any", "Any",  1)], FilterType.Advanced),
  //filterOption( "Hypoallergenic",  "animalHypoallergenic", false, CatClassification.physical, [listOption( "Yes", "Yes",  0),listOption( "Any", "Any",  1)], FilterType.Advanced),
  filterOption(
      "Microchipped",
      "",
      "animals.isMicrochipped",
      false,
      false,
      CatClassification.physical,
      37,
      [
        listOption("Yes", true, 0),
        listOption("No", false, 1),
        listOption("Any", "Any", 2)
      ],
      [],
      false,
      FilterType.advanced),
  filterOption(
      "Mixed breed",
      "",
      "animals.isBreedMixed",
      false,
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
      FilterType.advanced),
  //filterOption( "Ongoing medical?",  "animalOngoingMedical", false, CatClassification.physical, [listOption( "Yes", "Yes",  0),listOption( "Any", "Any",  1)], FilterType.Advanced),
  //filterOption( "Special diet",  "animalSpecialDiet", false, CatClassification.physical, [listOption( "Yes", "Yes",  0),listOption( "Any", "Any",  1)], FilterType.Advanced),
  filterOption(
      "Has special needs",
      "",
      "animals.isSpecialNeeds",
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
      FilterType.advanced),
];
