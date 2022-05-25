
class Shelter {
  Meta? meta;
  List<Data>? data;

  Shelter({this.meta, this.data});

  Shelter.fromJson(Map<String, dynamic> json) {
    if(json["meta"] is Map)
      this.meta = json["meta"] == null ? null : Meta.fromJson(json["meta"]);
    if(json["data"] is List)
      this.data = json["data"]==null ? null : (json["data"] as List).map((e)=>Data.fromJson(e)).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if(this.meta != null)
      data["meta"] = meta!.toJson();
    if(this.data != null)
      data["data"] = this.data?.map((e)=>e.toJson()).toList();
    return data;
  }
}

class Data {
  String? type;
  String? id;
  Attributes? attributes;

  Data({this.type, this.id, this.attributes});

  Data.fromJson(Map<String, dynamic> json) {
    if(json["type"] is String)
      this.type = json["type"];
    if(json["id"] is String)
      this.id = json["id"];
    if(json["attributes"] is Map)
      this.attributes = json["attributes"] == null ? null : Attributes.fromJson(json["attributes"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data["type"] = this.type;
    data["id"] = this.id;
    if(this.attributes != null)
      data["attributes"] = this.attributes?.toJson();
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
    if(json["name"] is String)
      this.name = json["name"];
    if(json["city"] is String)
      this.city = json["city"];
    if(json["state"] is String)
      this.state = json["state"];
    if(json["postalcode"] is String)
      this.postalcode = json["postalcode"];
    if(json["postalcodePlus4"] is String)
      this.postalcodePlus4 = json["postalcodePlus4"];
    if(json["country"] is String)
      this.country = json["country"];
    if(json["email"] is String)
      this.email = json["email"];
    if(json["url"] is String)
      this.url = json["url"];
    if(json["facebookUrl"] is String)
      this.facebookUrl = json["facebookUrl"];
    if(json["type"] is String)
      this.type = json["type"];
    if(json["isCommonapplicationAccepted"] is bool)
      this.isCommonapplicationAccepted = json["isCommonapplicationAccepted"];
    if(json["lat"] is double)
      this.lat = json["lat"];
    if(json["lon"] is double)
      this.lon = json["lon"];
    if(json["coordinates"] is String)
      this.coordinates = json["coordinates"];
    if(json["citystate"] is String)
      this.citystate = json["citystate"];

    if(json["serveAreas"] is String)
      this.serveAreas = json["serveAreas"];
    if(json["about"] is String)
      this.about = json["about"];
    if(json["services"] is String)
      this.services = json["services"];
    if(json["adoptionProcess"] is String)
      this.adoptionProcess = json["adoptionProcess"];
    if(json["adoptionUrl"] is String)
      this.adoptionUrl = json["adoptionUrl"];
    if(json["meetPets"] is String)
      this.meetPets = json["meetPets"];
    if(json["donationUrl"] is String)
      this.donationUrl = json["donationUrl"];
    if(json["sponsorshipUrl"] is String)
      this.sponsorshipUrl = json["sponsorshipUrl"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data["name"] = this.name;
    data["city"] = this.city;
    data["state"] = this.state;
    data["postalcode"] = this.postalcode;
    data["postalcodePlus4"] = this.postalcodePlus4;
    data["country"] = this.country;
    data["email"] = this.email;
    data["url"] = this.url;
    data["facebookUrl"] = this.facebookUrl;
    data["type"] = this.type;
    data["isCommonapplicationAccepted"] = this.isCommonapplicationAccepted;
    data["lat"] = this.lat;
    data["lon"] = this.lon;
    data["coordinates"] = this.coordinates;
    data["citystate"] = this.citystate;

    data["serveAreas"] = this.serveAreas;
    data["about"] = this.about;
    data["services"] = this.services;
    data["adoptionProcess"] = this.adoptionProcess;
    data["adoptionUrl"] = this.adoptionUrl;
    data["meetPets"] = this.meetPets;
    data["donationUrl"] = this.donationUrl;
    data["sponsorshipUrl"] = this.sponsorshipUrl;

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
    if(json["count"] is int)
      this.count = json["count"];
    if(json["countReturned"] is int)
      this.countReturned = json["countReturned"];
    if(json["pageReturned"] is int)
      this.pageReturned = json["pageReturned"];
    if(json["limit"] is int)
      this.limit = json["limit"];
    if(json["pages"] is int)
      this.pages = json["pages"];
    if(json["transactionId"] is String)
      this.transactionId = json["transactionId"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data["count"] = this.count;
    data["countReturned"] = this.countReturned;
    data["pageReturned"] = this.pageReturned;
    data["limit"] = this.limit;
    data["pages"] = this.pages;
    data["transactionId"] = this.transactionId;
    return data;
  }
}