
class Shelter {
  Meta? meta;
  List<Data>? data;

  Shelter({this.meta, this.data});

  Shelter.fromJson(Map<String, dynamic> json) {
    if(json["meta"] is Map) {
      meta = json["meta"] == null ? null : Meta.fromJson(json["meta"]);
    }
    if(json["data"] is List) {
      data = json["data"]==null ? null : (json["data"] as List).map((e)=>Data.fromJson(e)).toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if(meta != null) {
      data["meta"] = meta!.toJson();
    }
    if(this.data != null) {
      data["data"] = this.data?.map((e)=>e.toJson()).toList();
    }
    return data;
  }
}

class Data {
  String? type;
  String? id;
  Attributes? attributes;

  Data({this.type, this.id, this.attributes});

  Data.fromJson(Map<String, dynamic> json) {
    if(json["type"] is String) {
      type = json["type"];
    }
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["attributes"] is Map) {
      attributes = json["attributes"] == null ? null : Attributes.fromJson(json["attributes"]);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["type"] = type;
    data["id"] = id;
    if(attributes != null) {
      data["attributes"] = attributes?.toJson();
    }
    return data;
  }
}

class Attributes {
  String? name;
  String? city;
  String? state;
  String? postalcode;
  String? postalcodePlus4;
  String? country;
  String? email;
  String? url;
  String? facebookUrl;
  String? type;
  bool? isCommonapplicationAccepted;
  double? lat;
  double? lon;
  String? coordinates;
  String? citystate;

  String? serveAreas;
  String? about;
  String? services;
  String? adoptionProcess;
  String? adoptionUrl;
  String? meetPets;
  String? donationUrl;
  String? sponsorshipUrl;

  Attributes({this.name, this.city, this.state, this.postalcode, this.postalcodePlus4, this.country, this.email, this.url, this.facebookUrl, this.type, this.isCommonapplicationAccepted, this.lat, this.lon, this.coordinates, this.citystate});

  Attributes.fromJson(Map<String, dynamic> json) {
    if(json["name"] is String) {
      name = json["name"];
    }
    if(json["city"] is String) {
      city = json["city"];
    }
    if(json["state"] is String) {
      state = json["state"];
    }
    if(json["postalcode"] is String) {
      postalcode = json["postalcode"];
    }
    if(json["postalcodePlus4"] is String) {
      postalcodePlus4 = json["postalcodePlus4"];
    }
    if(json["country"] is String) {
      country = json["country"];
    }
    if(json["email"] is String) {
      email = json["email"];
    }
    if(json["url"] is String) {
      url = json["url"];
    }
    if(json["facebookUrl"] is String) {
      facebookUrl = json["facebookUrl"];
    }
    if(json["type"] is String) {
      type = json["type"];
    }
    if(json["isCommonapplicationAccepted"] is bool) {
      isCommonapplicationAccepted = json["isCommonapplicationAccepted"];
    }
    if(json["lat"] is double) {
      lat = json["lat"];
    }
    if(json["lon"] is double) {
      lon = json["lon"];
    }
    if(json["coordinates"] is String) {
      coordinates = json["coordinates"];
    }
    if(json["citystate"] is String) {
      citystate = json["citystate"];
    }

    if(json["serveAreas"] is String) {
      serveAreas = json["serveAreas"];
    }
    if(json["about"] is String) {
      about = json["about"];
    }
    if(json["services"] is String) {
      services = json["services"];
    }
    if(json["adoptionProcess"] is String) {
      adoptionProcess = json["adoptionProcess"];
    }
    if(json["adoptionUrl"] is String) {
      adoptionUrl = json["adoptionUrl"];
    }
    if(json["meetPets"] is String) {
      meetPets = json["meetPets"];
    }
    if(json["donationUrl"] is String) {
      donationUrl = json["donationUrl"];
    }
    if(json["sponsorshipUrl"] is String) {
      sponsorshipUrl = json["sponsorshipUrl"];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["name"] = name;
    data["city"] = city;
    data["state"] = state;
    data["postalcode"] = postalcode;
    data["postalcodePlus4"] = postalcodePlus4;
    data["country"] = country;
    data["email"] = email;
    data["url"] = url;
    data["facebookUrl"] = facebookUrl;
    data["type"] = type;
    data["isCommonapplicationAccepted"] = isCommonapplicationAccepted;
    data["lat"] = lat;
    data["lon"] = lon;
    data["coordinates"] = coordinates;
    data["citystate"] = citystate;

    data["serveAreas"] = serveAreas;
    data["about"] = about;
    data["services"] = services;
    data["adoptionProcess"] = adoptionProcess;
    data["adoptionUrl"] = adoptionUrl;
    data["meetPets"] = meetPets;
    data["donationUrl"] = donationUrl;
    data["sponsorshipUrl"] = sponsorshipUrl;

    return data;
  }
}

class Meta {
  int? count;
  int? countReturned;
  int? pageReturned;
  int? limit;
  int? pages;
  String? transactionId;

  Meta({this.count, this.countReturned, this.pageReturned, this.limit, this.pages, this.transactionId});

  Meta.fromJson(Map<String, dynamic> json) {
    if(json["count"] is int) {
      count = json["count"];
    }
    if(json["countReturned"] is int) {
      countReturned = json["countReturned"];
    }
    if(json["pageReturned"] is int) {
      pageReturned = json["pageReturned"];
    }
    if(json["limit"] is int) {
      limit = json["limit"];
    }
    if(json["pages"] is int) {
      pages = json["pages"];
    }
    if(json["transactionId"] is String) {
      transactionId = json["transactionId"];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["count"] = count;
    data["countReturned"] = countReturned;
    data["pageReturned"] = pageReturned;
    data["limit"] = limit;
    data["pages"] = pages;
    data["transactionId"] = transactionId;
    return data;
  }
}