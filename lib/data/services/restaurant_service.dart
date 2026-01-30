import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/utils/constants.dart';

class RestaurantService {

  static Stream<QuerySnapshot> _getEmptyStream() {
    return FirebaseService.restaurants
        .where('nonexistent_field', isEqualTo: 'empty')
        .limit(0)
        .snapshots();
  }

  static Future<String> createRestaurant({
    required String merchantId,
    required String name,
    required String description,
    required String address,
    required String phone,
    required double latitude,
    required double longitude,
    required List<String> cuisineTypes,
    Map<String, dynamic>? documents,
    String verificationStatus = AppConstants.statusPending,
    String? logoBase64,
    String? coverImageBase64,
  }) async {
    try {
      Map<String, dynamic> formattedDocuments = {};
      if (documents != null && documents.isNotEmpty) {
        formattedDocuments = {
          'businessRegistration': documents['business_registration'] ??
              documents['businessRegistration'] ?? '',
          'ownerId': documents['owner_id'] ?? documents['ownerId'] ?? '',
          'healthPermit': documents['health_permit'] ??
              documents['healthPermit'] ?? '',
          'restaurantPhoto': documents['restaurant_photo'] ??
              documents['restaurantPhoto'] ?? '',
        };
      }

      await FirebaseService.restaurants.doc(merchantId).set({
        'merchantId': merchantId,
        'name': name,
        'description': description,
        'address': address,
        'phone': phone,
        'location': GeoPoint(latitude, longitude),
        'cuisineTypes': cuisineTypes,
        'logoBase64': logoBase64,
        'coverImageBase64': coverImageBase64,
        'verificationStatus': verificationStatus,
        'documents': formattedDocuments,
        'isActive': false,
        'isVerified': false,
        'rating': 0.0,
        'totalReviews': 0,
        'deliveryTime': '20-30 min',
        'searchKeywords': _generateSearchKeywords(name, cuisineTypes),
        'openingHours': getDefaultOpeningHours(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'adminNotes': '',
      });

      return merchantId;

    } catch (e) {
      print('Error creating restaurant: $e');
      rethrow;
    }
  }


  static Future<String?> getRestaurantIdByMerchantId(String merchantId) async {
    try {
      final doc = await FirebaseService.restaurants.doc(merchantId).get();

      if (doc.exists) {
        return merchantId;
      }
      return null;
    } catch (e) {
      print('Error getting restaurant ID by merchant ID: $e');
      return null;
    }
  }

  static Future<String?> getCurrentMerchantRestaurantId() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user == null) return null;

      final restaurantDoc = await FirebaseService.restaurants.doc(user.uid).get();
      if (restaurantDoc.exists) {
        return user.uid;
      }

