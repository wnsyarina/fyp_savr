import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:fyp_savr/data/models/cart_item_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/services/order_service.dart';
import 'food_service.dart';
import 'payment_method_service.dart';

class CartService {
  static String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  static CollectionReference get _cartCollection {
    return FirebaseService.firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('cart');
  }

  static Future<void> addToCart(CartItem item) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      final existingItem = await _cartCollection
          .where('foodId', isEqualTo: item.foodId)
          .get();

      if (existingItem.docs.isNotEmpty) {
        final existingDoc = existingItem.docs.first;
        final currentQuantity = (existingDoc['quantity'] ?? 0) as int;
        await existingDoc.reference.update({
          'quantity': currentQuantity + item.quantity,
          'updatedAt': DateTime.now(),
        });
      } else {
        await _cartCollection.add({
          'foodId': item.foodId,
          'foodName': item.foodName,
          'restaurantId': item.restaurantId,
          'restaurantName': item.restaurantName,
          'price': item.price,
          'quantity': item.quantity,
          'imageBase64': item.imageBase64,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
      }
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  static Future<List<CartItem>> getCartItems() async {
    try {
      if (_currentUserId.isEmpty) {
        return [];
      }

      final querySnapshot = await _cartCollection
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CartItem(
          foodId: data['foodId'] ?? '',
          foodName: data['foodName'] ?? '',
          restaurantId: data['restaurantId'] ?? '',
          restaurantName: data['restaurantName'] ?? '',
          price: (data['price'] ?? 0.0).toDouble(),
          quantity: (data['quantity'] ?? 0) as int,
          imageBase64: data['imageBase64'],
        );
      }).toList();
    } catch (e) {
      print('Error getting cart items: $e');
      return [];
    }
  }

