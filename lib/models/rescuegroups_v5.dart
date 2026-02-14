// To parse this JSON data, do
//
//     final pet = petFromJson(jsonString);

import 'dart:convert';

pet petFromJson(String str) => pet.fromJson(json.decode(str));

String petToJson(pet data) => json.encode(data.toJson());

class pet {
  pet({
    this.meta,
    this.data,
    this.included,
  });

  final Meta? meta;
  final List<petDatum>? data;
  final List<Included>? included;

  factory pet.fromJson(Map<dynamic, dynamic> json) => pet(
        meta: Meta.fromJson(json["meta"]),
        data:
            List<petDatum>.from(json["data"].map((x) => petDatum.fromJson(x))),
        included: List<Included>.from(
            json["included"].map((x) => Included.fromJson(x))),
      );

  Map<dynamic, dynamic> toJson() => {
        "meta": meta!.toJson(),
        "data": List<dynamic>.from(data!.map((x) => x.toJson())),
        "included": List<dynamic>.from(included!.map((x) => x.toJson())),
      };
}

class petDatum {
  petDatum({
    this.type,
    this.id,
    this.attributes,
    this.relationships,
  });

  final PurpleType? type;
  final String? id;
  final DatumAttributes? attributes;
  final Map<dynamic, Relationship>? relationships;

  factory petDatum.fromJson(Map<dynamic, dynamic> json) => petDatum(
        type: purpleTypeValues.map![json["type"]],
        id: json["id"],
        attributes: DatumAttributes.fromJson(json["attributes"]),
        relationships: Map.from(json["relationships"]).map((k, v) =>
            MapEntry<String, Relationship>(k, Relationship.fromJson(v))),
      );

  Map<dynamic, dynamic> toJson() => {
        "type": purpleTypeValues.reverse[type],
        "id": id,
        "attributes": attributes!.toJson(),
        "relationships": Map.from(relationships!)
            .map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
      };
}

class DatumAttributes {
  DatumAttributes({
    this.id,
    this.name,
    this.breedPrimary,
    this.ageGroup,
    this.sex,
    this.updatedDate,
    this.birthDate,
    this.descriptionHtml,
    this.descriptionText,
    this.sizeGroup,
    this.availableDate,
  });

  final String? id;
  final String? name;
  final String? breedPrimary;
  final AgeGroup? ageGroup;
  final Sex? sex;
  final DateTime? updatedDate;
  final DateTime? birthDate;
  final String? descriptionHtml;
  final String? descriptionText;
  final SizeGroup? sizeGroup;
  final DateTime? availableDate;

  factory DatumAttributes.fromJson(Map<dynamic, dynamic> json) =>
      DatumAttributes(
        id: json["id"],
        name: json["name"],
        breedPrimary: json["breedPrimary"],
        ageGroup: json["ageGroup"] == null
            ? null
            : ageGroupValues.map![json["ageGroup"]],
        sex: sexValues.map![json["sex"]],
        updatedDate: DateTime.parse(json["updatedDate"]),
        birthDate: json["birthDate"] == null
            ? null
            : DateTime.parse(json["birthDate"]),
        descriptionHtml: json["descriptionHtml"],
        descriptionText: json["descriptionText"] is String
            ? json["descriptionText"] as String
            : null,
        sizeGroup: json["sizeGroup"] == null
            ? null
            : sizeGroupValues.map![json["sizeGroup"]],
        availableDate: json["availableDate"] == null
            ? null
            : DateTime.parse(json["availableDate"]),
      );

  Map<dynamic, dynamic> toJson() => {
        "id": id,
        "name": name,
        "breedPrimary": breedPrimary,
        "ageGroup": ageGroup == null ? null : ageGroupValues.reverse[ageGroup],
        "sex": sexValues.reverse[sex],
        "updatedDate": updatedDate!.toIso8601String(),
        "birthDate": birthDate?.toIso8601String(),
        "descriptionHtml": descriptionHtml,
        "descriptionText": descriptionText,
        "sizeGroup":
            sizeGroup == null ? null : sizeGroupValues.reverse[sizeGroup],
        "availableDate":
            availableDate?.toIso8601String(),
      };
}

enum AgeGroup { ADULT, SENIOR, YOUNG }

final ageGroupValues = EnumValues({
  "Adult": AgeGroup.ADULT,
  "Senior": AgeGroup.SENIOR,
  "Young": AgeGroup.YOUNG
});

enum Sex { FEMALE, MALE }

final sexValues = EnumValues({"Female": Sex.FEMALE, "Male": Sex.MALE});

enum SizeGroup { LARGE, MEDIUM, SMALL, X_LARGE }

final sizeGroupValues = EnumValues({
  "Large": SizeGroup.LARGE,
  "Medium": SizeGroup.MEDIUM,
  "Small": SizeGroup.SMALL,
  "X-Large": SizeGroup.X_LARGE
});