      return null;
    } catch (e) {
      print('Error getting current merchant restaurant ID: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentMerchantRestaurant() async {
    try {
      final restaurantId = await getCurrentMerchantRestaurantId();
      if (restaurantId == null) return null;

      return await getRestaurantById(restaurantId);
    } catch (e) {
      print('Error getting current merchant restaurant: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getRestaurantByMerchantId(String merchantId) async {
    try {
      return await getRestaurantById(merchantId);
    } catch (e) {
      print('Error getting restaurant by merchant ID: $e');
      return null;
    }
  }

  static Stream<QuerySnapshot> getCurrentMerchantFoods() {
    return Stream.fromFuture(getCurrentMerchantRestaurantId()).asyncExpand((restaurantId) {
      if (restaurantId == null) {
        return _getEmptyStream();
      }

      return FirebaseService.foods
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .snapshots();
    });
  }

  static Stream<QuerySnapshot> getCurrentMerchantActiveFoods() {
    return Stream.fromFuture(getCurrentMerchantRestaurantId()).asyncExpand((restaurantId) {
      if (restaurantId == null) {
        return _getEmptyStream();
      }

      return FirebaseService.foods
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('quantityAvailable', isGreaterThan: 0)
          .where('pickupEnd', isGreaterThan: DateTime.now())
          .orderBy('pickupEnd')
          .snapshots();
    });
  }

  static Future<String?> getMerchantVerificationStatus() async {
    try {
      final restaurant = await getCurrentMerchantRestaurant();
      return restaurant?['verificationStatus'] as String?;
    } catch (e) {
      print('Error getting merchant verification status: $e');
      return null;
    }
  }

  static Future<bool> isCurrentMerchantVerified() async {
    final status = await getMerchantVerificationStatus();
    return status == 'approved';
  }

  static Future<Map<String, dynamic>> getMerchantStats() async {
    try {
      final restaurantId = await getCurrentMerchantRestaurantId();
      if (restaurantId == null) {
        return {
          'restaurantId': null,
          'isVerified': false,
          'isActive': false,
          'verificationStatus': 'pending',
          'hasRestaurant': false,
        };
      }

      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

      if (restaurantData == null) {
        return {
          'restaurantId': restaurantId,
          'isVerified': false,
          'isActive': false,
          'verificationStatus': 'pending',
          'hasRestaurant': true,
        };
      }

      return {
        'restaurantId': restaurantId,
        'isVerified': restaurantData['isVerified'] ?? false,
        'isActive': restaurantData['isActive'] ?? false,
        'verificationStatus': restaurantData['verificationStatus'] ?? 'pending',
        'hasRestaurant': true,
        'name': restaurantData['name'] ?? '',
        'address': restaurantData['address'] ?? '',
        'phone': restaurantData['phone'] ?? '',
      };
    } catch (e) {
      print('Error getting merchant stats: $e');
      return {
        'restaurantId': null,
        'isVerified': false,
        'isActive': false,
        'verificationStatus': 'pending',
        'hasRestaurant': false,
        'error': e.toString(),
      };
    }
  }

  static Future<void> updateRestaurant(String restaurantId, Map<String, dynamic> data) async {
    try {
      if (data.containsKey('name') || data.containsKey('cuisineTypes')) {
        final currentData = await _getRestaurantData(restaurantId);
        final name = data['name'] ?? currentData['name'];
        final cuisineTypes = data['cuisineTypes'] ?? currentData['cuisineTypes'];

        data['searchKeywords'] = _generateSearchKeywords(name, List<String>.from(cuisineTypes));
      }

      await FirebaseService.restaurants.doc(restaurantId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating restaurant: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getRestaurantById(String restaurantId) async {
    try {
      final doc = await FirebaseService.restaurants.doc(restaurantId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        };
      }
      return null;
    } catch (e) {
      print('Error getting restaurant by ID: $e');
      return null;
    }
  }

  static Stream<DocumentSnapshot> getRestaurantStream(String restaurantId) {
    return FirebaseService.restaurants.doc(restaurantId).snapshots();
  }

  static Stream<QuerySnapshot> getAllRestaurants() {
    return FirebaseService.restaurants
        .where('isActive', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'approved')
        .orderBy('rating', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getRestaurantsByCuisine(String cuisineType) {
    return FirebaseService.restaurants
        .where('isActive', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'approved')
        .where('cuisineTypes', arrayContains: cuisineType)
        .orderBy('rating', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> searchRestaurants(String query) {
    if (query.isEmpty) {
      return getAllRestaurants();
    }

    final lowercaseQuery = query.toLowerCase();

    return FirebaseService.restaurants
        .where('isActive', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'approved')
        .where('searchKeywords', arrayContains: lowercaseQuery)
        .orderBy('rating', descending: true)
        .snapshots();
  }


  static Stream<QuerySnapshot> getPendingVerifications() {
    return FirebaseService.restaurants
        .where('verificationStatus', isEqualTo: AppConstants.statusPending)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> updateVerificationStatus({
    required String restaurantId,
    required String status,
    required String adminId,
    required String adminName,
    String notes = '',
  }) async {
    final updateData = {
      'verificationStatus': status,
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': adminId,
      'verifiedByName': adminName,
      'adminNotes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == AppConstants.statusApproved) {
      updateData['isActive'] = true;
      updateData['isVerified'] = true;
    } else if (status == AppConstants.statusRejected) {
      updateData['isActive'] = false;
      updateData['isVerified'] = false;
    }

    await FirebaseService.restaurants.doc(restaurantId).update(updateData);
  }

  static Stream<QuerySnapshot> getAllRestaurantsForAdmin() {
    return FirebaseService.restaurants
        .orderBy('createdAt', descending: true)
        .snapshots();
  }


  static Future<void> updateOpeningStatus(String restaurantId, bool isOpen) async {
    await FirebaseService.restaurants.doc(restaurantId).update({
      'isOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateOpeningHours(String restaurantId, Map<String, dynamic> openingHours) async {
    await FirebaseService.restaurants.doc(restaurantId).update({
      'openingHours': openingHours,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>> getRestaurantOpeningHours(String restaurantId) async {
    try {
      final doc = await FirebaseService.restaurants.doc(restaurantId).get();
      final data = doc.data() as Map<String, dynamic>?;
      final hours = data?['openingHours'] as Map<String, dynamic>?;
      return hours ?? getDefaultOpeningHours();
    } catch (e) {
      print('Error getting opening hours: $e');
      return getDefaultOpeningHours();
    }
  }

  static Future<void> updateRestaurantOpeningHoursByMerchantId({
    required String merchantId,
    required Map<String, dynamic> openingHours,
  }) async {
    try {
      final restaurantId = await getRestaurantIdByMerchantId(merchantId);
      if (restaurantId == null) {
        throw Exception('Restaurant not found for merchant: $merchantId');
      }

      await updateOpeningHours(restaurantId, openingHours);
    } catch (e) {
      print('Error updating opening hours by merchant ID: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRestaurantOpeningHoursByMerchantId(String merchantId) async {
    try {
      final restaurantId = await getRestaurantIdByMerchantId(merchantId);
      if (restaurantId == null) {
        return getDefaultOpeningHours();
      }

      return await getRestaurantOpeningHours(restaurantId);
    } catch (e) {
      print('Error getting opening hours by merchant ID: $e');
      return getDefaultOpeningHours();
    }
  }


  static List<String> _generateSearchKeywords(String name, List<String> cuisineTypes) {
    final keywords = <String>{};

    keywords.addAll(name.toLowerCase().split(' '));
    keywords.addAll(cuisineTypes.map((cuisine) => cuisine.toLowerCase()));

    for (final word in name.toLowerCase().split(' ')) {
      if (word.length > 2) {
        keywords.add(word);
      }
    }

    return keywords.where((word) => word.length > 2).toList();
  }

  static Map<String, dynamic> getDefaultOpeningHours() {
    return {
      'monday': {'open': '10:00', 'close': '22:00', 'isClosed': false},
      'tuesday': {'open': '10:00', 'close': '22:00', 'isClosed': false},
      'wednesday': {'open': '10:00', 'close': '22:00', 'isClosed': false},
      'thursday': {'open': '10:00', 'close': '22:00', 'isClosed': false},
      'friday': {'open': '10:00', 'close': '23:00', 'isClosed': false},
      'saturday': {'open': '10:00', 'close': '23:00', 'isClosed': false},
      'sunday': {'open': '10:00', 'close': '22:00', 'isClosed': false},
    };
  }

  static Future<Map<String, dynamic>> _getRestaurantData(String restaurantId) async {
    final doc = await FirebaseService.restaurants.doc(restaurantId).get();
    return doc.data() as Map<String, dynamic>? ?? {};
  }

  static Future<bool> isRestaurantCurrentlyOpen(String restaurantId) async {
    try {
      final hours = await getRestaurantOpeningHours(restaurantId);
      final now = DateTime.now();
      final dayName = _getDayName(now.weekday);

      final dayHours = hours[dayName] as Map<String, dynamic>?;
      if (dayHours == null || dayHours['isClosed'] == true) {
        return false;
      }

      final openTime = dayHours['open'] as String?;
      final closeTime = dayHours['close'] as String?;

      if (openTime == null || closeTime == null) {
        return false;
      }

      return _isTimeBetween(now, openTime, closeTime);
    } catch (e) {
      print('Error checking if restaurant is open: $e');
      return false;
    }
  }

  static Future<double> getRestaurantRating(String restaurantId) async {
    try {
      final doc = await FirebaseService.restaurants.doc(restaurantId).get();
      final data = doc.data() as Map<String, dynamic>?;
      return (data?['rating'] ?? 0.0).toDouble();
    } catch (e) {
      print('Error getting restaurant rating: $e');
      return 0.0;
    }
  }

  static Future<void> updateRestaurantRating(String restaurantId, double newRating, int newReviewCount) async {
    await FirebaseService.restaurants.doc(restaurantId).update({
      'rating': newRating,
      'totalReviews': newReviewCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<bool> isRestaurantOpen(String restaurantId) async {
    try {
      final doc = await FirebaseService.restaurants.doc(restaurantId).get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['isOpen'] ?? false;
    } catch (e) {
      print('Error checking restaurant open status: $e');
      return false;
    }
  }

  static Future<void> updateRestaurantPickupTime({
    required String restaurantId,
    required String pickupTime,
  }) async {
    try {
      await FirebaseService.restaurants.doc(restaurantId).update({
        'pickupTime': pickupTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating pickup time: $e');
      rethrow;
    }
  }

  static Future<String> getRestaurantPickupTime(String restaurantId) async {
    try {
      final doc = await FirebaseService.restaurants.doc(restaurantId).get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['pickupTime'] as String? ?? '20-30'; // Default fallback
    } catch (e) {
      print('Error getting pickup time: $e');
      return '20-30';
    }
  }


  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  static bool _isTimeBetween(DateTime now, String openTime, String closeTime) {
    try {
      final open = _parseTime(openTime);
      final close = _parseTime(closeTime);
      final current = TimeOfDay(hour: now.hour, minute: now.minute);

      if (close.hour < open.hour) {
        return _compareTimeOfDay(current, open) >= 0 || _compareTimeOfDay(current, close) <= 0;
      }

      return _compareTimeOfDay(current, open) >= 0 && _compareTimeOfDay(current, close) <= 0;
    } catch (e) {
      return false;
    }
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour - b.hour;
    return a.minute - b.minute;
  }
}