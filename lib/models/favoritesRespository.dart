import 'package:cloud_firestore/cloud_firestore.dart';

import 'favorite.dart';

class DataRepository {
  // 2
  Stream<QuerySnapshot> getStream() {
    return collection.snapshots();
  }

  // 3
  Future<DocumentReference> addPet(Favorites favorites) {
    return collection.add(favorites.toJson());
  }

  // 4
  void updatePet(Favorites favorites) async {
    await collection.doc(favorites.referenceId).update(favorites.toJson());
  }

  // 5
  void deletePet(Favorites favorite) async {
    await collection.doc(favorite.referenceId).delete();
  }
}
