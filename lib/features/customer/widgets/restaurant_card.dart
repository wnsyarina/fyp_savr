import 'package:flutter/material.dart';
import 'dart:convert';

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;
  final double? distance;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final rating = restaurant['rating'] ?? 0.0;
    final totalReviews = restaurant['totalReviews'] ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Restaurant Image
              _buildRestaurantImage(),
              const SizedBox(width: 16),
              
              // Restaurant Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant['name'] ?? 'Unknown Restaurant',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Cuisine Types
                    if (restaurant['cuisineTypes'] != null && (restaurant['cuisineTypes'] as List).isNotEmpty)
                      Text(
                        (restaurant['cuisineTypes'] as List).join(', '),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Rating and Delivery Time
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1)),
                        const SizedBox(width: 8),
                        Text('($totalReviews)'),
                        const SizedBox(width: 16),
                        Icon(Icons.timer, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(restaurant['deliveryTime'] ?? '20-30 min'),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Distance and Address
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurant['address'] ?? 'No address',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    if (distance != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${distance!.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Status Indicator
              Column(
                children: [
                  _buildStatusIndicator(),
                  const SizedBox(height: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.deepOrange[100],
      ),
      child: restaurant['logoBase64'] != null && restaurant['logoBase64'].isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(restaurant['logoBase64']!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.restaurant, color: Colors.deepOrange);
                },
              ),
            )
          : const Icon(Icons.restaurant, size: 40, color: Colors.deepOrange),
    );
  }

  Widget _buildStatusIndicator() {
    final isOpen = restaurant['isOpen'] ?? false;
    final isVerified = restaurant['isVerified'] ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isVerified)
          const Icon(Icons.verified, color: Colors.green, size: 16),
        if (isVerified) const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isOpen ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOpen ? 'Open' : 'Closed',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}