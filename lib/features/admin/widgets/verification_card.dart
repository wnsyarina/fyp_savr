import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VerificationCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final String restaurantId;
  final VoidCallback onTap;
  final Color? statusColor;

  const VerificationCard({
    super.key,
    required this.restaurant,
    required this.restaurantId,
    required this.onTap,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final status = restaurant['verificationStatus'] ?? 'pending';
    final appliedDate = restaurant['createdAt'] != null 
        ? _formatDate(restaurant['createdAt'])
        : 'Unknown';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.deepOrange[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: restaurant['logoBase64'] != null && restaurant['logoBase64'].isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(restaurant['logoBase64']!),
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.restaurant, color: Colors.deepOrange),
        ),
        title: Text(
          restaurant['name'] ?? 'Unknown Restaurant',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(restaurant['address'] ?? 'No address'),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip(status),
                const SizedBox(width: 8),
                Text(
                  'Applied: $appliedDate',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (restaurant['adminNotes'] != null && restaurant['adminNotes'].isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Note: ${restaurant['adminNotes']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: status == 'pending'
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : const Icon(Icons.verified, color: Colors.green),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'APPROVED';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'REJECTED';
        break;
      default:
        color = Colors.orange;
        text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'Unknown';
  }
}