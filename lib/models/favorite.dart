class Favorites {
  // 1
  String userid;
  List<String> favorites = [];

  String? referenceId;
/*
  factory Favorites.fromSnapshot(DocumentSnapshot snapshot) {
    final newFavorite = Favorites.fromJson(snapshot.data() as Map<String, dynamic>);
    newFavorite.referenceId = snapshot.reference.id;
    return newFavorite;
  }
*/

  // 2
  Favorites(this.userid, {required this.favorites, this.referenceId});
  // 3
  factory Favorites.fromJson(Map<String, dynamic> json) =>
      _favoritesFromJson(json);
  // 4
  Map<String, dynamic> toJson() => _favoritesToJson(this);

  @override
  String toString() => 'Favorites<$favorites>';
}

// 1
Favorites _favoritesFromJson(Map<String, dynamic> json) {
  return Favorites(
    json['userid'] as String,
    favorites: (json['favorites'] as List<String>).toList(),
  );
}

// 2
Map<String, dynamic> _favoritesToJson(Favorites instance) => <String, dynamic>{
      'userid': instance.userid,
      'favorites': instance.favorites,
    };