class Relationship {
  Relationship({
    this.data,
  });

  final List<RelationshipDatum>? data;

  factory Relationship.fromJson(Map<dynamic, dynamic> json) => Relationship(
        data: List<RelationshipDatum>.from(
            json["data"].map((x) => RelationshipDatum.fromJson(x))),
      );

  Map<dynamic, dynamic> toJson() => {
        "data": List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class RelationshipDatum {
  RelationshipDatum({
    this.type,
    this.id,
  });

  final IncludedType? type;
  final String? id;

  factory RelationshipDatum.fromJson(Map<dynamic, dynamic> json) =>
      RelationshipDatum(
        type: includedTypeValues.map![json["type"]],
        id: json["id"],
      );

  Map<dynamic, dynamic> toJson() => {
        "type": includedTypeValues.reverse[type],
        "id": id,
      };
}

enum IncludedType {
  BREEDS,
  COLORS,
  FOSTERS,
  LOCATIONS,
  ORGS,
  PATTERNS,
  PICTURES,
  SPECIES,
  STATUSES,
  VIDEOS,
  VIDEOURLS
}

final includedTypeValues = EnumValues({
  "breeds": IncludedType.BREEDS,
  "colors": IncludedType.COLORS,
  "fosters": IncludedType.FOSTERS,
  "locations": IncludedType.LOCATIONS,
  "orgs": IncludedType.ORGS,
  "patterns": IncludedType.PATTERNS,
  "pictures": IncludedType.PICTURES,
  "species": IncludedType.SPECIES,
  "statuses": IncludedType.STATUSES,
  "videos": IncludedType.VIDEOS,
  "videourls": IncludedType.VIDEOURLS
});

enum PurpleType { ANIMALS }

final purpleTypeValues = EnumValues({"animals": PurpleType.ANIMALS});

class Included {
  Included({
    this.type,
    this.id,
    this.attributes,
    this.links,
  });

  final IncludedType? type;
  final String? id;
  final IncludedAttributes? attributes;
  final Links? links;

  factory Included.fromJson(Map<dynamic, dynamic> json) => Included(
        type: includedTypeValues.map![json["type"]],
        id: json["id"],
        attributes: IncludedAttributes.fromJson(json["attributes"]),
        links: json["links"] == null ? null : Links.fromJson(json["links"]),
      );

  Map<dynamic, dynamic> toJson() => {
        "type": includedTypeValues.reverse[type],
        "id": id,
        "attributes": attributes?.toJson(),
        "links": links?.toJson(),
      };
}

class IncludedAttributes {
  IncludedAttributes({
    this.name,
    this.singular,
    this.plural,
    this.youngSingular,
    this.youngPlural,
    this.description,
    this.street,
    this.city,
    this.state,
    this.citystate,
    this.postalcode,
    this.country,
    this.phone,
    this.lat,
    this.lon,
    this.coordinates,
    this.email,
    this.url,
    this.facebookUrl,
    this.adoptionProcess,
    this.about,
    this.services,
    this.type,
    this.original,
    this.large,
    this.small,
    this.order,
    this.created,
    this.updated,
    this.videoId,
    this.urlThumbnail,
    this.postalcodePlus4,
    this.donationUrl,
    this.firstname,
    this.fullname,
    this.adoptionUrl,
    this.sponsorshipUrl,
    this.fileSize,
  });

  final String? name;
  final String? singular;
  final String? plural;
  final String? youngSingular;
  final String? youngPlural;
  final String? description;
  final String? street;
  final String? city;
  final String? state;
  final String? citystate;
  final String? postalcode;
  final Country? country;
  final String? phone;
  final double? lat;
  final double? lon;
  final String? coordinates;
  final String? email;
  final String? url;
  final String? facebookUrl;
  final String? adoptionProcess;
  final String? about;
  final String? services;
  final AttributesType? type;
  final Large? original;
  final Large? large;
  final Large? small;
  final int? order;
  final DateTime? created;
  final DateTime? updated;
  final String? videoId;
  final String? urlThumbnail;
  final String? postalcodePlus4;
  final String? donationUrl;
  final String? firstname;
  final String? fullname;
  final String? adoptionUrl;
  final String? sponsorshipUrl;
  final int? fileSize;

  factory IncludedAttributes.fromJson(Map<dynamic, dynamic> json) =>
      IncludedAttributes(
        name: json["name"],
        singular: json["singular"],
        plural: json["plural"],
        youngSingular:
            json["youngSingular"],
        youngPlural: json["youngPlural"],
        description: json["description"],
        street: json["street"],
        city: json["city"],
        state: json["state"],
        citystate: json["citystate"],
        postalcode: json["postalcode"],
        country: json["country"] == null
            ? null
            : countryValues.map![json["country"]],
        phone: json["phone"],
        lat: json["lat"]?.toDouble(),
        lon: json["lon"]?.toDouble(),
        coordinates: json["coordinates"],
        email: json["email"],
        url: json["url"],
        facebookUrl: json["facebookUrl"],
        adoptionProcess:
            json["adoptionProcess"],
        about: json["about"],
        services: json["services"],
        type: json["type"] == null
            ? null
            : attributesTypeValues.map![json["type"]],
        original:
            json["original"] == null ? null : Large.fromJson(json["original"]),
        large: json["large"] == null ? null : Large.fromJson(json["large"]),
        small: json["small"] == null ? null : Large.fromJson(json["small"]),
        order: json["order"],
        created:
            json["created"] == null ? null : DateTime.parse(json["created"]),
        updated:
            json["updated"] == null ? null : DateTime.parse(json["updated"]),
        videoId: json["videoId"],
        urlThumbnail:
            json["urlThumbnail"],
        postalcodePlus4:
            json["postalcodePlus4"],
        donationUrl: json["donationUrl"],
        firstname: json["firstname"],
        fullname: json["fullname"],
        adoptionUrl: json["adoptionUrl"],
        sponsorshipUrl:
            json["sponsorshipUrl"],
        fileSize: json["fileSize"],
      );

  Map<dynamic, dynamic> toJson() => {
        "name": name,
        "singular": singular,
        "plural": plural,
        "youngSingular": youngSingular,
        "youngPlural": youngPlural,
        "description": description,
        "street": street,
        "city": city,
        "state": state,
        "citystate": citystate,
        "postalcode": postalcode,
        "country": country == null ? null : countryValues.reverse[country],
        "phone": phone,
        "lat": lat,
        "lon": lon,
        "coordinates": coordinates,
        "email": email,
        "url": url,
        "facebookUrl": facebookUrl,
        "adoptionProcess": adoptionProcess,
        "about": about,
        "services": services,
        "type": type == null ? null : attributesTypeValues.reverse[type],
        "original": original?.toJson(),
        "large": large?.toJson(),
        "small": small?.toJson(),
        "order": order,
        "created": created?.toIso8601String(),
        "updated": updated?.toIso8601String(),
        "videoId": videoId,
        "urlThumbnail": urlThumbnail,
        "postalcodePlus4": postalcodePlus4,
        "donationUrl": donationUrl,
        "firstname": firstname,
        "fullname": fullname,
        "adoptionUrl": adoptionUrl,
        "sponsorshipUrl": sponsorshipUrl,
        "fileSize": fileSize,
      };
}

enum Country { UNITED_STATES, CANADA }

final countryValues = EnumValues(
    {"Canada": Country.CANADA, "United States": Country.UNITED_STATES});

class Large {
  Large({
    this.filesize,
    this.resolutionX,
    this.resolutionY,
    this.url,
  });

  final int? filesize;
  final int? resolutionX;
  final int? resolutionY;
  final String? url;

  factory Large.fromJson(Map<dynamic, dynamic> json) => Large(
        filesize: json["filesize"],
        resolutionX: json["resolutionX"],
        resolutionY: json["resolutionY"],
        url: json["url"],
      );

  Map<dynamic, dynamic> toJson() => {
        "filesize": filesize,
        "resolutionX": resolutionX,
        "resolutionY": resolutionY,
        "url": url,
      };
}

enum AttributesType { SHELTER, RESCUE }

final attributesTypeValues = EnumValues(
    {"Rescue": AttributesType.RESCUE, "Shelter": AttributesType.SHELTER});

class Links {
  Links({
    this.self,
  });

  final String? self;

  factory Links.fromJson(Map<dynamic, dynamic> json) => Links(
        self: json["self"],
      );

  Map<dynamic, dynamic> toJson() => {
        "self": self,
      };
}

class Meta {
  Meta({
    this.count,
    this.countReturned,
    this.pageReturned,
    this.limit,
    this.pages,
    this.transactionId,
  });

  final int? count;
  final int? countReturned;
  final int? pageReturned;
  final int? limit;
  final int? pages;
  final String? transactionId;

  factory Meta.fromJson(Map<dynamic, dynamic> json) => Meta(
        count: json["count"],
        countReturned: json["countReturned"],
        pageReturned: json["pageReturned"],
        limit: json["limit"],
        pages: json["pages"],
        transactionId: json["transactionId"],
      );

  Map<dynamic, dynamic> toJson() => {
        "count": count,
        "countReturned": countReturned,
        "pageReturned": pageReturned,
        "limit": limit,
        "pages": pages,
        "transactionId": transactionId,
      };
}

class EnumValues<T> {
  Map<dynamic, T>? map;
  Map<T, dynamic>? reverseMap;

  EnumValues(this.map);

  Map<T, dynamic> get reverse {
    reverseMap ??= map!.map((k, v) => MapEntry(v, k));
    return reverseMap!;
  }
}
