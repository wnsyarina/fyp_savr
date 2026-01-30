import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final VoidCallback? onEditRole;

  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
    this.onEditRole,
  });

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? 'customer';
    final joinDate = user['createdAt'] != null 
        ? _formatDate(user['createdAt'])
        : 'Unknown';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role),
          child: Text(
            user['name']?[0].toUpperCase() ?? 'U',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user['name'] ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? 'No email'),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildRoleChip(role),
                const SizedBox(width: 8),
                Text(
                  'Joined: $joinDate',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: onEditRole != null
            ? IconButton(
                icon: const Icon(Icons.edit, color: Colors.deepOrange),
                onPressed: onEditRole,
                tooltip: 'Edit Role',
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final color = _getRoleColor(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'merchant':
        return Colors.green;
      case 'customer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'Unknown';
  }
}