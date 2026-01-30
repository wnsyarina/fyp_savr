import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/utils/helpers.dart';

class EnhancedAnalyticsService {
static Future<Map<String, dynamic>> getPlatformGrowthData({int days = 30}) async {
  final timePeriod = Helpers.getTimePeriodDates(days);
  final startDate = timePeriod['startDate']!;
  final endDate = timePeriod['endDate']!;
    
    try {
      final users = await FirebaseService.users
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final restaurants = await FirebaseService.restaurants
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final orders = await FirebaseService.orders
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final userGrowth = _groupByDateCumulative(users.docs, 'createdAt');
      final restaurantGrowth = _groupByDateCumulative(restaurants.docs, 'createdAt');
      final orderGrowth = _groupByDateCumulative(orders.docs, 'createdAt');

      return {
        'userGrowth': userGrowth,
        'restaurantGrowth': restaurantGrowth,
        'orderGrowth': orderGrowth,
        'timeframe': '$days days',
      };
    } catch (e) {
      print('Error getting growth data: $e');
      return {
        'userGrowth': {},
        'restaurantGrowth': {},
        'orderGrowth': {},
        'timeframe': '$days days',
      };
    }
  }

  static Future<Map<String, dynamic>> getRevenueAnalytics({int days = 30}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    try {
      final orders = await FirebaseService.orders
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('status', isEqualTo: 'completed')
          .get();

      final dailyRevenue = <String, double>{};
      double totalRevenue = 0.0;
      int totalOrders = 0;

      for (final order in orders.docs) {
        final data = order.data() as Map<String, dynamic>;
        final date = (data['createdAt'] as Timestamp).toDate();
        final dateKey = '${date.day}/${date.month}';
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + amount;
        totalRevenue += amount;
        totalOrders++;
      }

      final revenueByRestaurant = <String, double>{};
      for (final order in orders.docs) {
        final data = order.data() as Map<String, dynamic>;
        final restaurantName = data['restaurantName'] ?? 'Unknown';
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        revenueByRestaurant[restaurantName] = (revenueByRestaurant[restaurantName] ?? 0.0) + amount;
      }

      return {
        'dailyRevenue': dailyRevenue,
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'averageOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
        'revenueByRestaurant': revenueByRestaurant,
      };
    } catch (e) {
      print('Error getting revenue analytics: $e');
      return {
        'dailyRevenue': {},
        'totalRevenue': 0.0,
        'totalOrders': 0,
        'averageOrderValue': 0.0,
        'revenueByRestaurant': {},
      };
    }
  }

static Future<Map<String, dynamic>> getRevenueAnalyticsForMerchant(String merchantId, {int days = 30}) async {
  final startDate = DateTime.now().subtract(Duration(days: days));

  try {
    final restaurantQuery = await FirebaseService.restaurants
        .where('merchantId', isEqualTo: merchantId)
        .limit(1)
        .get();

    if (restaurantQuery.docs.isEmpty) {
      return {
        'dailyRevenue': {},
        'totalRevenue': 0.0,
        'totalOrders': 0,
        'averageOrderValue': 0.0,
      };
    }

    final restaurantId = restaurantQuery.docs.first.id;

    final orders = await FirebaseService.orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('status', isEqualTo: 'completed')
        .get();

    final dailyRevenue = <String, double>{};
    double totalRevenue = 0.0;
    int totalOrders = 0;

    for (final order in orders.docs) {
      final data = order.data() as Map<String, dynamic>;
      final date = (data['createdAt'] as Timestamp).toDate();
      final dateKey = '${date.day}/${date.month}';
      final amount = (data['totalAmount'] ?? 0.0).toDouble();

      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + amount;
      totalRevenue += amount;
      totalOrders++;
    }

    return {
      'dailyRevenue': dailyRevenue,
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'averageOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
    };
  } catch (e) {
    print('Error getting merchant revenue analytics: $e');
    return {
      'dailyRevenue': {},
      'totalRevenue': 0.0,
      'totalOrders': 0,
      'averageOrderValue': 0.0,
    };
  }
}

