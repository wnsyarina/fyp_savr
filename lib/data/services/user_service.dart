import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class UserService {
  static Future<void> createUser({
    required String uid,
    required String email,
    required String name,
    required String role,
  }) async {
    try {
      await FirebaseService.users.doc(uid).set({
        'email': email,
        'name': name,
        'role': role,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'isEmailVerified': false,
      });
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await FirebaseService.users.doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  static Stream<DocumentSnapshot> getUserStream(String uid) {
    return FirebaseService.users.doc(uid).snapshots();
  }
}