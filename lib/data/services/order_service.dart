import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/models/cart_item_model.dart';
import 'package:fyp_savr/data/services/notification_service.dart';
import 'package:fyp_savr/data/services/payment_service.dart';

class OrderService {
  static Future<String> createOrder({
    required String customerId,
    required String customerName,
    required String customerEmail,
    required List<CartItem> items,
    required double totalAmount,
    required String paymentMethod,
    required String restaurantId,
    required String restaurantName,
    String? specialInstructions,
  }) async {
    try {
      final orderRef = FirebaseService.orders.doc();
      final orderId = orderRef.id;
      final orderNumber = _generateOrderNumber();

      final orderItems = items.map((item) => item.toMap()).toList();

      final orderData = {
        'orderId': orderId,
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'items': orderItems,
        'totalAmount': totalAmount,
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'paymentStatus': 'completed',
        'specialInstructions': specialInstructions ?? '',
        'orderDate': DateTime.now(),
        'pickupTime': DateTime.now().add(const Duration(minutes: 30)),
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'orderNumber': orderNumber,
        'pickupConfirmedByCustomer': false,
        'pickupConfirmedByMerchant': false,
        'customerPickupTime': null,
        'merchantPickupTime': null,
      };

      await orderRef.set(orderData);

      await PaymentService.recordPayment(
        cartItems: items,
        orderId: orderId,
        customerId: customerId,
        customerName: customerName,
        paymentMethod: paymentMethod,
      );

      await NotificationService.sendNewOrderNotification(
        restaurantId: restaurantId,
        orderId: orderId,
        customerName: customerName,
        totalAmount: totalAmount,
        orderNumber: orderNumber,
      );

      return orderId;
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  static Stream<QuerySnapshot> getRestaurantOrders(String restaurantId) {
    return FirebaseService.orders
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getCustomerOrders(String customerId) {
    return FirebaseService.orders
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    required String? oldStatus,
  }) async {
    try {
      final orderDoc = await FirebaseService.orders.doc(orderId).get();
      final orderData = orderDoc.data() as Map<String, dynamic>?;

      if (orderData == null) return;

      final customerId = orderData['customerId'];
      final customerName = orderData['customerName'] ?? 'Customer';
      final restaurantId = orderData['restaurantId'];
      final orderNumber = orderData['orderNumber'] ?? orderId.substring(0, 8);

      Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': DateTime.now(),
      };

      if (status == 'picked_up_by_customer') {
        updateData['pickupConfirmedByCustomer'] = true;
        updateData['customerPickupTime'] = DateTime.now();
      } else if (status == 'completed') {
        updateData['pickupConfirmedByMerchant'] = true;
        updateData['merchantPickupTime'] = DateTime.now();

        if (restaurantId != null) {
          await PaymentService.releasePaymentToMerchant(
            orderId: orderId,
            restaurantId: restaurantId,
          );
        }

        if (restaurantId != null) {
          await NotificationService.sendPaymentNotification(
            restaurantId: restaurantId,
            orderId: orderId,
            amount: orderData['totalAmount'] ?? 0.0,
            orderNumber: orderNumber,
          );
        }
      }

      await FirebaseService.orders.doc(orderId).update(updateData);

      if (oldStatus != status) {
        await NotificationService.sendOrderStatusNotification(
          customerId: customerId,
          orderId: orderId,
          orderNumber: orderNumber,
          oldStatus: oldStatus ?? 'unknown',
          newStatus: status,
        );

        if (status == 'picked_up_by_customer' ||
            status == 'completed' ||
            status == 'cancelled') {
          if (restaurantId != null) {
            await NotificationService.sendMerchantOrderStatusNotification(
              restaurantId: restaurantId,
              orderId: orderId,
              orderNumber: orderNumber,
              customerName: customerName,
              newStatus: status,
            );
          }
        }
      }
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }
  static Future<void> _sendPickupConfirmationToMerchant(
      Map<String, dynamic> orderData,
      String orderId,
      ) async {
    try {
      final restaurantId = orderData['restaurantId'];
      if (restaurantId == null) return;

      await NotificationService.saveNotification(
        userId: restaurantId,
        type: 'customer_pickup_confirmation',
        title: 'Customer Confirmed Pickup',
        body: 'Customer has confirmed pickup of order #${orderData['orderNumber'] ?? orderId.substring(0, 8)}',
        data: {
          'orderId': orderId,
          'customerName': orderData['customerName'] ?? 'Customer',
          'orderNumber': orderData['orderNumber'] ?? orderId.substring(0, 8),
        },
      );
    } catch (e) {
      print('Error sending pickup confirmation to merchant: $e');
    }
  }

  static Future<DocumentSnapshot> getOrder(String orderId) async {
    return await FirebaseService.orders.doc(orderId).get();
  }

  static Stream<QuerySnapshot> getTodaysOrders(String restaurantId) {
    final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return FirebaseService.orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where('orderDate', isGreaterThanOrEqualTo: startOfDay)
        .orderBy('orderDate', descending: true)
        .snapshots();
  }

  static String _generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    return 'SAVR${timestamp.substring(timestamp.length - 8)}';
  }
}
