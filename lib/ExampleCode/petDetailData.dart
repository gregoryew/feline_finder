import 'package:flutter/widgets.dart';
import 'Media.dart';
import 'RescueGroups.dart';
import '../screens/globals.dart' as globals;

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
  List<Widget> media = [];
  List<double> mediaWidths = [];
  String? organizationID = "";
  String? organizationName = "";
  String? description = "";

  PetDetailData(
      petDatum pet, List<Included> included, List<Relationship> relationships) {
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
    double total = 0;
    mediaWidths.add(0);
    for (int i = 0; i < picturesIncluded.length; i++) {
      var photo = SmallPhoto(i, picturesIncluded[i].attributes!.large!.url!);
      var large = picturesIncluded[i].attributes!.large!;
      double width = large.resolutionX! * (300 / large.resolutionY!);
      total += width;
      mediaWidths.add(total);
      media.add(photo);
    }
    List<Included> videoListIncluded = findAllOfACertainType(
        pet, included, "videourls", IncludedType.VIDEOURLS);
    for (int i = 0; i < videoListIncluded.length; i++) {
      var video = YouTubeVideo(
          videoListIncluded[i].attributes!.urlThumbnail ?? "",
          videoListIncluded[i].attributes?.name ?? "",
          videoListIncluded[i].attributes?.videoId ?? "");
      total += 330;
      mediaWidths.add(total);
      media.add(video);
    }
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
