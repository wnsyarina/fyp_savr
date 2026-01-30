import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/features/customer/pages/restaurant_food_page.dart';
import 'package:fyp_savr/data/services/cart_service.dart';
import 'package:fyp_savr/data/models/cart_item_model.dart';
import '../widgets/food_item_card.dart';

class AllDealsPage extends StatefulWidget {
  const AllDealsPage({super.key});

  @override
  State<AllDealsPage> createState() => _AllDealsPageState();
}

class _AllDealsPageState extends State<AllDealsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Food Deals'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FoodService.getFeaturedFoods(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoDealsAvailable();
          }

          final foodDeals = snapshot.data!.docs;

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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: foodsWithRatings.length,
                itemBuilder: (context, index) {
                  final foodData = foodsWithRatings[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FoodItemCard(
                      foodItem: {
                        'id': foodData['foodId'],
                        ...foodData,
                      },
                      onTap: () async {
                        final restaurantId = foodData['restaurantId'];
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
                        _addFoodToCart(foodData['foodId'], foodData);
                      },
                      showRestaurantRating: true,
                      restaurantRating: foodData['restaurantRating'],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No Food Deals Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for discounted surplus food!',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFoodToCart(String foodId, Map<String, dynamic> foodData) async {
    try {
      final cartItem = CartItem(
        foodId: foodId,
        foodName: foodData['name'] ?? 'Unknown Food',
        restaurantId: foodData['restaurantId'],
        restaurantName: foodData['restaurantName'] ?? 'Unknown Restaurant',
        price: (foodData['discountPrice'] ?? 0.0).toDouble(),
        quantity: 1,
        imageBase64: foodData['imageBase64'],
      );

      await CartService.addToCart(cartItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${foodData['name']} added to cart!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}