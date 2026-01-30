import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/utils/helpers.dart';
import 'package:fyp_savr/features/customer/pages/customer_order_detail_Page.dart';

class CustomerOrderHistoryPage extends StatelessWidget {

  final String? orderId;
  const CustomerOrderHistoryPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order History')),
        body: const Center(child: Text('Please login to view orders')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.orders
            .where('customerId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyOrders();
          }

          final orders = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return CustomerOrderCard(orderDoc: order);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Orders Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your orders will appear here',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class CustomerOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot orderDoc;

  const CustomerOrderCard({super.key, required this.orderDoc});

  @override
  Widget build(BuildContext context) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final orderId = order['orderId'] ?? '';
    final restaurantName = order['restaurantName'] ?? 'Restaurant';
    final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
    final status = order['status'] ?? 'pending';
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    final Map<String, Color> statusColors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': Colors.purple,
      'ready': Colors.green,
      'completed': Colors.grey,
      'cancelled': Colors.red,
    };

    final Map<String, String> statusLabels = {
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'preparing': 'Preparing',
      'ready': 'Ready for Pickup',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
    };

    final statusColor = statusColors[status] ?? Colors.grey;
    final statusLabel = statusLabels[status] ?? status;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerOrderDetailPage(
                orderDoc: orderDoc,
                statusColors: statusColors,
                statusLabels: statusLabels,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restaurantName,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // order items summary
              if (items.isNotEmpty)
                Text(
                  '${items.length} item${items.length > 1 ? 's' : ''} • ${items.first['foodName']}${items.length > 1 ? ' + more' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Helpers.formatDate(createdAt),
                        style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        Helpers.formatTime(createdAt),
                        style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RM${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap for details →',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}