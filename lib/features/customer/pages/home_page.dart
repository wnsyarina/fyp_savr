import 'package:flutter/material.dart';
import 'package:fyp_savr/features/customer/pages/search_page.dart';
import 'package:fyp_savr/features/customer/pages/cart_page.dart';
import 'package:fyp_savr/features/customer/pages/profile_page.dart';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/features/customer/widgets/food_item_card.dart';
import 'package:fyp_savr/features/customer/pages/restaurant_food_page.dart';
import 'package:fyp_savr/data/services/cart_service.dart';
import '../../../data/models/cart_item_model.dart';
import 'package:fyp_savr/features/customer/pages/all_restaurants_page.dart';
import 'all_deals_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeContentPage(),
      const SearchPage(),
      const CartPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeContentPage extends StatefulWidget {
  const HomeContentPage({super.key});

  @override
  State<HomeContentPage> createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage> {
  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.all_inclusive},
    {'name': 'Sushi', 'icon': Icons.restaurant},
    {'name': 'Pizza', 'icon': Icons.local_pizza},
    {'name': 'Burger', 'icon': Icons.fastfood},
    {'name': 'Asian', 'icon': Icons.ramen_dining},
    {'name': 'Dessert', 'icon': Icons.cake},
  ];

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  String _userName = 'Customer';
  String _userAddress = 'No address set';
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            _userName = userData?['name'] ?? user.displayName ?? 'Customer';
            _userAddress = userData?['address'] ?? 'No address set';
            _isLoadingUserData = false;
          });
        } else {
          setState(() {
            _userName = user.displayName ?? 'Customer';
            _userAddress = 'No address set';
            _isLoadingUserData = false;
          });
        }
      } else {
        setState(() => _isLoadingUserData = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'Customer';
        _userAddress = 'No address set';
        _isLoadingUserData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savr'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUserHeader(),

                  _buildCategoriesList(),

                  _buildTopRestaurantsSection(),

                  _buildTopDealsSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 30,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back,', style: TextStyle(color: Colors.grey)),
                _isLoadingUserData
                    ? const SizedBox(
                  height: 20,
                  child: SizedBox(
                    width: 100,
                    height: 12,
                    child: LinearProgressIndicator(),
                  ),
                )
                    : Text(
                  _userName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                _isLoadingUserData
                    ? const SizedBox(
                  height: 16,
                  child: SizedBox(
                    width: 150,
                    height: 10,
                    child: LinearProgressIndicator(),
                  ),
                )
                    : Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _userAddress,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final categoryName = category['name'] as String;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                print('Selected category: $categoryName');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchPage(
                      initialQuery: categoryName,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      color: Colors.orange,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopRestaurantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Restaurants Near You',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllRestaurantsPage(),
                    ),
                  );
                },
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: RestaurantService.getAllRestaurants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('Error: ${snapshot.error}')),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('No restaurants found.')),
              );
            }

            final restaurants = snapshot.data!.docs;

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getRestaurantsWithOpenStatus(restaurants),
              builder: (context, statusSnapshot) {
                if (statusSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final restaurantsWithStatus = statusSnapshot.data ?? [];

                restaurantsWithStatus.sort((a, b) {
                  if (a['isOpen'] != b['isOpen']) {
                    return b['isOpen'] ? 1 : -1;
                  }
                  final ratingA = a['rating'] ?? 0.0;
                  final ratingB = b['rating'] ?? 0.0;
                  return ratingB.compareTo(ratingA);
                });

                final topRestaurants = restaurantsWithStatus.take(3).toList();

                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: topRestaurants.length,
                    itemBuilder: (context, index) {
                      final restaurantData = topRestaurants[index];
                      return _buildHorizontalRestaurantCard(
                        restaurantId: restaurantData['id'],
                        data: restaurantData,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _getRestaurantsWithOpenStatus(List<QueryDocumentSnapshot> restaurants) async {
    final List<Map<String, dynamic>> result = [];

    for (final restaurant in restaurants) {
      final data = restaurant.data() as Map<String, dynamic>;
      final isOpen = await _isRestaurantOpen(restaurant.id, data);

      result.add({
        'id': restaurant.id,
        ...data,
        'isOpen': isOpen,
      });
    }

    return result;
  }

  Widget _buildHorizontalRestaurantCard({
    required String restaurantId,
    required Map<String, dynamic> data,
  }) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getCompleteRestaurantData(restaurantId, data),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 180,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 180,
                child: const Center(child: Icon(Icons.error)),
              ),
            ),
          );
        }

        final completeData = snapshot.data ?? data;

        final shouldBeOpen = _shouldRestaurantBeOpen(completeData);
        final rating = completeData['rating'] ?? 0.0;
        final totalReviews = completeData['totalReviews'] ?? 0;
        final cuisineTypes = (completeData['cuisineTypes'] as List?)?.join(', ') ?? 'Various Cuisines';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantFoodPage(
                  restaurant: {
                    'id': restaurantId,
                    ...completeData,
                  },
                ),
              ),
            );
          },
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        image: completeData['coverImageBase64'] != null &&
                            completeData['coverImageBase64'].isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(
                              'data:image/jpeg;base64,${completeData['coverImageBase64']}'),
                          fit: BoxFit.cover,
                        )
                            : const DecorationImage(
                          image: NetworkImage(
                              'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: shouldBeOpen ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                shouldBeOpen ? 'Open' : 'Closed',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            height: 22,
                            child: Text(
                              completeData['name'] ?? 'Restaurant',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          SizedBox(
                            height: 16,
                            child: Text(
                              cuisineTypes,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          SizedBox(
                            height: 22,
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    completeData['deliveryTime'] ?? '20-30 min',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${totalReviews} reviews',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _shouldRestaurantBeOpen(Map<String, dynamic> restaurantData) {
    try {
      final openingHours = restaurantData['openingHours'] as Map<String, dynamic>?;
      if (openingHours == null) return true;

      final now = DateTime.now();
      final dayName = _getDayName(now.weekday);
      final dayHours = openingHours[dayName] as Map<String, dynamic>?;

      if (dayHours == null) return true;

      final isDayClosed = dayHours['isClosed'] ?? false;
      if (isDayClosed) return false;

      final openTime = dayHours['open'] as String?;
      final closeTime = dayHours['close'] as String?;

      if (openTime == null || closeTime == null) return true;

      return _isTimeBetween(now, openTime, closeTime);
    } catch (e) {
      print('Error checking restaurant open status: $e');
      return false;
    }
  }


  Widget _buildTopDealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Top Deals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllDealsPage(),
                    ),
                  );
                },
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: FoodService.getFeaturedFoods(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('Error: ${snapshot.error}')),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildNoDealsAvailable();
            }

            final foodDeals = snapshot.data!.docs;

            // Get restaurant ratings for sorting
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getFoodsWithRestaurantRatings(foodDeals),
              builder: (context, ratingSnapshot) {
                if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final foodsWithRatings = ratingSnapshot.data ?? [];

                foodsWithRatings.sort((a, b) {
                  final ratingA = a['restaurantRating'] ?? 0.0;
                  final ratingB = b['restaurantRating'] ?? 0.0;
                  return ratingB.compareTo(ratingA);
                });

                final topFoods = foodsWithRatings.take(4).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: topFoods.map((foodData) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildVerticalFoodCard(
                          foodId: foodData['foodId'],
                          data: foodData,
                          restaurantRating: foodData['restaurantRating'],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVerticalFoodCard({
    required String foodId,
    required Map<String, dynamic> data,
    required double restaurantRating,
  }) {
    return FoodItemCard(
      foodItem: {
        'id': foodId,
        ...data,
      },
      onTap: () async {
        final restaurantId = data['restaurantId'];
        if (restaurantId != null) {
          final restaurantDoc = await FirebaseService.restaurants
              .doc(restaurantId)
              .get();
          final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

          if (restaurantData != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantFoodPage(
                  restaurant: {
                    'id': restaurantId,
                    ...restaurantData,
                  },
                ),
              ),
            );
          }
        }
      },
      onAddToCart: () {
        _addFoodToCart(foodId, data);
      },
      showRestaurantRating: true,
      restaurantRating: restaurantRating,
    );
  }

  Future<List<Map<String, dynamic>>> _getFoodsWithRestaurantRatings(List<QueryDocumentSnapshot> foodDocs) async {
    final List<Map<String, dynamic>> result = [];

    for (final foodDoc in foodDocs) {
      final foodData = foodDoc.data() as Map<String, dynamic>;
      final restaurantId = foodData['restaurantId'];

      double restaurantRating = 0.0;

      if (restaurantId != null) {
        try {
          final restaurantDoc = await FirebaseService.restaurants
              .doc(restaurantId)
              .get();
          final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
          restaurantRating = restaurantData?['rating'] ?? 0.0;
        } catch (e) {
          print('Error getting restaurant rating: $e');
        }
      }

      result.add({
        'foodId': foodDoc.id,
        ...foodData,
        'restaurantRating': restaurantRating,
      });
    }

    return result;
  }

  Widget _buildNoDealsAvailable() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.sentiment_dissatisfied,
              size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          const Text('No deals available at the moment'),
          const SizedBox(height: 8),
          Text(
            'Check back later for amazing discounts!',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _addFoodToCart(String foodId, Map<String, dynamic> foodData) async {
    try {
      final restaurantId = foodData['restaurantId'];
      if (restaurantId != null) {
        final restaurantDoc = await FirebaseService.restaurants
            .doc(restaurantId)
            .get();
        final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

        if (restaurantData != null) {
          final isRestaurantOpen = _shouldRestaurantBeOpen(restaurantData);

          if (!isRestaurantOpen) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${restaurantData['name'] ?? 'Restaurant'} is currently closed'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
        }
      }

      final quantityAvailable = foodData['quantityAvailable'] ?? 0;
      final isAvailable = foodData['isAvailable'] ?? false;

      if (!isAvailable || quantityAvailable <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${foodData['name']} is sold out!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final restaurantDoc = await FirebaseService.restaurants
          .doc(restaurantId)
          .get();
      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;

      final cartItem = CartItem(
        foodId: foodId,
        foodName: foodData['name'] ?? 'Unknown Food',
        restaurantId: restaurantId,
        restaurantName: restaurantData?['name'] ?? 'Unknown Restaurant',
        price: (foodData['discountPrice'] ?? 0.0).toDouble(),
        quantity: 1,
        imageBase64: foodData['imageBase64'],
      );

      await CartService.addToCart(cartItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${foodData['name']} added to cart!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

    } catch (e) {
      print('Error adding to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  bool _isTimeBetween(DateTime now, String openTime, String closeTime) {
    try {
      final partsOpen = openTime.split(':');
      final partsClose = closeTime.split(':');

      final openHour = int.parse(partsOpen[0]);
      final openMinute = partsOpen.length > 1 ? int.parse(partsOpen[1]) : 0;

      final closeHour = int.parse(partsClose[0]);
      final closeMinute = partsClose.length > 1 ? int.parse(partsClose[1]) : 0;

      final currentHour = now.hour;
      final currentMinute = now.minute;

      final currentTotal = currentHour * 60 + currentMinute;
      final openTotal = openHour * 60 + openMinute;
      final closeTotal = closeHour * 60 + closeMinute;

      if (closeTotal < openTotal) {
        return currentTotal >= openTotal || currentTotal <= closeTotal;
      }

      return currentTotal >= openTotal && currentTotal <= closeTotal;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isRestaurantOpen(String restaurantId, Map<String, dynamic> restaurantData) async {
    if (restaurantData.containsKey('isOpenCalculated')) {
      return restaurantData['isOpenCalculated'] ?? false;
    }

    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      if (!restaurantDoc.exists) return false;

      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
      if (restaurantData == null) return false;

      return _shouldRestaurantBeOpen(restaurantData);
    } catch (e) {
      print('Error checking restaurant open status: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _getCompleteRestaurantData(String restaurantId, Map<String, dynamic> initialData) async {
    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      if (restaurantDoc.exists) {
        final data = restaurantDoc.data() as Map<String, dynamic>?;
        return data ?? initialData;
      }
      return initialData;
    } catch (e) {
      print('Error fetching complete restaurant data: $e');
      return initialData;
    }
  }

}