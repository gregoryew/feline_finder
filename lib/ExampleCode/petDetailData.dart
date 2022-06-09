import 'package:flutter/widgets.dart';
import '../main.dart';
import 'RescueGroups.dart';
import 'media.dart';

class PetDetailData {
  String? id;
  String? name;
  String? primaryBreed;
  String? status;
  String? ageGroup;
  String? sex;
  String? sizeGroup;
  String? email;
  String? phoneNumber;
  String? street;
  String? cityState;
  String? postalCode;
  List<Large> mainPictures = [];
  List<Media> media = [];
  String? organizationID = "";
  String? organizationName = "";
  String? description = "";
  var mediaGlobalKeys = [];

  PetDetailData(petDatum pet, List<Included> included,
      List<Relationship> relationships, Function(int) selectedIndexChanged) {
    id = pet.id;
    name = pet.attributes!.name;
    primaryBreed = pet.attributes!.breedPrimary;
    ageGroup = ageGroupValues.reverse[pet.attributes!.ageGroup];
    sex = sexValues.reverse[pet.attributes!.sex];
    sizeGroup = sizeGroupValues.reverse[pet.attributes!.sizeGroup];
    var statusList =
        findAllOfACertainType(pet, included, "statuses", IncludedType.STATUSES);
    status = statusList[0].attributes!.name;
    List<Included> picturesIncluded =
        findAllOfACertainType(pet, included, "pictures", IncludedType.PICTURES);
    for (int i = 0; i < picturesIncluded.length; i++) {
      if (picturesIncluded[i].attributes!.large!.url != null) {
        mainPictures.add(picturesIncluded[i].attributes!.large!);
      } else if (picturesIncluded[i].attributes!.original!.url == null) {
        mainPictures.add(picturesIncluded[i].attributes!.original!);
      } else {
        mainPictures.add(picturesIncluded[i].attributes!.small!);
      }
    }
    print("******* URL = " + picturesIncluded[0].attributes!.small!.url!);
    for (int i = 0; i < picturesIncluded.length; i++) {
      var photo = SmallPhoto(
          i == 0,
          i,
          picturesIncluded[i].attributes!.small!.url!,
          selectedIndexChanged,
          buttonChangedHighlightStream
          );
      media.add(photo);
    }
    List<Included> videoListIncluded =
        findAllOfACertainType(pet, included, "videos", IncludedType.VIDEOS);
    /*
    for (int i = 0; i < videoListIncluded.length; i++) {
      YouTubeVideo video = YouTubeVideo();
      video.order = videoListIncluded[i].attributes!.order;
      video.urlThumbnail = videoListIncluded[i].attributes!.urlThumbnail;
      video.videoId = videoListIncluded[i].attributes!.videoId;
      videos?.add(video);
    }
    */
    List<Included> organizationIncluded =
        findAllOfACertainType(pet, included, "orgs", IncludedType.ORGS);
    organizationID = organizationIncluded[0].id;
    organizationName = organizationIncluded[0].attributes!.name;
    street = organizationIncluded[0].attributes!.street;
    cityState = organizationIncluded[0].attributes!.citystate;
    postalCode = organizationIncluded[0].attributes!.postalcode;
    email = organizationIncluded[0].attributes!.email;
    phoneNumber = organizationIncluded[0].attributes!.phone;
    description = pet.attributes!.descriptionText;
  }

  List<Included> findAllOfACertainType(petDatum pet, List<Included> included,
      String includeType, IncludedType type) {
    if (pet.relationships![includeType] == null ||
        pet.relationships![includeType]!.data == null) return [];
    final includedData = pet.relationships![includeType]!.data!;
    final includeds = included.where((l) => l.type == type).toList();
    List<Included> includedList = [];
    for (var include in includedData) {
      includedList.add(includeds.firstWhere((l) => l.id == include.id));
    }
    return includedList;
  }
}
