import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class PaymentMethodService {
  static String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  static CollectionReference get _paymentMethodsCollection {
    return FirebaseService.firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('payment_methods');
  }

  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      if (_currentUserId.isEmpty) {
        return [];
      }

      final querySnapshot = await _paymentMethodsCollection
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting payment methods: $e');
      return [];
    }
  }

  static Future<void> addCard({
    required String cardNumber,
    required String cardHolder,
    required int expiryMonth,
    required int expiryYear,
    required String cvv,
    bool isDefault = false,
  }) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      if (isDefault) {
        await _unsetExistingDefault();
      }

      // mask card number (store only last 4 digits)
      final maskedNumber = '•••• ${cardNumber.substring(cardNumber.length - 4)}';

      await _paymentMethodsCollection.add({
        'cardNumber': cardNumber,
        'maskedNumber': maskedNumber,
        'cardHolder': cardHolder,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'cvv': cvv,
        'type': 'credit_card',
        'isDefault': isDefault,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      print('Error adding card: $e');
      rethrow;
    }
  }

  static Future<void> deleteCard(String cardId) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      await _paymentMethodsCollection.doc(cardId).delete();
    } catch (e) {
      print('Error deleting card: $e');
      rethrow;
    }
  }

  static Future<void> setDefaultCard(String cardId) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      await _unsetExistingDefault();

      await _paymentMethodsCollection.doc(cardId).update({
        'isDefault': true,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      print('Error setting default card: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getDefaultPaymentMethod() async {
    try {
      if (_currentUserId.isEmpty) {
        return null;
      }

      final querySnapshot = await _paymentMethodsCollection
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }

      return null;
    } catch (e) {
      print('Error getting default payment method: $e');
      return null;
    }
  }

  static Future<void> _unsetExistingDefault() async {
    final defaultCards = await _paymentMethodsCollection
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = FirebaseService.firestore.batch();
    for (final doc in defaultCards.docs) {
      batch.update(doc.reference, {
        'isDefault': false,
        'updatedAt': DateTime.now(),
      });
    }

    if (defaultCards.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  static List<String> validateCard({
    required String cardNumber,
    required String cardHolder,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  }) {
    final errors = <String>[];

    final cleanedNumber = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleanedNumber.isEmpty) {
      errors.add('Card number is required');
    } else if (cleanedNumber.length < 13 || cleanedNumber.length > 19) {
      errors.add('Invalid card number length');
    }

    if (cardHolder.trim().isEmpty) {
      errors.add('Card holder name is required');
    }

    final month = int.tryParse(expiryMonth);
    if (month == null || month < 1 || month > 12) {
      errors.add('Invalid expiry month');
    }

    final year = int.tryParse(expiryYear);
    final currentYear = DateTime.now().year % 100;
    if (year == null || year < currentYear) {
      errors.add('Card has expired');
    } else if (year == currentYear) {
      final currentMonth = DateTime.now().month;
      if (month != null && month < currentMonth) {
        errors.add('Card has expired');
      }
    }

    if (cvv.isEmpty) {
      errors.add('CVV is required');
    } else if (cvv.length < 3 || cvv.length > 4) {
      errors.add('Invalid CVV');
    }

    return errors;
  }

  static Future<Map<String, dynamic>?> getPaymentMethodById(String cardId) async {
    try {
      if (_currentUserId.isEmpty) {
        return null;
      }

      final doc = await _paymentMethodsCollection.doc(cardId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }
      return null;
    } catch (e) {
      print('Error getting payment method by ID: $e');
      return null;
    }
  }
}