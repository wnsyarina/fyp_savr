import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class WalletService {
  static Future<void> updateMerchantWallet(String restaurantId, double amount) async {
    try {
      final walletRef = FirebaseService.wallets.doc(restaurantId);

      await FirebaseService.firestore.runTransaction((transaction) async {
        final walletDoc = await transaction.get(walletRef);

        if (walletDoc.exists) {
          final data = walletDoc.data() as Map<String, dynamic>;
          final currentBalance = (data['balance'] ?? 0.0).toDouble();
          transaction.update(walletRef, {
            'balance': currentBalance + amount,
            'updatedAt': DateTime.now(),
          });
        } else {
          transaction.set(walletRef, {
            'restaurantId': restaurantId,
            'balance': amount,
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          });
        }
      });

    } catch (e) {
      print('Error updating merchant wallet: $e');
      rethrow;
    }
  }

  static Future<double> getMerchantWalletBalance(String restaurantId) async {
    try {
      final walletDoc = await FirebaseService.wallets.doc(restaurantId).get();
      if (walletDoc.exists) {
        final data = walletDoc.data() as Map<String, dynamic>?;
        return (data?['balance'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting merchant wallet balance: $e');
      return 0.0;
    }
  }

  static Stream<DocumentSnapshot> getWalletBalanceStream(String restaurantId) {
    return FirebaseService.wallets.doc(restaurantId).snapshots();
  }

  static Future<void> withdrawFromWallet(String restaurantId, double amount) async {
    try {
      final walletRef = FirebaseService.wallets.doc(restaurantId);

      await FirebaseService.firestore.runTransaction((transaction) async {
        final walletDoc = await transaction.get(walletRef);

        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final data = walletDoc.data() as Map<String, dynamic>;
        final currentBalance = (data['balance'] ?? 0.0).toDouble();

        if (currentBalance < amount) {
          throw Exception('Insufficient funds');
        }

        transaction.update(walletRef, {
          'balance': currentBalance - amount,
          'updatedAt': DateTime.now(),
        });

        await FirebaseService.payments.add({
          'restaurantId': restaurantId,
          'amount': -amount,
          'type': 'withdrawal',
          'status': 'completed',
          'createdAt': DateTime.now(),
          'description': 'Funds withdrawal',
          'referenceNumber': 'WDL${DateTime.now().millisecondsSinceEpoch}',
        });
      });

      print('Withdrawal successful: RM${amount.toStringAsFixed(2)} from merchant $restaurantId');
    } catch (e) {
      print('Error withdrawing from wallet: $e');
      rethrow;
    }
  }

  static Stream<QuerySnapshot> getWalletTransactions(String restaurantId) {
    return FirebaseService.payments
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}