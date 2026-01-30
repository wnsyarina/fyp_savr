import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/models/user_role.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  static CollectionReference get users => _firestore.collection('users');
  static CollectionReference get restaurants => _firestore.collection('restaurants');
  static CollectionReference get foods => _firestore.collection('foods');
  static CollectionReference get orders => _firestore.collection('orders');
  static CollectionReference get payments => _firestore.collection('payments');
  static CollectionReference get wallets => _firestore.collection('wallets');
  static CollectionReference get categories => _firestore.collection('categories');
  static CollectionReference get aiTrainingData => _firestore.collection('ai_training_data');
  static CollectionReference get mlModels => _firestore.collection('ml_models');
  static CollectionReference get merchantAnalytics => _firestore.collection('merchant_analytics');
  static CollectionReference get emailQueue => _firestore.collection('email_queue');

  // Getters
  static FirebaseAuth get auth => _auth;
  static FirebaseFirestore get firestore => _firestore;

  // ========== USER & ROLE MANAGEMENT ==========
  
  static Future<UserRole> getUserRole(String uid) async {
    try {
      final doc = await users.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final role = data?['role'] as String?;

        if (role == 'super_admin') {
          return UserRole.superAdmin;
        }

        return UserRole.fromString(role ?? 'customer');
      }
      return UserRole.customer;
    } catch (e) {
      print('Error getting user role: $e');
      return UserRole.customer;
    }
  }

  static Future<void> setUserRole(String uid, UserRole role) async {
    await users.doc(uid).set({
      'role': role.value,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<UserRole> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await getUserRole(user.uid);
    }
    return UserRole.customer;
  }

  static Future<bool> isMerchantVerified(String uid) async {
    try {
      final doc = await users.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final role = data?['role'] as String?;
        final verificationStatus = data?['restaurantVerificationStatus'] as String?;
        return role == UserRole.merchant.value && verificationStatus == 'approved';
      }
      return false;
    } catch (e) {
      print('Error checking merchant verification: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await users.doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  static Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await users.doc(uid).set(updates, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  static Future<bool> checkEmailExists(String email) async {
    try {
      final query = await users.where('email', isEqualTo: email).limit(1).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  static Stream<QuerySnapshot> getUsersByRole(UserRole role) {
    return users
        .where('role', isEqualTo: role.value)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ========== RESTAURANT MANAGEMENT ==========

  static Future<Map<String, dynamic>?> getMerchantRestaurant(String merchantId) async {
    try {
      final query = await restaurants
          .where('merchantId', isEqualTo: merchantId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        };
      }
      return null;
    } catch (e) {
      print('Error getting merchant restaurant: $e');
      return null;
    }
  }

  static Stream<QuerySnapshot> getPendingMerchantApplications() {
    return restaurants
        .where('verificationStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Future<void> updateMerchantVerificationStatus({
    required String restaurantId,
    required String status,
    required String adminId,
    required String adminName,
    String? notes,
  }) async {
    try {
      await restaurants.doc(restaurantId).update({
        'verificationStatus': status,
        'verifiedBy': adminId,
        'verifiedByName': adminName,
        'verifiedAt': FieldValue.serverTimestamp(),
        'adminNotes': notes,
        'isActive': status == 'approved',
      });

      final restaurantDoc = await restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
      final merchantId = restaurantData?['merchantId'] as String?;
      
      if (merchantId != null) {
        await users.doc(merchantId).update({
          'restaurantVerificationStatus': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating merchant verification: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getRestaurantById(String restaurantId) async {
    try {
      final doc = await restaurants.doc(restaurantId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting restaurant: $e');
      return null;
    }
  }

  static Future<bool> isRestaurantActive(String restaurantId) async {
    try {
      final doc = await restaurants.doc(restaurantId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['isActive'] == true && data?['verificationStatus'] == 'approved';
      }
      return false;
    } catch (e) {
      print('Error checking restaurant status: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRestaurantByMerchantId(String merchantId) async {
    try {
      final query = await restaurants
          .where('merchantId', isEqualTo: merchantId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        };
      }
      return null;
    } catch (e) {
      print('Error getting restaurant by merchant ID: $e');
      return null;
    }
  }

  // ========== UTILITY METHODS ==========

  static Map<String, dynamic> validateAndPrepareData(Map<String, dynamic> data) {
    data.removeWhere((key, value) => value == null);
    
    if (!data.containsKey('updatedAt')) {
      data['updatedAt'] = FieldValue.serverTimestamp();
    }
    
    return data;
  }

  static Future<void> init() async {
    print('Firebase services initialized');
  }

  static Future<void> batchWrite(List<Map<String, dynamic>> operations) async {
    final batch = _firestore.batch();
    
    for (final operation in operations) {
      final collection = operation['collection'] as String;
      final documentId = operation['documentId'] as String?;
      final data = operation['data'] as Map<String, dynamic>;
      final type = operation['type'] as String;
      
      final docRef = _firestore.collection(collection).doc(documentId);
      
      switch (type) {
        case 'set':
          batch.set(docRef, data);
          break;
        case 'update':
          batch.update(docRef, data);
          break;
        case 'delete':
          batch.delete(docRef);
          break;
      }
    }
    
    await batch.commit();
  }
}