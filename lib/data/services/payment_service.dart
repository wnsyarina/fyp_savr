import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/models/cart_item_model.dart';
import 'wallet_service.dart';

class PaymentService {
  static Future<void> recordPayment({
    required List<CartItem> cartItems,
    required String orderId,
    required String customerId,
    required String customerName,
    required String paymentMethod,
  }) async {
    try {
      final restaurantItems = <String, List<CartItem>>{};

      for (final item in cartItems) {
        if (!restaurantItems.containsKey(item.restaurantId)) {
          restaurantItems[item.restaurantId] = [];
        }
        restaurantItems[item.restaurantId]!.add(item);
      }

      for (final restaurantId in restaurantItems.keys) {
        final items = restaurantItems[restaurantId]!;
        final restaurantTotal = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

        await _createPaymentRecord(
          orderId: orderId,
          restaurantId: restaurantId,
          restaurantName: items.first.restaurantName,
          amount: restaurantTotal,
          customerId: customerId,
          customerName: customerName,
          items: items,
          paymentStatus: 'pending', // payment recorded but not released to wallet
        );

      }
    } catch (e) {
      print('Error recording payment: $e');
      rethrow;
    }
  }

  static Future<void> releasePaymentToMerchant({
    required String orderId,
    required String restaurantId,
  }) async {
    try {
      final anyPaymentQuery = await FirebaseService.payments
          .where('orderId', isEqualTo: orderId)
          .where('restaurantId', isEqualTo: restaurantId)
          .limit(1)
          .get();

      if (anyPaymentQuery.docs.isEmpty) {
        print('No payment record found');
        return;
      }
      for (final doc in anyPaymentQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('   - Payment ID: ${doc.id}');
        print('     Status: ${data['status']}');
        print('     Amount: ${data['amount']}');
      }

      final paymentQuery = await FirebaseService.payments
          .where('orderId', isEqualTo: orderId)
          .where('restaurantId', isEqualTo: restaurantId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (paymentQuery.docs.isEmpty) {
        print('No pending payment found');

        final completedPaymentQuery = await FirebaseService.payments
            .where('orderId', isEqualTo: orderId)
            .where('restaurantId', isEqualTo: restaurantId)
            .where('status', isEqualTo: 'completed')
            .limit(1)
            .get();

        if (completedPaymentQuery.docs.isNotEmpty) {
          print('Payment completed');
          return;
        }

        final firstPayment = anyPaymentQuery.docs.first;
        final paymentData = firstPayment.data() as Map<String, dynamic>;

        if (paymentData['status'] != 'completed') {
          final amount = (paymentData['amount'] ?? 0.0).toDouble();

          await firstPayment.reference.update({
            'status': 'completed',
            'releasedAt': DateTime.now(),
          });

          await WalletService.updateMerchantWallet(restaurantId, amount);
          print('Payment manually updated and wallet credited');
        }

        return;
      }

      final paymentDoc = paymentQuery.docs.first;
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final amount = (paymentData['amount'] ?? 0.0).toDouble();

      await paymentDoc.reference.update({
        'status': 'completed',
        'releasedAt': DateTime.now(),
      });

      // Update merchant wallet
      await WalletService.updateMerchantWallet(restaurantId, amount);

      print('Payment of RM${amount.toStringAsFixed(2)} released to merchant $restaurantId');

    } catch (e) {
      print('Error releasing payment to merchant: $e');
      rethrow;
    }
  }

  static Future<void> _createPaymentRecord({
    required String orderId,
    required String restaurantId,
    required String restaurantName,
    required double amount,
    required String customerId,
    required String customerName,
    required List<CartItem> items,
    String paymentStatus = 'pending',
  }) async {
    await FirebaseService.payments.add({
      'orderId': orderId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'amount': amount,
      'status': paymentStatus,
      'customerId': customerId,
      'customerName': customerName,
      'type': 'sale',
      'createdAt': DateTime.now(),
      'releasedAt': paymentStatus == 'completed' ? DateTime.now() : null,
      'items': items.map((item) => item.toMap()).toList(),
    });
  }

  static Stream<QuerySnapshot> getMerchantPayments(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('type', isEqualTo: 'sale')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getPendingMerchantPayments(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('type', isEqualTo: 'sale')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getCompletedMerchantPayments(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('type', isEqualTo: 'sale')
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getWithdrawalHistory(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('type', isEqualTo: 'withdrawal')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getMerchantTransactions(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getMerchantSales(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('type', isEqualTo: 'sale')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getMerchantWithdrawals(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('type', isEqualTo: 'withdrawal')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getMerchantTransactionsByDateRange(
      String restaurantId, {
        required DateTime startDate,
        required DateTime endDate,
      }) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
