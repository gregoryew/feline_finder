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

  Zippopotam.fromJson(Map<String, dynamic> json) {
    postCode = json['post code'] ?? '';
    country = json['country'] ?? '';
    countryAbbreviation = json['country abbreviation'] ?? '';
    places = json['places'] != null
        ? List.from(json['places']).map((e) => Places.fromJson(e)).toList()
        : <Places>[];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['post code'] = postCode;
    data['country'] = country;
    data['country abbreviation'] = countryAbbreviation;
    data['places'] = places.map((e) => e.toJson()).toList();
    return data;
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

  Places.fromJson(Map<String, dynamic> json) {
    placeName = json['place name'];
    longitude = json['longitude'];
    state = json['state'];
    stateAbbreviation = json['state abbreviation'];
    latitude = json['latitude'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['place name'] = placeName;
    data['longitude'] = longitude;
    data['state'] = state;
    data['state abbreviation'] = stateAbbreviation;
    data['latitude'] = latitude;
    return data;
  }
}
