class WikipediaTextExtract {
  String? batchcomplete;
  Query? query;

  WikipediaTextExtract({this.batchcomplete, this.query});

  WikipediaTextExtract.fromJson(Map<String, dynamic> json) {
    batchcomplete = json['batchcomplete'];
    query = json['query'] != null ? Query.fromJson(json['query']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['batchcomplete'] = batchcomplete;
    if (query != null) {
      data['query'] = query!.toJson();
    }
    return data;
  }

}

class Query {
  Pages? pages;

  Query({this.pages});

  Query.fromJson(Map<String, dynamic> json) {
    pages = json['pages'] != null ? Pages.fromJson(json['pages']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (pages != null) {
      data['pages'] = pages!.toJson();
    }
    return data;
  }
}

class Pages {

  Page? page;

  Pages({this.page});

  Pages.fromJson(Map<String, dynamic> json) {
    page = json.values.elementAt(0) != null ? Page.fromJson(json.values.elementAt(0)) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (page != null) {
      data['page'] = page!.toJson();
    }
    return data;
  }
}

class Page {
  int? pageid;
  int? ns;
  String? title;
  String? extract;

  Page({this.pageid, this.ns, this.title, this.extract});

  Page.fromJson(Map<String, dynamic> json) {
    pageid = json['pageid'];
    ns = json['ns'];
    title = json['title'];
    extract = json['extract'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['pageid'] = pageid;
    data['ns'] = ns;
    data['title'] = title;
    data['extract'] = extract;
    return data;
  }
}