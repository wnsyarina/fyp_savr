import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class GoogleAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final GoogleSignIn _googleSignIn = GoogleSignIn.standard(
    scopes: ['email', 'profile'],
  );

  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

      if (googleUser == null) {
        return await _signInWithGoogleInteractive();
      }

      return await _processGoogleSignIn(googleUser);
    } catch (e) {
      print('Google Sign-In Error (silent): $e');
      return await _signInWithGoogleInteractive();
    }
  }

  static Future<User?> _signInWithGoogleInteractive() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      return await _processGoogleSignIn(googleUser);
    } catch (e) {
      print('Google Sign-In Error (interactive): $e');
      rethrow;
    }
  }

  static Future<User?> _processGoogleSignIn(GoogleSignInAccount googleUser) async {
    try {
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseService.users.doc(user.uid).get();

        if (!userDoc.exists) {
          await FirebaseService.users.doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? 'Google User',
            'email': user.email ?? '',
            'role': 'customer',
            'profileImageUrl': user.photoURL ?? '',
            'isEmailVerified': true,
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          });
        } else {
          await FirebaseService.users.doc(user.uid).update({
            'profileImageUrl': user.photoURL ?? '',
            'updatedAt': DateTime.now(),
          });
        }
      }

      return user;
    } catch (e) {
      print('Error processing Google sign-in: $e');
      rethrow;
    }
  }

  static Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Google Sign-Out Error: $e');
      rethrow;
    }
  }

  static bool isSignedInWithGoogle() {
    final user = _auth.currentUser;
    return user != null &&
        user.providerData.any((userInfo) => userInfo.providerId == 'google.com');
  }

  static Future<GoogleSignInAccount?> getGoogleUserData() async {
    try {
      return await _googleSignIn.currentUser;
    } catch (e) {
      print('Error getting Google user data: $e');
      return null;
    }
  }
}