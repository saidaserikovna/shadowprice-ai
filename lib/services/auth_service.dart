import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw const AuthFailure(
          'Google sign-in is not configured correctly. Add SHA1 and SHA256 for the Android app in Firebase, then download a fresh google-services.json.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      await _createUserProfile(userCred.user!);
      notifyListeners();
      return userCred;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign in Firebase error: ${e.code} ${e.message}');
      throw AuthFailure(_mapFirebaseAuthError(e));
    } on PlatformException catch (e) {
      debugPrint('Google sign in platform error: ${e.code} ${e.message}');
      throw AuthFailure(_mapGooglePlatformError(e));
    } catch (e) {
      debugPrint('Google sign in error: $e');
      throw const AuthFailure(
        'Google sign-in failed. Check Firebase Google Sign-In settings and the Google account on the emulator.',
      );
    }
  }

  // Email/Password Sign Up
  Future<UserCredential> signUpWithEmail(String email, String password, String name) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCred.user!.updateDisplayName(name);
      await userCred.user!.sendEmailVerification();
      await _createUserProfile(userCred.user!, name: name);
      notifyListeners();
      return userCred;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign up error: ${e.code} ${e.message}');
      throw AuthFailure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Email sign up error: $e');
      throw const AuthFailure('Sign-up failed. Please try again.');
    }
  }

  // Email/Password Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return userCred;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign in error: ${e.code} ${e.message}');
      throw AuthFailure(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Email sign in error: $e');
      throw const AuthFailure('Sign-in failed. Please try again.');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }

  // Create/update user profile in Firestore
  Future<void> _createUserProfile(User user, {String? name}) async {
    final docRef = _db.collection('profiles').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'name': name ?? user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email,
        'avatarUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    final doc = await _db.collection('profiles').doc(currentUser!.uid).get();
    return doc.data();
  }

  // Update user profile
  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    if (currentUser == null) return;
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    await _db.collection('profiles').doc(currentUser!.uid).update(updates);
    notifyListeners();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'This email is already linked to a different sign-in method.';
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'The sign-in credentials are invalid.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account was found for that email.';
      case 'wrong-password':
      case 'invalid-password':
        return 'The password is incorrect.';
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'weak-password':
        return 'The password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  String _mapGooglePlatformError(PlatformException e) {
    final message = (e.message ?? '').toLowerCase();
    final details = (e.details ?? '').toString().toLowerCase();
    final combined = '$message $details';

    if (e.code == 'sign_in_canceled' || combined.contains('12501')) {
      return 'Google sign-in was canceled.';
    }

    if (e.code == 'network_error' || combined.contains('network')) {
      return 'Network error. Check your internet connection.';
    }

    if (e.code == 'sign_in_failed' ||
        combined.contains('apiexception: 10') ||
        combined.contains('developer error')) {
      return 'Google sign-in is still misconfigured. Add SHA1 and SHA256 in Firebase and install the latest google-services.json file.';
    }

    if (combined.contains('com.google.android.gms') ||
        combined.contains('play services')) {
      return 'Google Play Services is not working correctly on the emulator. Use a Google Play system image.';
    }

    return e.message ?? 'Google sign-in failed.';
  }
}
