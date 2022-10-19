class SavedQuery {
  Query? query;

  SavedQuery({this.query});

  SavedQuery.fromJson(Map<String, dynamic> json) {
    query = json['query'] != null ? Query.fromJson(json['query']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (query != null) {
      data['query'] = query!.toJson();
    }
    return data;
  }
}

class Query {
  String? name;
  String? createdDate;
  String? createdBy;
  String? updatedDate;
  List<Filters>? filters;
  int? sort;
  int? distance;

  Query(
      {this.name,
      this.createdDate,
      this.createdBy,
      this.updatedDate,
      this.filters,
      this.sort,
      this.distance});

  Query.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    createdDate = json['created_date'];
    createdBy = json['created_by'];
    updatedDate = json['updated_date'];
    if (json['filters'] != null) {
      filters = <Filters>[];
      json['filters'].forEach((v) {
        filters!.add(Filters.fromJson(v));
      });
    }
    sort = json['sort'];
    distance = json['distance'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = name;
    data['created_date'] = createdDate;
    data['created_by'] = createdBy;
    data['updated_date'] = updatedDate;
    if (filters != null) {
      data['filters'] = filters!.map((v) => v.toJson()).toList();
    }
    data['sort'] = sort;
    data['distance'] = distance;
    return data;
  }
}

class Filters {
  String? fieldName;
  String? fieldOperation;
  List<String>? fieldValues;

  Filters({this.fieldName, this.fieldOperation, this.fieldValues});

  Filters.fromJson(Map<String, dynamic> json) {
    fieldName = json['field_name'];
    fieldOperation = json['field_operation'];
    fieldValues = json['field_values'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['field_name'] = fieldName;
    data['field_operation'] = fieldOperation;
    data['field_values'] = fieldValues;
    return data;
  }
}
