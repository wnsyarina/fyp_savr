import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/services/ml_service.dart';
import 'package:fyp_savr/data/services/analytics_service.dart';
import 'package:fyp_savr/utils/constants.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';

class FoodService {
  static Future<String> addFoodItem({
    required String restaurantId,
    required String name,
    required String description,
    required double originalPrice,
    required double discountPrice,
    required int quantityAvailable,
    required DateTime pickupStart,
    required DateTime pickupEnd,
    required List<String> categories,
    String? imageBase64,
    String? imageUrl,
    bool useAICategories = true,
  }) async {
    try {
      List<String> finalCategories = categories;
      if (useAICategories && categories.isEmpty) {
        final aiCategories = await MLService.predictCategories(
          foodName: name,
          description: description,
        );
        finalCategories = aiCategories;
      }

      final discountPercentage = ((originalPrice - discountPrice) / originalPrice * 100).round();

      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
      final restaurantName = restaurantData?['name'] ?? 'Unknown Restaurant';

      final docRef = await FirebaseService.foods.add({
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'name': name,
        'description': description,
        'originalPrice': originalPrice,
        'discountPrice': discountPrice,
        'discountPercentage': discountPercentage,
        'quantityAvailable': quantityAvailable,
        'pickupStart': pickupStart,
        'pickupEnd': pickupEnd,
        'imageBase64': imageBase64,
        'imageUrl': imageUrl,
        'categories': finalCategories,
        'searchKeywords': _generateSearchKeywords(name, description, finalCategories),
        'tags': _generateTags(discountPercentage, quantityAvailable),
        'isActive': true,
        'isAvailable': true,
        'isDiscounted': discountPrice < originalPrice,
        'aiSuggestedCategories': useAICategories && categories.isEmpty,
        'aiConfidenceScores': await MLService.getPredictionConfidence(
          foodName: name,
          description: description,
        ),
        'manualOverride': categories.isNotEmpty && useAICategories,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (useAICategories) {
        await AnalyticsService.trackAIPrediction(
          foodName: name,
          predictedCategories: await MLService.getPredictionConfidence(
            foodName: name,
            description: description,
          ),
          finalCategories: finalCategories,
          merchantId: restaurantId,
        );
      }

      return docRef.id;
    } catch (e) {
      print('Error adding food item: $e');
      rethrow;
    }
  }
  static DateTime _getCurrentTimeForComparison() {
    return DateTime.now();
  }

  static Future<void> updateFoodItem(String foodId, Map<String, dynamic> data) async {
    try {
      if (data.containsKey('originalPrice') || data.containsKey('discountPrice')) {
        final originalPrice = data['originalPrice'] ?? await _getFoodField(foodId, 'originalPrice');
        final discountPrice = data['discountPrice'] ?? await _getFoodField(foodId, 'discountPrice');
        
        data['discountPercentage'] = ((originalPrice - discountPrice) / originalPrice * 100).round();
        data['isDiscounted'] = discountPrice < originalPrice;
      }

      if (data.containsKey('name') || data.containsKey('description') || data.containsKey('categories')) {
        final name = data['name'] ?? await _getFoodField(foodId, 'name');
        final description = data['description'] ?? await _getFoodField(foodId, 'description');
        final categories = data['categories'] ?? await _getFoodField(foodId, 'categories');
        
        data['searchKeywords'] = _generateSearchKeywords(name, description, List<String>.from(categories));
      }

      await FirebaseService.foods.doc(foodId).update({
        ...data,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      print('Error updating food item: $e');
      rethrow;
    }
  }

  static Future<void> deleteFoodItem(String foodId) async {
    try {
      await FirebaseService.foods.doc(foodId).update({
        'isActive': false,
        'isAvailable': false,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      print('Error deleting food item: $e');
      rethrow;
    }
  }

  static Future<void> checkAndUpdateFoodAvailability(String foodId) async {
    try {
      final foodDoc = await getFoodItem(foodId);
      final foodData = foodDoc.data() as Map<String, dynamic>?;

      if (foodData != null) {
        final pickupEnd = (foodData['pickupEnd'] as Timestamp).toDate();
        final now = DateTime.now();

        if (pickupEnd.isBefore(now) && (foodData['isAvailable'] ?? false)) {
          await FirebaseService.foods.doc(foodId).update({
            'isAvailable': false,
            'updatedAt': DateTime.now(),
          });

          await FirebaseService.foods.doc(foodId).update({
            'quantityAvailable': 0,
          });

          print('Food $foodId marked as expired');
        }
      }
    } catch (e) {
      print('Error checking food availability: $e');
    }
  }

  static Future<DocumentSnapshot> getFoodItem(String foodId) async {
    return await FirebaseService.foods.doc(foodId).get();
  }

  static Stream<QuerySnapshot> getRestaurantFoods(String restaurantId) {
    final now = _getCurrentTimeForComparison();

    return FirebaseService.foods
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('quantityAvailable', isGreaterThan: 0)
        .where('pickupEnd', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('pickupEnd')
        .snapshots();
  }

  static Stream<QuerySnapshot> getActiveRestaurantFoods(String restaurantId) {
    return FirebaseService.foods
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('pickupEnd', isGreaterThan: DateTime.now())
        .orderBy('pickupEnd')
        .snapshots();
  }

  static Stream<QuerySnapshot> getAvailableFoods() {
    return FirebaseService.foods
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('quantityAvailable', isGreaterThan: 0)
        .where('pickupEnd', isGreaterThan: DateTime.now())
        .orderBy('pickupEnd')
        .snapshots();
  }

  static Stream<QuerySnapshot> getFoodsByCategory(String category) {
    return FirebaseService.foods
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('quantityAvailable', isGreaterThan: 0)
        .where('pickupEnd', isGreaterThan: DateTime.now())
        .where('categories', arrayContains: category)
        .orderBy('discountPercentage', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> searchFoods(String query) {
    if (query.isEmpty) {
      return getAvailableFoods();
    }

    final lowercaseQuery = query.toLowerCase();
    
    return FirebaseService.foods
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('quantityAvailable', isGreaterThan: 0)
        .where('pickupEnd', isGreaterThan: DateTime.now())
        .where('searchKeywords', arrayContains: lowercaseQuery)
        .orderBy('discountPercentage', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getFeaturedFoods() {
    final now = _getCurrentTimeForComparison();

    return FirebaseService.foods
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('quantityAvailable', isGreaterThan: 0)
        .where('pickupEnd', isGreaterThan: Timestamp.fromDate(now))
        .where('discountPercentage', isGreaterThan: 0)
        .orderBy('discountPercentage', descending: true)
        .orderBy('pickupEnd')
        .limit(10)
        .snapshots();
  }


  static Stream<QuerySnapshot> getExpiringSoonFoods() {
    final now = DateTime.now();
    final twoHoursFromNow = now.add(const Duration(hours: 2));
    
    return FirebaseService.foods
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('quantityAvailable', isGreaterThan: 0)
        .where('pickupEnd', isGreaterThan: now)
        .where('pickupEnd', isLessThan: twoHoursFromNow)
        .orderBy('pickupEnd')
        .snapshots();
  }

  static Future<void> updateFoodQuantity(String foodId, int quantitySold) async {
    try {
      final foodDoc = await FirebaseService.foods.doc(foodId).get();
      final foodData = foodDoc.data() as Map<String, dynamic>?;
      
      if (foodData != null) {
        final currentQuantity = foodData['quantityAvailable'] ?? 0;
        final newQuantity = currentQuantity - quantitySold;
        
        await FirebaseService.foods.doc(foodId).update({
          'quantityAvailable': newQuantity > 0 ? newQuantity : 0,
          'isAvailable': newQuantity > 0,
          'updatedAt': DateTime.now(),
        });
      }
    } catch (e) {
      print('Error updating food quantity: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAICategorySuggestions({
    required String foodName,
    String description = '',
  }) async {
    final categories = await MLService.predictCategories(
      foodName: foodName,
      description: description,
    );
    
    final confidence = await MLService.getPredictionConfidence(
      foodName: foodName,
      description: description,
    );

    return {
      'suggestedCategories': categories,
      'confidenceScores': confidence,
      'topCategory': categories.isNotEmpty ? categories.first : AppConstants.roleCustomer,
      'hasHighConfidence': confidence.values.any((score) => score > 0.7),
    };
  }

  static Future<Map<String, dynamic>> getFoodStats(String restaurantId) async {
    try {
      final activeFoods = await FirebaseService.foods
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      final totalFoods = await FirebaseService.foods
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .get();

      final expiringSoon = await FirebaseService.foods
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('pickupEnd', isLessThan: DateTime.now().add(const Duration(hours: 2)))
          .get();

      double totalValue = 0;
      double totalDiscountedValue = 0;
      
      for (final doc in totalFoods.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final originalPrice = data['originalPrice'] ?? 0;
        final discountPrice = data['discountPrice'] ?? 0;
        final quantity = data['quantityAvailable'] ?? 0;
        
        totalValue += originalPrice * quantity;
        totalDiscountedValue += discountPrice * quantity;
      }

      return {
        'activeCount': activeFoods.docs.length,
        'totalCount': totalFoods.docs.length,
        'expiringSoonCount': expiringSoon.docs.length,
        'totalValue': totalValue,
        'totalDiscountedValue': totalDiscountedValue,
        'totalSavings': totalValue - totalDiscountedValue,
      };
    } catch (e) {
      print('Error getting food stats: $e');
      return {
        'activeCount': 0,
        'totalCount': 0,
        'expiringSoonCount': 0,
        'totalValue': 0,
        'totalDiscountedValue': 0,
        'totalSavings': 0,
      };
    }
  }

  static Future<void> updateFoodsAvailability() async {
    try {
      final now = DateTime.now();
      final expiredFoods = await FirebaseService.foods
          .where('isAvailable', isEqualTo: true)
          .where('pickupEnd', isLessThan: now)
          .get();

      final batch = FirebaseService.firestore.batch();
      
      for (final doc in expiredFoods.docs) {
        batch.update(doc.reference, {
          'isAvailable': false,
          'updatedAt': now,
        });
      }
      
      await batch.commit();
      print('Updated ${expiredFoods.docs.length} expired foods');
    } catch (e) {
      print('Error updating food availability: $e');
    }
  }

  static Future<void> _updateRestaurantName(String foodId, String restaurantId) async {
    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      if (restaurantDoc.exists) {
        final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
        final restaurantName = restaurantData?['name'] ?? 'Unknown Restaurant';
        
        await FirebaseService.foods.doc(foodId).update({
          'restaurantName': restaurantName,
        });
      }
    } catch (e) {
      print('Error updating restaurant name: $e');
    }
  }

  static Future<dynamic> _getFoodField(String foodId, String field) async {
    final doc = await FirebaseService.foods.doc(foodId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?[field];
  }

  static List<String> _generateSearchKeywords(String name, String description, List<String> categories) {
    final keywords = <String>{};
    
    keywords.addAll(name.toLowerCase().split(' '));
    
    keywords.addAll(description.toLowerCase().split(' ').take(10));
    
    keywords.addAll(categories.map((c) => c.toLowerCase()));
    
    for (final word in name.toLowerCase().split(' ')) {
      if (word.length > 2) {
        keywords.add(word);
      }
    }
    
    return keywords.where((word) => word.length > 2).toList();
  }

  static List<String> _generateTags(int discountPercentage, int quantity) {
    final tags = <String>[];
    
    if (discountPercentage >= 50) {
      tags.add('half-price');
    } else if (discountPercentage >= 30) {
      tags.add('high-discount');
    } else if (discountPercentage > 0) {
      tags.add('discounted');
    }
    
    if (quantity <= 3) {
      tags.add('limited');
    } else if (quantity >= 10) {
      tags.add('plenty');
    }
    
    tags.add('today-only');
    
    return tags;
  }

  static Stream<QuerySnapshot> getLowStockFoods(String restaurantId, {int threshold = 3}) {
    return FirebaseService.foods
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isActive', isEqualTo: true)
        .where('quantityAvailable', isLessThan: threshold)
        .where('quantityAvailable', isGreaterThan: 0)
        .orderBy('quantityAvailable')
        .snapshots();
  }

  static Stream<QuerySnapshot> getPopularFoods(String restaurantId) {
    return FirebaseService.foods
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isActive', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .orderBy('discountPercentage', descending: true)
        .limit(5)
        .snapshots();
  }

  static Future<String> duplicateFoodItem(String originalFoodId) async {
    try {
      final originalDoc = await FirebaseService.foods.doc(originalFoodId).get();
      final originalData = originalDoc.data() as Map<String, dynamic>?;
      
      if (originalData == null) {
        throw Exception('Original food item not found');
      }
      
      final newData = Map<String, dynamic>.from(originalData)
        ..remove('id')
        ..['createdAt'] = DateTime.now()
        ..['updatedAt'] = DateTime.now()
        ..['name'] = '${originalData['name']} (Copy)';
      
      final docRef = await FirebaseService.foods.add(newData);
      return docRef.id;
    } catch (e) {
      print('Error duplicating food item: $e');
      rethrow;
    }
  }

static Future<Map<String, dynamic>> validateFoodAvailability(List<Map<String, dynamic>> cartItems) async {
  final results = <String, dynamic>{};
  final unavailableItems = <String>[];
  
  for (final item in cartItems) {
    final foodId = item['foodId'];
    final requestedQuantity = item['quantity'];
    
    final foodDoc = await getFoodItem(foodId);
    final foodData = foodDoc.data() as Map<String, dynamic>?;
    
    if (foodData == null || 
        foodData['isAvailable'] != true || 
        foodData['quantityAvailable'] < requestedQuantity) {
      unavailableItems.add(foodData?['name'] ?? 'Unknown item');
    }
  }
  
  results['isAvailable'] = unavailableItems.isEmpty;
  results['unavailableItems'] = unavailableItems;
  return results;
}

static Future<void> updateFoodQuantitiesAfterOrder(List<Map<String, dynamic>> orderedItems) async {
  for (final item in orderedItems) {
    final foodRef = FirebaseService.foods.doc(item['foodId']);
    final quantitySold = item['quantity'];
    
    // Get current quantity first
    final foodDoc = await foodRef.get();
    final foodData = foodDoc.data() as Map<String, dynamic>?;
    
    if (foodData != null) {
      final currentQuantity = foodData['quantityAvailable'] ?? 0;
      final newQuantity = currentQuantity - quantitySold;
      final isAvailable = newQuantity > 0;
      
      await foodRef.update({
        'quantityAvailable': newQuantity > 0 ? newQuantity : 0,
        'isAvailable': isAvailable,
        'updatedAt': DateTime.now(),
      });
    }
  }
}

static Stream<QuerySnapshot> searchFoodsWithFilters({
  String query = '',
  List<String> categories = const [],
  double maxPrice = 1000,
  double minDiscount = 0,
  String sortBy = 'discountPercentage',
}) {
  Query searchQuery = FirebaseService.foods
      .where('isActive', isEqualTo: true)
      .where('isAvailable', isEqualTo: true)
      .where('quantityAvailable', isGreaterThan: 0)
      .where('pickupEnd', isGreaterThan: DateTime.now());

  if (query.isNotEmpty) {
    searchQuery = searchQuery.where('searchKeywords', arrayContains: query.toLowerCase());
  }

  if (categories.isNotEmpty) {
    searchQuery = searchQuery.where('categories', arrayContainsAny: categories);
  }

  searchQuery = searchQuery.where('discountPrice', isLessThanOrEqualTo: maxPrice);

  if (minDiscount > 0) {
    searchQuery = searchQuery.where('discountPercentage', isGreaterThanOrEqualTo: minDiscount);
  }

  switch (sortBy) {
    case 'price':
      searchQuery = searchQuery.orderBy('discountPrice');
      break;
    case 'expiry':
      searchQuery = searchQuery.orderBy('pickupEnd');
      break;
    default: // discount
      searchQuery = searchQuery.orderBy('discountPercentage', descending: true);
  }

  return searchQuery.snapshots();
}

static Future<Map<String, dynamic>> getFoodPerformance(String restaurantId, {int days = 30}) async {
  try {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    final ordersQuery = await FirebaseService.orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    final orders = ordersQuery.docs;
    
    if (orders.isEmpty) {
      return {
        'topSelling': [],
        'lowPerforming': [],
        'revenueByCategory': {},
        'salesTrend': 0.0,
        'totalRevenue': 0.0,
        'totalOrders': 0,
      };
    }

    final Map<String, Map<String, dynamic>> foodStats = {};
    final Map<String, double> categoryRevenue = {};
    double totalRevenue = 0.0;

    for (final orderDoc in orders) {
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      
      for (final item in items) {
        final foodId = item['foodId'];
        final foodName = item['foodName'];
        final quantity = item['quantity'] ?? 0;
        final price = item['price'] ?? 0.0;
        final revenue = price * quantity;
        
        if (!foodStats.containsKey(foodId)) {
          foodStats[foodId] = {
            'name': foodName,
            'totalSold': 0,
            'totalRevenue': 0.0,
            'averagePrice': price,
          };
        }
        
        foodStats[foodId]!['totalSold'] = foodStats[foodId]!['totalSold'] + quantity;
        foodStats[foodId]!['totalRevenue'] = foodStats[foodId]!['totalRevenue'] + revenue;
        
        totalRevenue += revenue;
      }
    }

    final foodList = foodStats.entries.map((entry) => {
      'foodId': entry.key,
      'name': entry.value['name'],
      'totalSold': entry.value['totalSold'],
      'totalRevenue': entry.value['totalRevenue'],
    }).toList();

    foodList.sort((a, b) => b['totalRevenue'].compareTo(a['totalRevenue']));

    final topSelling = foodList.take(5).toList();
    
    final lowPerforming = foodList.length > 5
        ? foodList.sublist(foodList.length - 5) 
        : foodList;

    final salesTrend = await _calculateSalesTrend(restaurantId, days);

    return {
      'topSelling': topSelling,
      'lowPerforming': lowPerforming,
      'revenueByCategory': categoryRevenue,
      'salesTrend': salesTrend,
      'totalRevenue': totalRevenue,
      'totalOrders': orders.length,
      'timeframe': '$days days',
    };
  } catch (e) {
    print('Error getting food performance: $e');
    return {
      'topSelling': [],
      'lowPerforming': [],
      'revenueByCategory': {},
      'salesTrend': 0.0,
      'totalRevenue': 0.0,
      'totalOrders': 0,
      'error': e.toString(),
    };
  }
}

static Future<double> _calculateSalesTrend(String restaurantId, int days) async {
  try {
    final now = DateTime.now();
    final currentPeriodStart = now.subtract(Duration(days: days));
    final previousPeriodStart = now.subtract(Duration(days: days * 2));
    
    final currentOrders = await FirebaseService.orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(currentPeriodStart))
        .get();

    double currentRevenue = 0.0;
    for (final order in currentOrders.docs) {
      final data = order.data() as Map<String, dynamic>;
      currentRevenue += (data['totalAmount'] ?? 0.0).toDouble();
    }

    final previousOrders = await FirebaseService.orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousPeriodStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(currentPeriodStart))
        .get();

    double previousRevenue = 0.0;
    for (final order in previousOrders.docs) {
      final data = order.data() as Map<String, dynamic>;
      previousRevenue += (data['totalAmount'] ?? 0.0).toDouble();
    }

    if (previousRevenue == 0) return currentRevenue > 0 ? 100.0 : 0.0;
    
    return ((currentRevenue - previousRevenue) / previousRevenue * 100);
  } catch (e) {
    print('Error calculating sales trend: $e');
    return 0.0;
  }
}

static Future<Map<String, dynamic>> getFoodInsights(String foodId) async {
  final foodDoc = await getFoodItem(foodId);
  final foodData = foodDoc.data() as Map<String, dynamic>?;
  
  if (foodData == null) {
    return {'error': 'Food item not found'};
  }

  final originalPrice = foodData['originalPrice'] ?? 0.0;
  final discountPrice = foodData['discountPrice'] ?? 0.0;
  final discountPercentage = foodData['discountPercentage'] ?? 0;
  final quantityAvailable = foodData['quantityAvailable'] ?? 0;

  return {
    'profitMargin': ((discountPrice * 0.7) / discountPrice * 100), // Assuming 30% cost
    'discountEffectiveness': discountPercentage > 30 ? 'High' : 'Moderate',
    'stockLevel': quantityAvailable <= 2 ? 'Low' : quantityAvailable <= 5 ? 'Medium' : 'High',
    'priceCompetitiveness': discountPrice < (originalPrice * 0.6) ? 'Very Competitive' : 'Competitive',
    'recommendations': _generateRecommendations(foodData),
  };
}

static List<String> _generateRecommendations(Map<String, dynamic> foodData) {
  final recommendations = <String>[];
  final discountPercentage = foodData['discountPercentage'] ?? 0;
  final quantity = foodData['quantityAvailable'] ?? 0;

  if (discountPercentage > 50 && quantity > 10) {
    recommendations.add('Consider reducing discount to 40% to increase profit margin');
  }
  
  if (quantity <= 2) {
    recommendations.add('Low stock - consider preparing more or increasing price');
  }
  
  if (discountPercentage < 20) {
    recommendations.add('Low discount may not attract enough customers');
  }

  return recommendations;
}

  static Stream<QuerySnapshot> getFoodsByMerchantId(String merchantId) {
    return Stream.fromFuture(_getRestaurantIdFromMerchant(merchantId)).asyncExpand((restaurantId) {
      if (restaurantId == null) {
        return FirebaseService.foods
            .where('nonexistent_field', isEqualTo: 'empty')
            .limit(0)
            .snapshots();
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

  static Future<String?> _getRestaurantIdFromMerchant(String merchantId) async {
    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(merchantId).get();

      if (restaurantDoc.exists) {
        return merchantId;
      }

      return null;
    } catch (e) {
      print('Error getting restaurant ID from merchant: $e');
      return null;
    }
  }

  static Stream<QuerySnapshot> getCurrentMerchantFoods() {
    return Stream.fromFuture(_getCurrentMerchantRestaurantId()).asyncExpand((restaurantId) {
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


  static Future<String?> _getCurrentMerchantRestaurantId() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user == null) return null;

      final userDoc = await FirebaseService.users.doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final restaurantId = userData?['restaurantId'] as String?;
        if (restaurantId != null && restaurantId.isNotEmpty) {
          return restaurantId;
        }
      }

      return await RestaurantService.getRestaurantIdByMerchantId(user.uid);
    } catch (e) {
      print('Error getting current merchant restaurant ID: $e');
      return null;
    }
  }
  static Stream<QuerySnapshot> _getEmptyStream() {
    return FirebaseService.restaurants
        .where('nonexistent_field', isEqualTo: 'empty')
        .limit(0)
        .snapshots();
  }

}