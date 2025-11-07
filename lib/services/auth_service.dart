import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is authenticated (not anonymous)
  bool get isAuthenticated =>
      _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  // Check if user is authenticated (including anonymous)
  bool get isAuthenticatedOrAnonymous => _auth.currentUser != null;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user account
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Create adopter document in Firestore
      await _firestore
          .collection('adopters')
          .doc(userCredential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'lastLogin': DateTime.now(),
        'logins': 1,
      }, SetOptions(merge: true));

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login in Firestore
      final adopterDoc =
          _firestore.collection('adopters').doc(userCredential.user!.uid);
      final docSnapshot = await adopterDoc.get();

      if (docSnapshot.exists) {
        final logins = docSnapshot.data()?['logins'] ?? 0;
        await adopterDoc.update({
          'lastLogin': DateTime.now(),
          'logins': logins + 1,
        });
      } else {
        // Create adopter document if it doesn't exist
        await adopterDoc.set({
          'name': userCredential.user?.displayName ?? '',
          'email': email,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
          'lastLogin': DateTime.now(),
          'logins': 1,
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Sign in anonymously (keep for fallback)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      print('Anonymous sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Handle auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return 'An error occurred: ${e.message ?? "Unknown error"}';
    }
  }
}
