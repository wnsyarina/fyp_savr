import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fyp_savr/utils/helpers.dart';

class FoodItemCard extends StatelessWidget {
  final Map<String, dynamic> foodItem;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final bool showRestaurantRating;
  final double restaurantRating;

  const FoodItemCard({
    super.key,
    required this.foodItem,
    this.onTap,
    this.onAddToCart,
    this.showRestaurantRating = false,
    this.restaurantRating = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final discountPercentage = ((foodItem['originalPrice'] - foodItem['discountPrice']) / foodItem['originalPrice'] * 100).round();
    final timeRemaining = _getTimeRemaining(foodItem['pickupEnd']);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food Image
              _buildFoodImage(),
              const SizedBox(width: 12),
              
              // Food Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodItem['name'] ?? 'Unknown Food',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      foodItem['restaurantName'] ?? 'Unknown Restaurant',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Price Section
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'RM${foodItem['discountPrice']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'RM${foodItem['originalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                            '$discountPercentage% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Additional Info
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          timeRemaining,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.inventory, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${foodItem['quantityAvailable'] ?? 0} left',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Add to Cart Button
              if (onAddToCart != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onAddToCart,
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.deepOrange),
                  tooltip: 'Add to Cart',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _getFoodImage(),
      ),
    );
  }

  Widget _getFoodImage() {
    final imageUrl = foodItem['imageUrl'] as String?;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          print('Error loading image from URL: $error');
          return _buildImageFallback();
        },
      );
    }

    final imageBase64 = foodItem['imageBase64'] as String?;
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
        child: Icon(Icons.fastfood, color: Colors.grey, size: 40),
      ),
    );
  }

  String _getTimeRemaining(dynamic pickupEnd) {
    if (pickupEnd == null) return 'Unknown time';
    
    DateTime endTime;
    if (pickupEnd is Timestamp) {
      endTime = pickupEnd.toDate();
    } else if (pickupEnd is DateTime) {
      endTime = pickupEnd;
    } else {
      return 'Unknown time';
    }
    
    return Helpers.getTimeRemaining(endTime);
  }
}