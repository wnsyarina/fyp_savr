import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';
import 'package:fyp_savr/features/customer/pages/restaurant_food_page.dart';

class AllRestaurantsPage extends StatefulWidget {
  const AllRestaurantsPage({super.key});

  @override
  State<AllRestaurantsPage> createState() => _AllRestaurantsPageState();
}

class _AllRestaurantsPageState extends State<AllRestaurantsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Restaurants'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: RestaurantService.getAllRestaurants(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No restaurants found'));
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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: restaurantsWithStatus.length,
                itemBuilder: (context, index) {
                  final restaurantData = restaurantsWithStatus[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildVerticalRestaurantCard(
                      restaurantId: restaurantData['id'],
                      data: restaurantData,
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

  Widget _buildVerticalRestaurantCard({
    required String restaurantId,
    required Map<String, dynamic> data,
  }) {
    final shouldBeOpen = _shouldRestaurantBeOpen(data);
    final rating = data['rating'] ?? 0.0;
    final totalReviews = data['totalReviews'] ?? 0;
    final cuisineTypes = (data['cuisineTypes'] as List?)?.join(', ') ?? 'Various Cuisines';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantFoodPage(
              restaurant: {
                'id': restaurantId,
                ...data,
              },
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Restaurant Image
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                image: data['coverImageBase64'] != null &&
                    data['coverImageBase64'].isNotEmpty
                    ? DecorationImage(
                  image: NetworkImage(
                      'data:image/jpeg;base64,${data['coverImageBase64']}'),
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

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    data['name'] ?? 'Restaurant',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Text(
                    cuisineTypes,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        data['deliveryTime'] ?? '20-30 min',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['address'] ?? 'No address',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${totalReviews} reviews',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
}