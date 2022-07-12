class Zippopotam {
  Zippopotam({
    required this.postCode,
    required this.country,
    required this.countryAbbreviation,
    required this.places,
  });
  late final String postCode;
  late final String country;
  late final String countryAbbreviation;
  late final List<Places> places;
  
  Zippopotam.fromJson(Map<String, dynamic> json){
    postCode = json['post code'];
    country = json['country'];
    countryAbbreviation = json['country abbreviation'];
    places = List.from(json['places']).map((e)=>Places.fromJson(e)).toList();
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['post code'] = postCode;
    _data['country'] = country;
    _data['country abbreviation'] = countryAbbreviation;
    _data['places'] = places.map((e)=>e.toJson()).toList();
    return _data;
  }
}

class Places {
  Places({
    required this.placeName,
    required this.longitude,
    required this.state,
    required this.stateAbbreviation,
    required this.latitude,
  });
  late final String placeName;
  late final String longitude;
  late final String state;
  late final String stateAbbreviation;
  late final String latitude;
  
  Places.fromJson(Map<String, dynamic> json){
    placeName = json['place name'];
    longitude = json['longitude'];
    state = json['state'];
    stateAbbreviation = json['state abbreviation'];
    latitude = json['latitude'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['place name'] = placeName;
    _data['longitude'] = longitude;
    _data['state'] = state;
    _data['state abbreviation'] = stateAbbreviation;
    _data['latitude'] = latitude;
    return _data;
  }
}