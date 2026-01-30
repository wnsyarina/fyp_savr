import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/data/services/cart_service.dart';
import 'package:fyp_savr/data/models/cart_item_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/features/customer/widgets/food_item_card.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class RestaurantFoodPage extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantFoodPage({super.key, required this.restaurant});

  @override
  State<RestaurantFoodPage> createState() => _RestaurantFoodPageState();
}

class _RestaurantFoodPageState extends State<RestaurantFoodPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildRestaurantHeaderImage(),
              title: Text(
                widget.restaurant['name'] ?? 'Restaurant',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
              centerTitle: true,
            ),
          ),

          SliverToBoxAdapter(
            child: _buildRestaurantDetails(),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _buildFoodDealsHeader(),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FoodService.getRestaurantFoods(widget.restaurant['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading food items',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: _buildNoFoodAvailable(),
                );
              }

              final foodItems = snapshot.data!.docs;

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final doc = foodItems[index];
                    final foodData = doc.data() as Map<String, dynamic>;
                    return _buildFoodCard(doc.id, foodData);
                  },
                  childCount: foodItems.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantHeaderImage() {
    return Container(
      decoration: BoxDecoration(
        image: widget.restaurant['coverImageBase64'] != null &&
            widget.restaurant['coverImageBase64'].isNotEmpty
            ? DecorationImage(
          image: NetworkImage(
              'data:image/jpeg;base64,${widget.restaurant['coverImageBase64']}'),
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
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantDetails() {
    final openingHours = widget.restaurant['openingHours'] as Map<String, dynamic>?;

    return FutureBuilder<bool>(
      future: _isRestaurantOpen(widget.restaurant['id']),
      builder: (context, snapshot) {
        final isOpen = snapshot.data ?? false;
        final cuisineTypes = (widget.restaurant['cuisineTypes'] as List?)?.join(' • ') ?? 'Various Cuisines';
        final rating = widget.restaurant['rating'] ?? 0.0;
        final address = widget.restaurant['address'] ?? 'No address available';
        final description = widget.restaurant['description'] ?? '';

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOpen ? Colors.green[100]! : Colors.red[100]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOpen ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: isOpen ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOpen ? 'Open Now' : 'Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                cuisineTypes,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (widget.restaurant['phone'] != null)
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.restaurant['phone'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],

              if (widget.restaurant['deliveryTime'] != null) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Pickup time: ${widget.restaurant['deliveryTime']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoodDealsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Food Deals',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Discounted surplus food items',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodCard(String foodId, Map<String, dynamic> foodData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: FoodItemCard(
        foodItem: {
          'id': foodId,
          ...foodData,
        },
        onTap: () {
          _showFoodDetails(foodId, foodData);
        },
        onAddToCart: () => _addToCart(foodId, foodData),
      ),
    );
  }

  void _showFoodDetails(String foodId, Map<String, dynamic> foodData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                foodData['name'] ?? 'Food Item',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                foodData['description'] ?? 'No description available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RM${foodData['discountPrice']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'RM${foodData['originalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addToCart(foodId, foodData),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoFoodAvailable() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Icon(
            Icons.fastfood_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'No Food Deals Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This restaurant doesn\'t have any active deals at the moment.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for discounted surplus food!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(String foodId, Map<String, dynamic> foodData) async {
    try {
      final cartItem = CartItem(
        foodId: foodId,
        foodName: foodData['name'] ?? 'Unknown Food',
        restaurantId: widget.restaurant['id'],
        restaurantName: widget.restaurant['name'] ?? 'Unknown Restaurant',
        price: (foodData['discountPrice'] ?? 0.0).toDouble(),
        quantity: 1,
        imageBase64: foodData['imageBase64'],
      );

      await CartService.addToCart(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${foodData['name']} added to cart!',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to add to cart: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  Future<bool> _isRestaurantOpen(String restaurantId) async {
    try {
      final restaurantDoc = await FirebaseService.restaurants.doc(restaurantId).get();
      if (!restaurantDoc.exists) return false;

      final restaurantData = restaurantDoc.data() as Map<String, dynamic>?;
      if (restaurantData == null) return false;

      final openingHours = restaurantData['openingHours'] as Map<String, dynamic>?;
      if (openingHours == null) return true; // No hours set, assume open

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
}