  static Stream<List<CartItem>> getCartItemsStream() {
    if (_currentUserId.isEmpty) {
      return Stream.value([]);
    }

    return _cartCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CartItem(
          foodId: data['foodId'] ?? '',
          foodName: data['foodName'] ?? '',
          restaurantId: data['restaurantId'] ?? '',
          restaurantName: data['restaurantName'] ?? '',
          price: (data['price'] ?? 0.0).toDouble(),
          quantity: (data['quantity'] ?? 0) as int,
          imageBase64: data['imageBase64'],
        );
      }).toList();
    });
  }

  static Future<void> updateCartItemQuantity(String foodId, int quantity) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      if (quantity <= 0) {
        await removeFromCart(foodId);
        return;
      }

      final querySnapshot = await _cartCollection
          .where('foodId', isEqualTo: foodId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'quantity': quantity,
          'updatedAt': DateTime.now(),
        });
      }
    } catch (e) {
      print('Error updating cart item quantity: $e');
      rethrow;
    }
  }

  static Future<void> removeFromCart(String foodId) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      final querySnapshot = await _cartCollection
          .where('foodId', isEqualTo: foodId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.delete();
      }
    } catch (e) {
      print('Error removing from cart: $e');
      rethrow;
    }
  }

  static Future<void> clearCart() async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      final querySnapshot = await _cartCollection.get();

      final batch = FirebaseService.firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('Error clearing cart: $e');
      rethrow;
    }
  }

  static Future<int> getCartItemCount() async {
    try {
      if (_currentUserId.isEmpty) {
        return 0;
      }

      final querySnapshot = await _cartCollection.get();
      int totalCount = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalCount += (data['quantity'] ?? 0) as int;
      }
      return totalCount;
    } catch (e) {
      print('Error getting cart item count: $e');
      return 0;
    }
  }

  static Stream<int> getCartItemCountStream() {
    if (_currentUserId.isEmpty) {
      return Stream.value(0);
    }

    return _cartCollection.snapshots().map((querySnapshot) {
      return querySnapshot.docs.fold(0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>;
        return sum + ((data['quantity'] ?? 0) as int);
      });
    });
  }

  static Future<bool> isItemInCart(String foodId) async {
    try {
      if (_currentUserId.isEmpty) {
        return false;
      }

      final querySnapshot = await _cartCollection
          .where('foodId', isEqualTo: foodId)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if item in cart: $e');
      return false;
    }
  }

  static Future<double> getTotalPrice() async {
    try {
      if (_currentUserId.isEmpty) {
        return 0.0;
      }

      final items = await getCartItems();
      double total = 0.0;
      for (final item in items) {
        total += item.price * item.quantity;
      }
      return total;
    } catch (e) {
      print('Error getting total price: $e');
      return 0.0;
    }
  }

  static Future<String> createOrderFromCart({
    required String paymentMethod,
    required double totalAmount,
    String? specialInstructions,
  }) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      final cartItems = await getCartItems();

      if (cartItems.isEmpty) {
        throw Exception('Cart is empty');
      }

      final validationErrors = await validateCart();
      if (validationErrors.isNotEmpty) {
        throw Exception(validationErrors.join(', '));
      }

      final userDoc = await FirebaseService.users.doc(_currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      final restaurantId = cartItems.first.restaurantId;
      final restaurantName = cartItems.first.restaurantName;

      final orderId = await OrderService.createOrder(
        customerId: _currentUserId,
        customerName: userData?['name'] ?? 'Customer',
        customerEmail: userData?['email'] ?? '',
        items: cartItems,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        specialInstructions: specialInstructions,
      );

      await FoodService.updateFoodQuantitiesAfterOrder(
        cartItems.map((item) => {
          'foodId': item.foodId,
          'quantity': item.quantity,
        }).toList(),
      );

      await clearCart();

      return orderId;

    } catch (e) {
      print('Error creating order from cart: $e');
      rethrow;
    }
  }

  static Future<List<String>> validateCart() async {
    final List<String> errors = [];
    final cartItems = await getCartItems();

    for (final cartItem in cartItems) {
      try {
        final foodDoc = await FirebaseService.foods.doc(cartItem.foodId).get();
        
        if (!foodDoc.exists) {
          errors.add('${cartItem.foodName} is no longer available');
          continue;
        }

        final foodData = foodDoc.data() as Map<String, dynamic>?;
        
        if (foodData?['isActive'] != true) {
          errors.add('${cartItem.foodName} is no longer available');
          continue;
        }

        final availableQuantity = (foodData?['quantityAvailable'] ?? 0) as int;
        if (cartItem.quantity > availableQuantity) {
          errors.add('Only $availableQuantity ${cartItem.foodName} available');
          continue;
        }

        final currentPrice = (foodData?['discountPrice'] ?? 0.0).toDouble();
        if (currentPrice != cartItem.price) {
          errors.add('Price for ${cartItem.foodName} has changed to RM${currentPrice.toStringAsFixed(2)}');
          continue;
        }

        final pickupEnd = (foodData?['pickupEnd'] as Timestamp?)?.toDate();
        if (pickupEnd != null && DateTime.now().isAfter(pickupEnd)) {
          errors.add('${cartItem.foodName} pickup time has expired');
          continue;
        }

      } catch (e) {
        errors.add('Error validating ${cartItem.foodName}');
      }
    }

    return errors;
  }

  static Future<void> mergeGuestCart(List<CartItem> guestCartItems) async {
    try {
      if (_currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      for (final guestItem in guestCartItems) {
        await addToCart(guestItem);
      }
    } catch (e) {
      print('Error merging guest cart: $e');
      rethrow;
    }
  }

  static Future<bool> hasSavedPaymentMethods() async {
    try {
      final methods = await PaymentMethodService.getPaymentMethods();
      return methods.isNotEmpty;
    } catch (e) {
      print('Error checking saved payment methods: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getDefaultPaymentMethod() async {
    try {
      return await PaymentMethodService.getDefaultPaymentMethod();
    } catch (e) {
      print('Error getting default payment method: $e');
      return null;
    }
  }
}