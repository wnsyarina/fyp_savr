import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fyp_savr/data/services/push_notification_service.dart';

class NotificationService {
  static const String newOrder = 'new_order';
  static const String orderStatusUpdate = 'order_status_update';
  static const String orderReady = 'order_ready';
  static const String orderCompleted = 'order_completed';
  static const String paymentReceived = 'payment_received';


  static Future<void> sendNewOrderNotification({
    required String restaurantId,
    required String orderId,
    required String customerName,
    required double totalAmount,
    required String orderNumber,
  }) async {
    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

      if (!restaurantDoc.exists) {
        print('Restaurant document does not exist. ID: $restaurantId');
        print('=' * 50);
        return;
      }

      final merchantId = restaurantData?['merchantId'];
      if (merchantId == null) {
        print('Restaurant document has no merchantId field');
        print('=' * 50);
        return;
      }

      final merchantDoc = await FirebaseService.users.doc(merchantId).get();

      if (!merchantDoc.exists) {
        print('Merchant user document does not exist ID: $merchantId');
        print('Merchant needs to run the app at least once');
        print('=' * 50);
        return;
      }

      final merchantData = merchantDoc.data() as Map<String, dynamic>?;
      print('Merchant user document exists');

      final tokens = (merchantData?['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];

      if (tokens.isEmpty) {
        print('Merchant has no FCM tokens saved');
        print('Merchant needs to run app and grant notification permission');
      } else {
        print('Merchant has ${tokens.length} FCM token(s)');
      }

      await PushNotificationService.sendPushNotification(
        userId: merchantId,
        title: 'New Order Received! 🎉',
        body: 'Order #${orderNumber.substring(0, 8)} from $customerName for RM${totalAmount.toStringAsFixed(2)}',
        data: {
          'type': newOrder,
          'orderId': orderId,
          'restaurantId': restaurantId,
          'customerName': customerName,
          'totalAmount': totalAmount.toString(),
          'orderNumber': orderNumber,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      print('📋 Step 5: Saving in-app notification...');
      await saveNotification(
        userId: merchantId,
        type: newOrder,
        title: 'New Order Received!',
        body: 'Order #${orderNumber.substring(0, 8)} from $customerName for RM${totalAmount.toStringAsFixed(2)}',
        data: {
          'orderId': orderId,
          'restaurantId': restaurantId,
          'customerName': customerName,
          'totalAmount': totalAmount,
          'orderNumber': orderNumber,
        },
      );


    } catch (e, stackTrace) {
      print('Error sending new order notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> sendOrderStatusNotification({
    required String customerId,
    required String orderId,
    required String orderNumber,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      print('=' * 50);

      String title = '';
      String body = '';

      switch (newStatus) {
        case 'confirmed':
          title = '✅ Order Confirmed!';
          body = 'Your order #${orderNumber.substring(0, 8)} has been confirmed';
          break;
        case 'preparing':
          title = '👨‍🍳 Preparing Your Order';
          body = 'Order #${orderNumber.substring(0, 8)} is now being prepared';
          break;
        case 'ready':
          title = '🚀 Order Ready for Pickup!';
          body = 'Your order #${orderNumber.substring(0, 8)} is ready for pickup';
          break;
        case 'picked_up_by_customer':
          title = '📱 Pickup Confirmed';
          body = 'You confirmed pickup of order #${orderNumber.substring(0, 8)}';
          break;
        case 'completed':
          title = '🎉 Order Completed!';
          body = 'Order #${orderNumber.substring(0, 8)} has been completed';
          break;
        case 'cancelled':
          title = '❌ Order Cancelled';
          body = 'Order #${orderNumber.substring(0, 8)} has been cancelled';
          break;
        default:
          title = 'Order Status Updated';
          body = 'Order #${orderNumber.substring(0, 8)} status: $newStatus';
      }

      print('🔄 Title: $title');
      print('🔄 Body: $body');

      await PushNotificationService.sendPushNotification(
        userId: customerId,
        title: title,
        body: body,
        data: {
          'type': 'order_status_update',
          'orderId': orderId,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
          'orderNumber': orderNumber,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'screen': 'order_history',
          'order_id': orderId,
        },
      );

      await saveNotification(
        userId: customerId,
        type: orderStatusUpdate,
        title: title,
        body: body,
        data: {
          'orderId': orderId,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
          'orderNumber': orderNumber,
        },
      );


    } catch (e, stackTrace) {
      print('ERROR in sendOrderStatusNotification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> sendPaymentNotification({
    required String restaurantId,
    required String orderId,
    required double amount,
    required String orderNumber,
  }) async {
    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
      final merchantId = restaurantData?['merchantId'];

      if (merchantId == null) return;

      await saveNotification(
        userId: merchantId,
        type: paymentReceived,
        title: 'Payment Received!',
        body: 'RM${amount.toStringAsFixed(2)} received for order #${orderNumber.substring(0, 8)}',
        data: {
          'orderId': orderId,
          'amount': amount.toString(),
          'orderNumber': orderNumber,
        },
      );
    } catch (e) {
      print('Error sending payment notification: $e');
    }
  }


  static Future<void> saveNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return FirebaseService.firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> sendMerchantOrderStatusNotification({
    required String restaurantId,
    required String orderId,
    required String orderNumber,
    required String customerName,
    required String newStatus,
  }) async {
    try {

      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

      if (!restaurantDoc.exists) {
        print('ERROR: Restaurant document does not exist!');
        return;
      }

      final merchantId = restaurantData?['merchantId'];
      if (merchantId == null) {
        print('ERROR: No merchantId found for restaurant');
        return;
      }

      String title = '';
      String body = '';

      switch (newStatus) {
        case 'picked_up_by_customer':
          title = '✅ Customer Confirmed Pickup';
          body = 'Customer $customerName picked up order #${orderNumber.substring(0, 8)}';
          break;
        case 'completed':
          title = '💰 Payment Released';
          body = 'Payment for order #${orderNumber.substring(0, 8)} has been released to your wallet';
          break;
        case 'cancelled':
          title = '❌ Order Cancelled';
          body = 'Order #${orderNumber.substring(0, 8)} from $customerName was cancelled';
          break;
        default:
          print('🏪 No notification needed for merchant for status: $newStatus');
          return;
      }

      await PushNotificationService.sendPushNotification(
        userId: merchantId,
        title: title,
        body: body,
        data: {
          'type': 'merchant_order_update',
          'orderId': orderId,
          'orderNumber': orderNumber,
          'newStatus': newStatus,
          'customerName': customerName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      await saveNotification(
        userId: merchantId,
        type: 'merchant_order_update',
        title: title,
        body: body,
        data: {
          'orderId': orderId,
          'orderNumber': orderNumber,
          'newStatus': newStatus,
          'customerName': customerName,
        },
      );


    } catch (e, stackTrace) {
      print('ERROR in sendMerchantOrderStatusNotification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseService.firestore.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  static Stream<int> getUnreadCount(String userId) {
    return FirebaseService.firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }


  static void showInAppNotification({
    required BuildContext context,
    required String title,
    required String body,
    VoidCallback? onTap,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              body,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.grey[900],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: onTap != null
            ? SnackBarAction(
          label: 'View',
          textColor: Colors.orange,
          onPressed: onTap,
        )
            : null,
      ),
    );
  }

  static void showNewOrderAlert({
    required BuildContext context,
    required String orderId,
    required String customerName,
    required double totalAmount,
    required String orderNumber,
    VoidCallback? onViewOrder,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '🎉 New Order!',
          style: TextStyle(color: Colors.green),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: #${orderNumber.substring(0, 8)}'),
            Text('Customer: $customerName'),
            Text('Amount: RM${totalAmount.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          if (onViewOrder != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onViewOrder();
              },
              child: const Text('View Order'),
            ),
        ],
      ),
    );
  }
}