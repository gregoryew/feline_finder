import 'RescueGroups.dart';

class PetTileData {
  String? id;
  String? name;
  String? primaryBreed;
  String? cityState;
  String? status;
  String? age;
  String? sex;
  String? size;
  String? picture;
  double? resolutionY;
  String? smallPicture;
  double? smallPictureResolutionY;
  bool? hasVideos;

  PetTileData(petDatum pet, List<Included> included) {
    id = pet.id;
    name = pet.attributes!.name;
    primaryBreed = pet.attributes!.breedPrimary;
    var locationsList = findAllOfACertainType(
        pet, included, "locations", IncludedType.LOCATIONS);
    cityState = locationsList[0].attributes!.citystate;
    var statusList =
        findAllOfACertainType(pet, included, "statuses", IncludedType.STATUSES);
    status = statusList[0].attributes!.name;
    switch (pet.attributes!.ageGroup ?? AgeGroup.YOUNG) {
      case AgeGroup.ADULT:
        age = 'Adult';
        break;
      case AgeGroup.SENIOR:
        age = "Senior";
        break;
      case AgeGroup.YOUNG:
        age = "Kitten";
        break;
      default:
        age = "A?";
    }
    switch (pet.attributes!.sex ?? Sex.MALE) {
      case Sex.FEMALE:
        sex = "Female";
        break;
      case Sex.MALE:
        sex = "Male";
        break;
    }
    switch (pet.attributes!.sizeGroup ?? SizeGroup.MEDIUM) {
      case SizeGroup.LARGE:
        size = "Large";
        break;
      case SizeGroup.MEDIUM:
        size = "Medium";
        break;
      case SizeGroup.SMALL:
        size = "Small";
        break;
      case SizeGroup.X_LARGE:
        size = "X-Large";
        break;
    }
    var picturesList =
        findAllOfACertainType(pet, included, "pictures", IncludedType.PICTURES);
    picture = picturesList.isEmpty
        ? "https://via.placeholder.com/200x90.png?text=Cat+Image+Not+Available"
        : picturesList[0].attributes!.large!.url;
    resolutionY = picturesList.isEmpty
        ? 0
        : picturesList[0].attributes!.large!.resolutionY?.toDouble();
    smallPicture = picturesList.isEmpty
        ? "https://via.placeholder.com/200x90.png?text=Cat+Image+Not+Available"
        : picturesList[0].attributes!.original!.url;
    smallPictureResolutionY = picturesList.isEmpty
        ? 0
        : picturesList[0].attributes!.small!.resolutionY?.toDouble();
    var videoList =
        findAllOfACertainType(pet, included, "videos", IncludedType.VIDEOS);
    //print("@@@@@@@@@@@@@@@@VIDEO LIST = " + videoList.length.toString());
    hasVideos = (videoList.isNotEmpty) ? true : false;
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
