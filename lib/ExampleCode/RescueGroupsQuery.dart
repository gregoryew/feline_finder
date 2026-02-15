class RescueGroupsQuery {
  RescueGroupsQuery({
    required this.data,
    this.filterProcessing,
  });
  late final Data data;
  /// 1-based filter indices and AND/OR, e.g. "1 AND (2 OR 3 OR 4) AND 5"
  final String? filterProcessing;

  RescueGroupsQuery.fromJson(Map<dynamic, dynamic> json)
      : data = Data.fromJson(json['data']),
        filterProcessing = json['filterProcessing'] as String?;

  Map<dynamic, dynamic> toJson() {
    final data = <dynamic, dynamic>{};
    data['data'] = this.data.toJson();
    return data;
  }
}

class Data {
  Data({
    this.filterRadius,
    required this.filters,
    this.filterProcessing,
  });
  /// Optional. Omit for searches that don't need distance/location (e.g. fetch by animal IDs).
  final FilterRadius? filterRadius;
  late final List<Filters> filters;
  /// 1-based filter indices and AND/OR, e.g. "1 AND (2 OR 3 OR 4) AND 5"
  final String? filterProcessing;

  Data.fromJson(Map<dynamic, dynamic> json)
      : filterRadius = json['filterRadius'] != null
            ? FilterRadius.fromJson(json['filterRadius'] as Map<dynamic, dynamic>)
            : null,
        filters =
            List.from(json['filters']).map((e) => Filters.fromJson(e)).toList(),
        filterProcessing = json['filterProcessing'] as String?;

  Map<dynamic, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (filterRadius != null) {
      data['filterRadius'] = filterRadius!.toJson();
    }
    data['filters'] = filters.map((e) => e.toJson()).toList();
    if (filterProcessing != null && filterProcessing!.isNotEmpty) {
      data['filterProcessing'] = filterProcessing;
    }
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
