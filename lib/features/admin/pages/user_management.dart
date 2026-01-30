import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/super_admin_service.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: SuperAdminService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              return UserCard(
                user: user,
                userId: users[index].id,
                onDelete: () => _showDeleteConfirmation(context, users[index].id, user),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context,
      String userId,
      Map<String, dynamic> user,
      ) async {
    final currentUser = FirebaseService.auth.currentUser;

    if (userId == currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${user['name']}'),
            Text('Email: ${user['email']}'),
            const SizedBox(height: 16),
            const Text(
              'This action will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• User account'),
            if (user['role'] == 'merchant') ...[
              const Text('• Restaurant data'),
              const Text('• All associated food items'),
              const Text('• Order history'),
            ],
            const SizedBox(height: 16),
            const Text(
              '⚠This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(context, userId, user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete User'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(
      BuildContext context,
      String userId,
      Map<String, dynamic> user,
      ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting user...'),
          duration: Duration(seconds: 5),
        ),
      );

      await SuperAdminService.deleteUser(userId, user['role']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user['name']} deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String userId;
  final VoidCallback onDelete;

  const UserCard({
    required this.user,
    required this.userId,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user['role']),
          child: Text(
            user['name'][0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email']),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildRoleChip(user['role']),
                if (user['restaurantName'] != null)
                  Chip(
                    label: Text(
                      user['restaurantName'],
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    backgroundColor: Colors.blue[50],
                    labelStyle: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Joined: ${_formatDate(user['createdAt'])}'),
            if (user['lastLogin'] != null)
              Text('Last login: ${_formatDate(user['lastLogin'])}'),
          ],
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Change Role',
                onSelected: (newRole) => _updateUserRole(context, newRole),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'customer',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: Colors.orange, size: 16),
                        SizedBox(width: 6),
                        Text('Customer', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'merchant',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.store, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text('Merchant', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.blue, size: 16),
                        SizedBox(width: 6),
                        Text('Admin', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'super_admin',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.security, color: Colors.purple, size: 16),
                        SizedBox(width: 6),
                        Text('Super Admin', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                tooltip: 'Delete User',
                onPressed: onDelete,
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    Color color = _getRoleColor(role);

    return Chip(
      label: Text(
        role.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Future<void> _updateUserRole(BuildContext context, String newRole) async {
    final currentUser = FirebaseService.auth.currentUser;
    if (userId == currentUser?.uid && newRole != 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot change your own role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await SuperAdminService.updateUserRole(userId, newRole);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated to $newRole'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }
}