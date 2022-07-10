class RescueGroupsQuery {
  RescueGroupsQuery({
    required this.data,
  });
  late final Data data;

  RescueGroupsQuery.fromJson(Map<dynamic, dynamic> json) {
    data = Data.fromJson(json['data']);
  }

  Map<dynamic, dynamic> toJson() {
    final _data = <dynamic, dynamic>{};
    _data['data'] = data.toJson();
    return _data;
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
    final _data = <String, dynamic>{};
    _data['filterRadius'] = filterRadius.toJson();
    _data['filters'] = filters.map((e) => e.toJson()).toList();
    return _data;
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
    final _data = <String, dynamic>{};
    _data['miles'] = miles;
    _data['postalcode'] = postalcode;
    return _data;
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
  late final List<String> criteria;

  Filters.fromJson(Map<dynamic, dynamic> json) {
    fieldName = json['fieldName'];
    operation = json['operation'];
    String test = "";
    try {
      test = json['criteria'];
      criteria = [test];
    } catch (e) {
      criteria = json["criteria"];
    }
  }

  Map<dynamic, dynamic> toJson() {
    final _data = <dynamic, dynamic>{};
    _data['fieldName'] = fieldName;
    _data['operation'] = operation;
    _data['criteria'] = criteria;
    return _data;
  }
}
