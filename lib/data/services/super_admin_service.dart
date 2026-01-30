import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class SuperAdminService {
  static Stream<QuerySnapshot> getPendingVerifications() {
    return FirebaseService.restaurants
        .where('verificationStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getAllRestaurants() {
    return FirebaseService.restaurants
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<DocumentSnapshot> getRestaurant(String restaurantId) async {
    return await FirebaseService.restaurants.doc(restaurantId).get();
  }

  static Future<void> updateVerificationStatus({
    required String restaurantId,
    required String status,
    required String superAdminId,
    required String superAdminName,
    String notes = '',
    bool sendEmail = true,
  }) async {
    final updateData = {
      'verificationStatus': status,
      'verifiedAt': DateTime.now(),
      'verifiedBy': superAdminId,
      'verifiedByName': superAdminName,
      'adminNotes': notes,
      'updatedAt': DateTime.now(),
    };

    if (status == 'approved') {
      updateData['isActive'] = true;
    } else if (status == 'rejected') {
      updateData['isActive'] = false;
    }

    await FirebaseService.restaurants.doc(restaurantId).update(updateData);

    if (sendEmail) {
      await _sendVerificationEmail(restaurantId, status, notes);
    }
  }

  static Future<void> _sendVerificationEmail(
      String restaurantId,
      String status,
      String notes,
      ) async {
    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurant = restaurantDoc.data() as Map<String, dynamic>;
      final merchantId = restaurant['merchantId'];

      final merchantDoc = await FirebaseService.users.doc(merchantId).get();
      final merchant = merchantDoc.data() as Map<String, dynamic>;
      final merchantEmail = merchant['email'];
      final merchantName = merchant['name'];
      final restaurantName = restaurant['name'];

      final emailData = {
        'to': merchantEmail,
        'subject': 'Restaurant Verification Update - $restaurantName',
        'message': _buildEmailMessage(merchantName, restaurantName, status, notes),
        'type': 'verification_update',
      };

      await FirebaseService.firestore.collection('email_queue').add({
        ...emailData,
        'createdAt': DateTime.now(),
        'status': 'pending',
      });

      print('Email queued for: $merchantEmail');
    } catch (e) {
      print('Error sending email: $e');
    }
  }

  static String _buildEmailMessage(
      String merchantName,
      String restaurantName,
      String status,
      String notes,
      ) {
    final statusText = status == 'approved' ? 'APPROVED' : 'REJECTED';

    String message = '''
Hello $merchantName,

Your restaurant "$restaurantName" verification has been $statusText.

''';

    if (status == 'approved') {
      message += '''
Congratulations! Your restaurant has been approved and is now live on Savr.

You can now:
• Add food listings
• Manage your restaurant profile
• Start receiving orders

Login to your merchant dashboard to get started.
''';
    } else {
      message += '''
Unfortunately, your restaurant application was not approved at this time.

Reason: ${notes.isNotEmpty ? notes : 'Please check your submitted documents for accuracy.'}

You can:
1. Review your submitted documents
2. Make necessary corrections
3. Resubmit your application

If you have questions, please contact our support team.

Thank you for your understanding.
''';
    }

    message += '''

Best regards,
Savr Team
''';

    return message;
  }

  static Stream<QuerySnapshot> getAllUsers() {
    return FirebaseService.users
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> updateUserRole(String userId, String newRole) async {
    final roleToSet = newRole == 'admin' ? 'super_admin' : newRole;

    await FirebaseService.users.doc(userId).update({
      'role': roleToSet,
      'updatedAt': DateTime.now(),
    });

    print('User $userId role updated to: $roleToSet');
  }

  static Future<Map<String, dynamic>> getPlatformStats() async {
    final usersCount = await FirebaseService.users.count().get();
    final restaurantsCount = await FirebaseService.restaurants.count().get();
    final pendingCount = await FirebaseService.restaurants
        .where('verificationStatus', isEqualTo: 'pending')
        .count()
        .get();
    final ordersCount = await FirebaseService.orders.count().get();

    return {
      'totalUsers': usersCount.count,
      'totalRestaurants': restaurantsCount.count,
      'pendingVerifications': pendingCount.count,
      'totalOrders': ordersCount.count,
    };
  }

  static Future<Map<String, dynamic>> deleteUser(String userId, String userRole) async {
    try {
      final userDoc = await FirebaseService.users.doc(userId).get();
      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? 'Unknown User';
      final userEmail = userData['email'] ?? 'No Email';

      final batch = FirebaseService.firestore.batch();

      final userRef = FirebaseService.users.doc(userId);
      batch.delete(userRef);

      final restaurantRef = FirebaseService.restaurants.doc(userId);
      final restaurantDoc = await restaurantRef.get();

      if (restaurantDoc.exists) {
        batch.delete(restaurantRef);
      } else {
        print('ℹNo restaurant document found for user: $userId');
      }

      final foodsQuery = await FirebaseService.foods
          .where('restaurantId', isEqualTo: userId)
          .get();

      for (final foodDoc in foodsQuery.docs) {
        batch.delete(foodDoc.reference);
      }
      print('${foodsQuery.docs.length} food items will be deleted');

      final restaurantOrdersQuery = await FirebaseService.orders
          .where('restaurantId', isEqualTo: userId)
          .get();

      for (final orderDoc in restaurantOrdersQuery.docs) {
        batch.delete(orderDoc.reference);
      }
      print('${restaurantOrdersQuery.docs.length} merchant orders will be deleted');

      final customerOrdersQuery = await FirebaseService.orders
          .where('customerId', isEqualTo: userId)
          .get();

      for (final orderDoc in customerOrdersQuery.docs) {
        batch.delete(orderDoc.reference);
      }
      print('${customerOrdersQuery.docs.length} customer orders will be deleted');

      final walletRef = FirebaseService.wallets.doc(userId);
      final walletDoc = await walletRef.get();
      if (walletDoc.exists) {
        batch.delete(walletRef);
        print('Wallet will be deleted');
      }

      final paymentsQuery = await FirebaseService.payments
          .where('userId', isEqualTo: userId)
          .get();

      for (final paymentDoc in paymentsQuery.docs) {
        batch.delete(paymentDoc.reference);
      }
      print('${paymentsQuery.docs.length} payments will be deleted');

      await batch.commit();

      try {
      } catch (e) {
      }

      print('User deleted successfully: $userName ($userId)');
      print('   - Role: $userRole');

      return {
        'success': true,
        'message': 'User $userName deleted successfully',
        'deletedItems': {
          'user': true,
          'restaurant': restaurantDoc.exists,
          'foods': foodsQuery.docs.length,
          'orders': restaurantOrdersQuery.docs.length + customerOrdersQuery.docs.length,
          'wallet': walletDoc.exists,
          'payments': paymentsQuery.docs.length,
        },
      };

    } catch (e) {
      print('Error deleting user $userId: $e');
      return {
        'success': false,
        'message': 'Failed to delete user: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }


  static Stream<QuerySnapshot> searchUsers(String query) {
    if (query.isEmpty) {
      return getAllUsers();
    }

    return FirebaseService.users
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<Map<String, dynamic>> getUserActivitySummary(String userId) async {
    try {
      final ordersQuery = await FirebaseService.orders
          .where('customerId', isEqualTo: userId)
          .get();

      var restaurantStats = {};
      final userDoc = await FirebaseService.users.doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final role = userData?['role'] ?? 'customer';

      if (role == 'merchant') {
        final foodsQuery = await FirebaseService.foods
            .where('restaurantId', isEqualTo: userId)
            .get();

        final restaurantOrders = await FirebaseService.orders
            .where('restaurantId', isEqualTo: userId)
            .get();

        restaurantStats = {
          'totalFoods': foodsQuery.docs.length,
          'totalOrders': restaurantOrders.docs.length,
        };
      }

      return {
        'userId': userId,
        'role': role,
        'totalOrders': ordersQuery.docs.length,
        'lastActivity': ordersQuery.docs.isNotEmpty
            ? ordersQuery.docs.first['createdAt']
            : null,
        ...restaurantStats,
      };
    } catch (e) {
      print('Error getting user activity: $e');
      return {
        'userId': userId,
        'error': e.toString(),
      };
    }
  }

  static Future<void> toggleUserStatus(String userId, bool isActive) async {
    await FirebaseService.users.doc(userId).update({
      'isActive': isActive,
      'updatedAt': DateTime.now(),
    });
  }

  static Future<Map<String, dynamic>> getDeletionStats() async {
    try {
      final logs = await FirebaseService.firestore
          .collection('deletion_logs')
          .get();

      int merchants = 0;
      int customers = 0;
      int totalFoods = 0;
      int totalOrders = 0;

      for (final log in logs.docs) {
        final data = log.data() as Map<String, dynamic>;
        final deletedItems = data['deletedItems'] as Map<String, dynamic>?;

        if (data['userRole'] == 'merchant') merchants++;
        if (data['userRole'] == 'customer') customers++;

        if (deletedItems != null) {
          totalFoods += (deletedItems['foodItems'] as int? ?? 0);
          totalOrders += (deletedItems['orders'] as int? ?? 0);
        }
      }

      return {
        'totalDeletions': logs.docs.length,
        'merchantsDeleted': merchants,
        'customersDeleted': customers,
        'totalFoodsDeleted': totalFoods,
        'totalOrdersDeleted': totalOrders,
        'lastDeletion': logs.docs.isNotEmpty
            ? logs.docs.first['timestamp']
            : null,
      };
    } catch (e) {
      print('Error getting deletion stats: $e');
      return {
        'totalDeletions': 0,
        'merchantsDeleted': 0,
        'customersDeleted': 0,
        'totalFoodsDeleted': 0,
        'totalOrdersDeleted': 0,
      };
    }
  }

  static Stream<QuerySnapshot> getSuperAdminUsers() {
    return FirebaseService.users
        .where('role', isEqualTo: 'super_admin')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<bool> isSuperAdmin(String userId) async {
    try {
      final doc = await FirebaseService.users.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final role = data?['role'] as String?;
        // Accept both 'admin' and 'super_admin' as super admin
        return role == 'super_admin' || role == 'admin';
      }
      return false;
    } catch (e) {
      print('Error checking super admin status: $e');
      return false;
    }
  }
}