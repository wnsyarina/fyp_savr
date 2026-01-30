import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/notification_service.dart';
import 'package:fyp_savr/data/services/order_service.dart'; // ADD THIS
import 'package:fyp_savr/features/merchant/pages/add_food_item_page.dart';
import 'package:fyp_savr/features/merchant/pages/edit_food_item_page.dart'; // ADD THIS
import 'package:fyp_savr/features/merchant/pages/merchant_profile_page.dart';
import 'package:fyp_savr/features/merchant/widgets/food_management_card.dart';
import 'package:fyp_savr/features/merchant/widgets/stats_card.dart';
import 'package:fyp_savr/features/merchant/pages/wallet_page.dart';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/features/merchant/pages/order_management_page.dart';
import 'package:fyp_savr/features/merchant/pages/merchant_analytics_page.dart';
import '../widgets/notification_bell.dart';

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key});

  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard> {
  int _currentIndex = 0;
  Map<String, dynamic>? _foodStats;
  bool _isLoading = true;
  StreamSubscription? _orderSubscription;
  Set<String> _seenOrderIds = {};

  final List<Widget> _pages = [
    const FoodManagementPage(),
    const OrderManagementPage(),
    const MerchantAnalyticsPage(),
    const WalletPage(),
    const MerchantProfilePage(),
  ];

  final List<String> _pageTitles = [
    'Food Management',
    'Orders',
    'Analytics',
    'Wallet',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _loadFoodStats();
    _listenForNewOrders();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _listenForNewOrders() {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;

    _orderSubscription = OrderService.getRestaurantOrders(user.uid)
        .listen((snapshot) {
      if (!mounted) return;

      for (final doc in snapshot.docs) {
        final orderData = doc.data() as Map<String, dynamic>;
        final orderId = orderData['orderId'] ?? doc.id;
        final status = orderData['status'] ?? '';

        if (status == 'pending' && !_seenOrderIds.contains(orderId)) {
          _seenOrderIds.add(orderId); // Mark as seen
          
          if (_currentIndex != 1) {
            NotificationService.showNewOrderAlert(
              context: context,
              orderId: orderId,
              customerName: orderData['customerName'] ?? 'Customer',
              totalAmount: (orderData['totalAmount'] ?? 0.0).toDouble(),
              orderNumber: orderData['orderNumber'] ?? orderId.substring(0, 8),
              onViewOrder: () {
                setState(() => _currentIndex = 1);
              },
            );
          }
        }
      }
    });
  }

  Future<void> _loadFoodStats() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final stats = await FoodService.getFoodStats(user.uid);
        setState(() {
          _foodStats = stats;
        });
      }
    } catch (e) {
      print('Error loading food stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_currentIndex]),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          const NotificationBell(),

          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFoodItemPage()),
              ),
              tooltip: 'Add New Food Item',
            ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: 'Food',
          ),
          BottomNavigationBarItem( 
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class FoodManagementPage extends StatefulWidget {
  const FoodManagementPage({super.key});

  @override
  State<FoodManagementPage> createState() => _FoodManagementPageState();
}

class _FoodManagementPageState extends State<FoodManagementPage> {
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _foods = [];

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final foodsStream = FoodService.getRestaurantFoods(user.uid);
        foodsStream.listen((snapshot) {
          if (mounted) {
            setState(() {
              _foods = snapshot.docs;
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error loading foods: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFoodItem(String foodId) async {
    try {
      await FoodService.deleteFoodItem(foodId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food item deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting food item: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _duplicateFoodItem(String originalFoodId) async {
    try {
      await FoodService.duplicateFoodItem(originalFoodId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food item duplicated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error duplicating food item: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_foods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Food Items Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first food item to get started',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFoodItemPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Food Item'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFoods,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _foods.length,
        itemBuilder: (context, index) {
          final food = _foods[index].data() as Map<String, dynamic>;
          final foodId = _foods[index].id;

          return FoodManagementCard(
            foodItem: food,
            foodId: foodId,
            onEdit: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditFoodItemPage(
                    foodItem: food,
                    foodId: foodId,
                  ),
                ),
              );
            },
            onDelete: () => _showDeleteConfirmation(foodId, food['name']),
            onDuplicate: () => _duplicateFoodItem(foodId),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String foodId, String foodName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Food Item?'),
        content: Text('Are you sure you want to delete "$foodName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFoodItem(foodId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Map<String, dynamic>? _foodStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final stats = await FoodService.getFoodStats(user.uid);
        if (mounted) {
          setState(() {
            _foodStats = stats;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _foodStats ?? {
      'activeCount': 0,
      'totalCount': 0,
      'expiringSoonCount': 0,
      'totalValue': 0.0,
      'totalDiscountedValue': 0.0,
      'totalSavings': 0.0,
    };

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                StatsCard(
                  title: 'Active Listings',
                  value: stats['activeCount'].toString(),
                  subtitle: 'Currently available',
                  icon: Icons.fastfood,
                  color: Colors.green,
                ),
                StatsCard(
                  title: 'Total Listings',
                  value: stats['totalCount'].toString(),
                  subtitle: 'All time',
                  icon: Icons.inventory,
                  color: Colors.blue,
                ),
                StatsCard(
                  title: 'Expiring Soon',
                  value: stats['expiringSoonCount'].toString(),
                  subtitle: 'Within 2 hours',
                  icon: Icons.timer,
                  color: Colors.orange,
                ),
                StatsCard(
                  title: 'Total Value',
                  value: 'RM${stats['totalValue'].toStringAsFixed(2)}',
                  subtitle: 'At original price',
                  icon: Icons.attach_money,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Savings Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Customer Savings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'RM${stats['totalSavings'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Total amount saved by customers',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Add New Food'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddFoodItemPage()),
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh Stats'),
                          onPressed: _loadStats,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}