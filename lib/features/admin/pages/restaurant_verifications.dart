import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/features/admin/pages/verification_detail_page.dart';

class RestaurantVerificationsPage extends StatelessWidget {
  const RestaurantVerificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verification Status'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.pending),
                text: 'Pending',
              ),
              Tab(
                icon: Icon(Icons.verified),
                text: 'Approved',
              ),
              Tab(
                icon: Icon(Icons.cancel),
                text: 'Rejected',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _VerificationList(status: 'pending'),
            _VerificationList(status: 'approved'),
            _VerificationList(status: 'rejected'),
          ],
        ),
      ),
    );
  }
}

class _VerificationList extends StatelessWidget {
  final String status;

  const _VerificationList({required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: status == 'pending'
          ? FirebaseService.getPendingMerchantApplications()
          : FirebaseService.restaurants.where('verificationStatus', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final restaurants = snapshot.data!.docs;

        if (restaurants.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: restaurants.length,
          itemBuilder: (context, index) {
            final restaurantDoc = restaurants[index];
            final restaurant = restaurantDoc.data() as Map<String, dynamic>;
            return _RestaurantVerificationCard(
              restaurant: restaurant,
              restaurantId: restaurantDoc.id,
              status: status,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String title;
    String subtitle;
    Color color;

    switch (status) {
      case 'pending':
        icon = Icons.checklist_rtl_outlined;
        title = 'No Pending Verifications';
        subtitle = 'All restaurant applications have been reviewed';
        color = Colors.orange;
        break;
      case 'approved':
        icon = Icons.verified_outlined;
        title = 'No Approved Restaurants';
        subtitle = 'No restaurants have been approved yet';
        color = Colors.green;
        break;
      case 'rejected':
        icon = Icons.cancel_outlined;
        title = 'No Rejected Applications';
        subtitle = 'All applications have been approved';
        color = Colors.red;
        break;
      default:
        icon = Icons.restaurant_outlined;
        title = 'No Restaurants Found';
        subtitle = 'There are no restaurants in this category';
        color = Colors.grey;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: color.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _RestaurantVerificationCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final String restaurantId;
  final String status;

  const _RestaurantVerificationCard({
    required this.restaurant,
    required this.restaurantId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final documents = restaurant['documents'] as Map<String, dynamic>? ?? {};
    final documentUrls = documents['documents'] as Map<String, dynamic>? ?? {};
    final restaurantPhoto = documentUrls['restaurantPhoto'] as String?;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: restaurantPhoto != null
            ? CircleAvatar(
          backgroundImage: NetworkImage(restaurantPhoto),
          radius: 25,
          onBackgroundImageError: (exception, stackTrace) {
          },
        )
            : const CircleAvatar(
          radius: 25,
          child: Icon(Icons.restaurant),
        ),
        title: Text(
          restaurant['name'] ?? 'Unnamed Restaurant',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(restaurant['phone'] ?? 'No phone'),
            Text(restaurant['address'] ?? 'No address'),
            const SizedBox(height: 4),
            _buildStatusChip(status),
            if (restaurant['cuisineTypes'] != null)
              Text(
                'Cuisine: ${(restaurant['cuisineTypes'] as List).join(', ')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (restaurant['adminNotes'] != null && (restaurant['adminNotes'] as String).isNotEmpty)
              Text(
                'Notes: ${restaurant['adminNotes']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (restaurant['verifiedByName'] != null)
              Text(
                'By: ${restaurant['verifiedByName']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            if (restaurant['createdAt'] != null)
              Text(
                'Applied: ${_formatDate(restaurant['createdAt'])}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
        trailing: status == 'pending'
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationDetailPage(
                restaurantId: restaurantId,
                restaurantData: restaurant,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'APPROVED';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'REJECTED';
        break;
      case 'pending':
      default:
        color = Colors.orange;
        label = 'PENDING REVIEW';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'Unknown date';
  }
}