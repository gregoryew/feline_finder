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

enum FilterType {
  simple,
  advanced
}

class filterOption {
  String name;
  String choosenValue;
  String fieldName;
  bool display;
  bool list;
  CatClassification classification;
  int sequence;
  List<listOption> options;
  List<int> choosenListValues;
  bool imported;
  FilterType filterType;

  filterOption(this.name,
  this.choosenValue,
  this.fieldName,
  this.display,
  this.list,
  this.classification,
  this.sequence,
  this.options,
  this.choosenListValues,
  this.imported,
  this.filterType
  );
}

class listOption {
  String displayName;
  String search;
  int value;

  listOption(this.displayName,
  this.search,
  this.value);
}

/*
filteringOptions.append(filterOption(n: "Breed", f: "breedPrimaryId", d: true, c:.breed, l: true, o: self.breedChoices, ft: FilterType.Advanced))
filteringOptions.append(filterOption(n: "Sort By", f: "sortBy", d: false, c:.sort, o: 
[listOption(displayName: "Most Recent", search: "No", value: 1), 
listOption(displayName: "Distance", search: "distance", value: 0)], ft: FilterType.Advanced))

filteringOptions.append(filterOption(n: "Distance", f: "distance", d: false, c:.sort, o: 
[listOption(displayName: "5", search: "5", value: 0), 
listOption(displayName: "20", search: "20", value: 1), 
listOption(displayName: "50", search: "50", value: 2), 
listOption(displayName: "100", search: "100", value: 3), 
listOption(displayName: "200", search: "200", value: 4), 
listOption(displayName: "Any", search: "Any", value: 5)], 
ft: FilterType.Advanced))

filteringOptions.append(filterOption(n: "Updated Since", f: "date", d: false, c:.sort, o: 
[listOption(displayName: "Day", search: "0", value: 0), 
listOption(displayName: "Week", search: "Week", value: 1), 
listOption(displayName: "Month", search: "Month", value: 2), 
listOption(displayName: "Year", search: "Year", value: 3), 
listOption(displayName: "Any", search: "Any", value: 4)], 
ft: FilterType.Advanced))

*/

List<filterOption> filteringOptions = [
  filterOption("Breed", "", "breedPrimaryId", true, true, CatClassification.breed, 1, [], [], false, FilterType.advanced),
  filterOption("Sort By", "", "sortBy", false, false, CatClassification.sort, 1, 
  [listOption("Most Recent", "distance", 1),
   listOption("Distance", "distance", 0)], [], false, FilterType.advanced),
  filterOption("Breed", "", "breedPrimaryId", true, true, CatClassification.breed, 1, [], [], false, FilterType.advanced), 

];

