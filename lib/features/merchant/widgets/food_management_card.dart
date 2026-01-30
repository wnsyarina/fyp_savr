import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fyp_savr/utils/helpers.dart';

class FoodManagementCard extends StatelessWidget {
  final Map<String, dynamic> foodItem;
  final String foodId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;

  const FoodManagementCard({
    super.key,
    required this.foodItem,
    required this.foodId,
    required this.onEdit,
    required this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final discountPercentage = ((foodItem['originalPrice'] - foodItem['discountPrice']) / foodItem['originalPrice'] * 100).round();
    final timeRemaining = _getTimeRemaining(foodItem['pickupEnd']);
    final isAvailable = foodItem['isAvailable'] ?? false;
    final quantity = foodItem['quantityAvailable'] ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFoodImage(),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              foodItem['name'] ?? 'Unknown Food',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusIndicator(isAvailable, quantity),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      if (foodItem['description'] != null && foodItem['description'].isNotEmpty)
                        Text(
                          foodItem['description'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Text(
                            'RM${foodItem['discountPrice']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RM${foodItem['originalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey[600],
                              fontSize: 14,
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
                      
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildInfoItem(
                            Icons.timer,
                            timeRemaining,
                          ),
                          _buildInfoItem(
                            Icons.inventory,
                            '$quantity available',
                          ),
                          _buildInfoItem(
                            Icons.category,
                            (foodItem['categories'] as List?)?.join(', ') ?? 'No categories',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                if (onDuplicate != null) ...[
                  OutlinedButton.icon(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Duplicate'),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
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
      child: foodItem['imageBase64'] != null && foodItem['imageBase64'].isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(foodItem['imageBase64']!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.fastfood, color: Colors.grey);
                },
              ),
            )
          : const Icon(Icons.fastfood, color: Colors.grey),
    );
  }

  Widget _buildStatusIndicator(bool isAvailable, int quantity) {
    Color color;
    String text;

    if (!isAvailable) {
      color = Colors.red;
      text = 'Unavailable';
    } else if (quantity == 0) {
      color = Colors.red;
      text = 'Sold Out';
    } else if (quantity <= 3) {
      color = Colors.orange;
      text = 'Low Stock';
    } else {
      color = Colors.green;
      text = 'Available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
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