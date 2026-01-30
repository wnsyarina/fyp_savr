import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseService.auth;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<User?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _saveFCMTokenForUser(user.uid);
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  static Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _saveFCMTokenForUser(user.uid);
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ========== FCM TOKEN MANAGEMENT ==========

  static Future<void> _saveFCMTokenForUser(String userId) async {
    try {
      print('FCM token for user $userId');
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        print('No FCM token available');
        return;
      }

      print('📱 Token: ${token.substring(0, min(50, token.length))}...');


      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('FCM token saved for user $userId');

    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  static Future<void> refreshFCMToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _saveFCMTokenForUser(user.uid);
    }
  }


  static Future<List<String>> getCurrentUserFCMTokens() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final tokens = doc.data()?['fcmTokens'] as List<dynamic>?;

    return tokens?.cast<String>() ?? [];
  }
}