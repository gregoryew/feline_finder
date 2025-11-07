class RescueGroupsQuery {
  RescueGroupsQuery({
    required this.data,
  });
  late final Data data;

  RescueGroupsQuery.fromJson(Map<dynamic, dynamic> json) {
    data = Data.fromJson(json['data']);
  }

  Map<dynamic, dynamic> toJson() {
    final data = <dynamic, dynamic>{};
    data['data'] = data.toJson();
    return data;
  }
}

class Data {
  Data({
    required this.filterRadius,
    required this.filters,
  });
  late final FilterRadius filterRadius;
  late final List<Filters> filters;

  Data.fromJson(Map<dynamic, dynamic> json) {
    filterRadius = FilterRadius.fromJson(json['filterRadius']);
    filters =
        List.from(json['filters']).map((e) => Filters.fromJson(e)).toList();
  }

  Map<dynamic, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['filterRadius'] = filterRadius.toJson();
    data['filters'] = filters.map((e) => e.toJson()).toList();
    return data;
  }
}

class FilterRadius {
  FilterRadius({
    required this.miles,
    required this.postalcode,
  });
  late final int miles;
  late final String postalcode;

  FilterRadius.fromJson(Map<dynamic, dynamic> json) {
    miles = json['miles'];
    postalcode = json['postalcode'];
  }

  Map<dynamic, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['miles'] = miles;
    data['postalcode'] = postalcode;
    return data;
  }
}

class Filters {
  Filters({
    required this.fieldName,
    required this.operation,
    required this.criteria,
  });
  late final String fieldName;
  late final String operation;
  late final dynamic criteria;

  Filters.fromJson(Map<dynamic, dynamic> json) {
    fieldName = json['fieldName'];
    operation = json['operation'];
    String test = "";
    try {
      test = json['criteria'];
      criteria = test;
    } catch (e) {
      try {
        criteria = json["criteria"];
      } catch (e2) {}
    }
  }

  Map<dynamic, dynamic> toJson() {
    final data = <dynamic, dynamic>{};
    data['fieldName'] = fieldName;
    data['operation'] = operation;
    data['criteria'] = criteria;
    return data;
  }
}