  static Future<Map<String, dynamic>> getCategoryPerformance() async {
    try {
      final foods = await FirebaseService.foods
          .where('isActive', isEqualTo: true)
          .get();
      
      final orders = await FirebaseService.orders
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
          .get();

      final categoryCount = <String, int>{};
      final categoryRevenue = <String, double>{};

      for (final food in foods.docs) {
        final data = food.data() as Map<String, dynamic>;
        final categories = List<String>.from(data['categories'] ?? []);
        
        for (final category in categories) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      for (final order in orders.docs) {
        final data = order.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        
        for (final item in items) {
          final foodName = item['foodName'] ?? '';
          final amount = (item['price'] ?? 0.0).toDouble() * (item['quantity'] ?? 1);
          
          final detectedCategory = _detectCategoryFromName(foodName);
          categoryRevenue[detectedCategory] = (categoryRevenue[detectedCategory] ?? 0.0) + amount;
        }
      }

      return {
        'categoryCount': categoryCount,
        'categoryRevenue': categoryRevenue,
      };
    } catch (e) {
      print('Error getting category performance: $e');
      return {
        'categoryCount': {},
        'categoryRevenue': {},
      };
    }
  }

static Map<String, int> _groupByDateCumulative(List<QueryDocumentSnapshot> docs, String dateField) {
  final result = <String, int>{};
  int cumulativeCount = 0;
  
  docs.sort((a, b) {
    final aData = a.data() as Map<String, dynamic>?;
    final bData = b.data() as Map<String, dynamic>?;
    
    final aTimestamp = aData?[dateField] as Timestamp?;
    final bTimestamp = bData?[dateField] as Timestamp?;
    
    final aDate = aTimestamp?.toDate() ?? DateTime.now();
    final bDate = bTimestamp?.toDate() ?? DateTime.now();
    
    return aDate.compareTo(bDate);
  });
  
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>?;
    final timestamp = data?[dateField] as Timestamp?;
    
    if (timestamp != null) {
      final date = timestamp.toDate();
      final dateKey = '${date.day}/${date.month}';
      
      cumulativeCount++;
      result[dateKey] = cumulativeCount;
    }
  }
  
  return result;
}

  static String _detectCategoryFromName(String foodName) {
    final name = foodName.toLowerCase();
    
    if (name.contains('sushi') || name.contains('ramen') || name.contains('japanese')) {
      return 'Japanese';
    } else if (name.contains('pizza') || name.contains('pasta') || name.contains('italian')) {
      return 'Italian';
    } else if (name.contains('burger') || name.contains('fries') || name.contains('fast food')) {
      return 'Fast Food';
    } else if (name.contains('rice') || name.contains('noodle') || name.contains('asian')) {
      return 'Asian';
    } else if (name.contains('cake') || name.contains('dessert') || name.contains('sweet')) {
      return 'Dessert';
    } else if (name.contains('salad') || name.contains('healthy') || name.contains('vegan')) {
      return 'Healthy';
    } else if (name.contains('taco') || name.contains('burrito') || name.contains('mexican')) {
      return 'Mexican';
    } else {
      return 'Other';
    }
  }

  static Future<Map<String, dynamic>> getPlatformStats() async {
    try {
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
    } catch (e) {
      print('Error getting platform stats: $e');
      return {
        'totalUsers': 0,
        'totalRestaurants': 0,
        'pendingVerifications': 0,
        'totalOrders': 0,
      };
    }
  }

  static Future<Map<String, dynamic>> getMerchantPerformance(String restaurantId, {int days = 30}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    try {
      final orders = await FirebaseService.orders
          .where('restaurantId', isEqualTo: restaurantId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      double totalRevenue = 0.0;
      int totalOrders = 0;
      final dailyRevenue = <String, double>{};
      final popularItems = <String, int>{};

      for (final order in orders.docs) {
        final data = order.data() as Map<String, dynamic>;
        final date = (data['createdAt'] as Timestamp).toDate();
        final dateKey = '${date.day}/${date.month}';
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + amount;
        totalRevenue += amount;
        totalOrders++;

        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        for (final item in items) {
          final itemName = item['foodName'] ?? '';
          final quantity = (item['quantity'] ?? 0) as int;
          popularItems[itemName] = (popularItems[itemName] ?? 0) + quantity;
        }
      }

      final sortedPopularItems = Map.fromEntries(
        popularItems.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
      );

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'averageOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
        'dailyRevenue': dailyRevenue,
        'popularItems': sortedPopularItems,
        'timeframe': '$days days',
      };
    } catch (e) {
      print('Error getting merchant performance: $e');
      return {
        'totalRevenue': 0.0,
        'totalOrders': 0,
        'averageOrderValue': 0.0,
        'dailyRevenue': {},
        'popularItems': {},
        'timeframe': '$days days',
      };
    }
  }
  
}