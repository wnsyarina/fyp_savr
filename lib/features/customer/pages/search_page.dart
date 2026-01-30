import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/food_service.dart';
import 'package:fyp_savr/data/services/restaurant_service.dart';
import 'package:fyp_savr/features/customer/pages/restaurant_food_page.dart';
import 'package:fyp_savr/features/customer/pages/restaurant_map_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    if (widget.initialQuery != null) {
      _searchQuery = widget.initialQuery!;
      _searchController.text = widget.initialQuery!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search nearby food deals...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _searchQuery = _searchController.text;
                    });
                  },
                ),
              ),
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searchQuery.isEmpty) {
      return _buildDefaultView();
    } else {
      return _buildSearchResults();
    }
  }

  Widget _buildDefaultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNearbyRestaurantsSection(),

          const SizedBox(height: 24),

          _buildQuickCategories(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNearbyRestaurantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nearby Restaurants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Find restaurants near your location with available food deals',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        StreamBuilder<QuerySnapshot>(
          stream: RestaurantService.getAllRestaurants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading restaurants: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No restaurants available nearby'),
              );
            }

            final restaurants = snapshot.data!.docs;

            return Column(
              children: restaurants
                  .take(3)
                  .map((doc) {
                final restaurant = doc.data() as Map<String, dynamic>;
                return _buildRestaurantCard(
                  restaurantId: doc.id,
                  restaurantData: {
                    'id': doc.id,
                    'name': restaurant['name'] ?? 'Unknown Restaurant',
                    'cuisine': (restaurant['cuisineTypes'] as List<dynamic>?)?.first ?? 'Various',
                    'rating': restaurant['rating'] ?? 0.0,
                    'address': restaurant['address'] ?? 'No address',
                    'distance': 'Nearby',
                  },
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RestaurantMapPage(),
                ),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Interactive Map to Find Restaurants'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[50],
              foregroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard({
    required String restaurantId,
    required Map<String, dynamic> restaurantData,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.restaurant, color: Colors.orange),
        ),
        title: Text(
          restaurantData['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(restaurantData['cuisine']),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${(restaurantData['rating'] as double).toStringAsFixed(2)}'),
                const SizedBox(width: 16),
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(restaurantData['distance']),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToRestaurantFoods(restaurantId, restaurantData),
      ),
    );
  }

  Widget _buildQuickCategories() {
    final categories = [
      {'name': 'Sushi', 'icon': Icons.restaurant, 'color': Colors.blue},
      {'name': 'Pizza', 'icon': Icons.local_pizza, 'color': Colors.red},
      {'name': 'Burger', 'icon': Icons.fastfood, 'color': Colors.orange},
      {'name': 'Asian', 'icon': Icons.ramen_dining, 'color': Colors.green},
      {'name': 'Dessert', 'icon': Icons.cake, 'color': Colors.pink},
      {'name': 'Healthy', 'icon': Icons.fitness_center, 'color': Colors.purple},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Categories',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _buildCategoryCard(category);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _searchQuery = category['name'];
            _searchController.text = category['name'];
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category['icon'], color: category['color'], size: 30),
            const SizedBox(height: 8),
            Text(category['name'], style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FoodService.searchFoods(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Search error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults();
        }

        final searchResults = snapshot.data!.docs;

        return Column(
          children: [
            // Search header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Text(
                    'Results for "$_searchQuery"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    '${searchResults.length} found',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Search results
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final foodDoc = searchResults[index];
                  final foodData = foodDoc.data() as Map<String, dynamic>;

                  return _buildFoodResultCard(foodDoc.id, foodData);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFoodResultCard(String foodId, Map<String, dynamic> foodData) {
    final originalPrice = (foodData['originalPrice'] ?? 0.0).toDouble();
    final discountPrice = (foodData['discountPrice'] ?? 0.0).toDouble();
    final discountPercent = ((originalPrice - discountPrice) / originalPrice * 100).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildFoodImage(foodData),
        title: Text(
          foodData['name'] ?? 'Unknown Food',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(foodData['restaurantName'] ?? 'Unknown Restaurant'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'RM${discountPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(width: 8),
                Text(
                  'RM${originalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$discountPercent% OFF',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _navigateToRestaurantFoods(
            foodData['restaurantId'] ?? '',
            {
              'id': foodData['restaurantId'],
              'name': foodData['restaurantName'] ?? 'Restaurant',
            },
          );
        },
      ),
    );
  }

  Widget _buildFoodImage(Map<String, dynamic> foodData) {
    final imageUrl = foodData['imageUrl'] as String?;
    final imageBase64 = foodData['imageBase64'] as String?;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _getFoodImageWidget(imageUrl, imageBase64),
      ),
    );
  }

  Widget _getFoodImageWidget(String? imageUrl, String? imageBase64) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) {
          print('Error loading image from URL: $error');
          return _buildImageFallback();
        },
      );
    }

    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error decoding base64 image: $error');
            return _buildImageFallback();
          },
        );
      } catch (e) {
        print('Base64 decode error: $e');
        return _buildImageFallback();
      }
    }

    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.fastfood, color: Colors.grey),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No results found', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Try searching with different keywords', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RestaurantMapPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('Search on Map'),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }

  void _openGoogleMaps() async {
    const double lat = 3.1390;
    const double lng = 101.6869;
    final String googleMapsUrl = 'https://www.google.com/maps/search/restaurants+near+me/@$lat,$lng,15z';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        _showMapError();
      }
    } catch (e) {
      _showMapError();
    }
  }

  void _showMapError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open Google Maps. Please make sure it is installed.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _navigateToRestaurantFoods(String restaurantId, Map<String, dynamic> restaurantData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();

      if (!restaurantDoc.exists) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant not found')),
        );
        return;
      }

      final completeRestaurantData = restaurantDoc.data() as Map<String, dynamic>;

      completeRestaurantData['id'] = restaurantId;

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantFoodPage(
            restaurant: completeRestaurantData,
          ),
        ),
      );

    } catch (e) {
      Navigator.pop(context);
      print('Error navigating to restaurant foods: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}