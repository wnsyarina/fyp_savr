import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class RatingService {
  static Future<bool> hasUserRatedOrder(String orderId, String userId) async {
    try {
      final ratingDoc = await FirebaseService.orders
          .doc(orderId)
          .collection('ratings')
          .doc(userId)
          .get();
      return ratingDoc.exists;
    } catch (e) {
      print('Error checking if user rated order: $e');
      return false;
    }
  }

  static Future<void> submitOrderRating({
    required String orderId,
    required String restaurantId,
    required String userId,
    required String userName,
    required int rating,
    String? feedback,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      final batch = FirebaseService.firestore.batch();

      final ratingRef = FirebaseService.orders
          .doc(orderId)
          .collection('ratings')
          .doc(userId);

      batch.set(ratingRef, {
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'feedback': feedback ?? '',
        'orderId': orderId,
        'restaurantId': restaurantId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

      double currentRating = 0.0;
      int totalReviews = 0;

      if (restaurantData != null) {
        currentRating = (restaurantData['rating'] ?? 0.0).toDouble();
        totalReviews = (restaurantData['totalReviews'] ?? 0).toInt();
      }

      final newTotalReviews = totalReviews + 1;
      final newAverageRating = ((currentRating * totalReviews) + rating) / newTotalReviews;

      batch.update(FirebaseService.restaurants.doc(restaurantId), {
        'rating': newAverageRating,
        'totalReviews': newTotalReviews,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      print('Rating submitted successfully: $rating stars for restaurant $restaurantId');
    } catch (e) {
      print('Error submitting rating: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getRestaurantRatingSummary(String restaurantId) async {
    try {
      final doc = await FirebaseService.restaurants.doc(restaurantId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'averageRating': (data?['rating'] ?? 0.0).toDouble(),
          'totalReviews': (data?['totalReviews'] ?? 0).toInt(),
          'restaurantName': data?['name'] ?? '',
          'restaurantId': restaurantId,
        };
      }
      return null;
    } catch (e) {
      print('Error getting restaurant rating: $e');
      return null;
    }
  }

  static Stream<QuerySnapshot> getRestaurantRatings(String restaurantId, {int limit = 50}) {
    return FirebaseService.firestore
        .collectionGroup('ratings')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  static Stream<QuerySnapshot> getOrderRatings(String orderId) {
    return FirebaseService.orders
        .doc(orderId)
        .collection('ratings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<Map<String, dynamic>> canUserRateOrder({
    required String orderId,
    required String restaurantId,
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? FirebaseService.auth.currentUser?.uid;
      if (currentUserId == null) {
        return {
          'canRate': false,
          'reason': 'User not logged in',
        };
      }

      final orderDoc = await FirebaseService.orders.doc(orderId).get();
      if (!orderDoc.exists) {
        return {
          'canRate': false,
          'reason': 'Order not found',
        };
      }

      final orderData = orderDoc.data() as Map<String, dynamic>?;
      final orderStatus = orderData?['status'] ?? '';
      final orderRestaurantId = orderData?['restaurantId'] ?? '';

      if (orderStatus != 'completed') {
        return {
          'canRate': false,
          'reason': 'Order is not completed',
          'currentStatus': orderStatus,
        };
      }

      if (orderRestaurantId != restaurantId) {
        return {
          'canRate': false,
          'reason': 'Restaurant ID mismatch',
        };
      }

      final hasRated = await hasUserRatedOrder(orderId, currentUserId);
      if (hasRated) {
        return {
          'canRate': false,
          'reason': 'Already rated',
        };
      }

      return {
        'canRate': true,
        'reason': 'Can rate',
        'userId': currentUserId,
        'orderStatus': orderStatus,
      };
    } catch (e) {
      print('Error checking if user can rate: $e');
      return {
        'canRate': false,
        'reason': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>?> getUserRatingForOrder(String orderId, String userId) async {
    try {
      final ratingDoc = await FirebaseService.orders
          .doc(orderId)
          .collection('ratings')
          .doc(userId)
          .get();

      if (ratingDoc.exists) {
        final data = ratingDoc.data() as Map<String, dynamic>?;
        return {
          'rating': data?['rating'] ?? 0,
          'feedback': data?['feedback'] ?? '',
          'createdAt': data?['createdAt'],
          'documentId': ratingDoc.id,
        };
      }
      return null;
    } catch (e) {
      print('Error getting user rating: $e');
      return null;
    }
  }

  static Future<void> updateRating({
    required String orderId,
    required String userId,
    required int newRating,
    String? newFeedback,
  }) async {
    try {
      final ratingRef = FirebaseService.orders
          .doc(orderId)
          .collection('ratings')
          .doc(userId);

      final currentRatingDoc = await ratingRef.get();
      final currentData = currentRatingDoc.data() as Map<String, dynamic>?;
      final currentRating = currentData?['rating'] ?? 0;
      final restaurantId = currentData?['restaurantId'] ?? '';

      if (restaurantId.isEmpty) {
        throw Exception('Restaurant ID not found in rating');
      }

      final batch = FirebaseService.firestore.batch();

      final updateData = <String, dynamic>{
        'rating': newRating,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newFeedback != null) {
        updateData['feedback'] = newFeedback;
      }

      batch.update(ratingRef, updateData);

      if (currentRating != newRating) {
        final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
        final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

        if (restaurantData != null) {
          final currentAvg = (restaurantData['rating'] ?? 0.0).toDouble();
          final totalReviews = (restaurantData['totalReviews'] ?? 0).toInt();

          final totalSum = (currentAvg * totalReviews) - currentRating + newRating;
          final newAverage = totalSum / totalReviews;

          batch.update(FirebaseService.restaurants.doc(restaurantId), {
            'rating': newAverage,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error updating rating: $e');
      rethrow;
    }
  }

  static Future<void> deleteRating({
    required String orderId,
    required String userId,
  }) async {
    try {
      final ratingRef = FirebaseService.orders
          .doc(orderId)
          .collection('ratings')
          .doc(userId);

      final ratingDoc = await ratingRef.get();
      final ratingData = ratingDoc.data() as Map<String, dynamic>?;
      final rating = ratingData?['rating'] ?? 0;
      final restaurantId = ratingData?['restaurantId'] ?? '';

      if (restaurantId.isEmpty) {
        throw Exception('Restaurant ID not found in rating');
      }

      final batch = FirebaseService.firestore.batch();

      batch.delete(ratingRef);

      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

      if (restaurantData != null) {
        final currentAvg = (restaurantData['rating'] ?? 0.0).toDouble();
        final totalReviews = (restaurantData['totalReviews'] ?? 0).toInt();

        if (totalReviews > 1) {
          final totalSum = (currentAvg * totalReviews) - rating;
          final newTotalReviews = totalReviews - 1;
          final newAverage = newTotalReviews > 0 ? totalSum / newTotalReviews : 0.0;

          batch.update(FirebaseService.restaurants.doc(restaurantId), {
            'rating': newAverage,
            'totalReviews': newTotalReviews,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(FirebaseService.restaurants.doc(restaurantId), {
            'rating': 0.0,
            'totalReviews': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting rating: $e');
      rethrow;
    }
  }

  static Future<Map<String, int>> getRatingDistribution(String restaurantId) async {
    try {
      final ratings = await FirebaseService.firestore
          .collectionGroup('ratings')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      final distribution = <String, int>{'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};

      for (final doc in ratings.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final rating = data['rating'] as int?;
        if (rating != null && rating >= 1 && rating <= 5) {
          final ratingKey = rating.toString();
          distribution[ratingKey] = (distribution[ratingKey] ?? 0) + 1;
        }
      }

      return distribution;
    } catch (e) {
      print('Error getting rating distribution: $e');
      return {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
    }
  }

  static List<bool> ratingToStars(int rating) {
    return List.generate(5, (index) => index < rating);
  }

  static Map<String, double> calculateStarPercentages(Map<String, int> distribution, int totalReviews) {
    final percentages = <String, double>{};

    for (int i = 5; i >= 1; i--) {
      final count = distribution[i] ?? 0;
      percentages[i.toString()] = totalReviews > 0 ? (count / totalReviews * 100) : 0.0;
    }

    return percentages;
  }

}
