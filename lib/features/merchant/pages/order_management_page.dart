import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_savr/utils/helpers.dart';
import '../../../data/services/order_service.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({super.key});

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String _selectedFilter = 'all';

  final Map<String, String> _statusLabels = {
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'preparing': 'Preparing',
    'ready': 'Ready for Pickup',
    'picked_up_by_customer': 'Customer Confirmed Pickup',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'confirmed': Colors.blue,
    'preparing': Colors.purple,
    'ready': Colors.green,
    'picked_up_by_customer': Colors.blue,
    'completed': Colors.grey,
    'cancelled': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Orders')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'preparing', child: Text('Preparing')),
              const PopupMenuItem(value: 'ready', child: Text('Ready')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
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
              return _buildOrderCard(order);
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    Query query = FirebaseService.orders
        .where('restaurantId', isEqualTo: _currentUser!.uid)
        .orderBy('createdAt', descending: true);

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildOrderCard(QueryDocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final orderId = order['orderId'] ?? '';
    final customerName = order['customerName'] ?? 'Customer';
    final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
    final status = order['status'] ?? 'pending';
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailPage(
                orderDoc: orderDoc,
                statusColors: _statusColors,
                statusLabels: _statusLabels,
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
                          'Customer: $customerName',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColors[status]?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _statusColors[status] ?? Colors.grey,
                      ),
                    ),
                    child: Text(
                      _statusLabels[status] ?? status,
                      style: TextStyle(
                        color: _statusColors[status] ?? Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        Helpers.formatTime(createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total: RM${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to view details →',
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Orders from customers will appear here',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot orderDoc;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;

  const OrderDetailPage({
    super.key,
    required this.orderDoc,
    required this.statusColors,
    required this.statusLabels,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Map<String, dynamic> order;
  late String orderId;
  late String currentStatus;

  @override
  void initState() {
    super.initState();
    order = widget.orderDoc.data() as Map<String, dynamic>;
    orderId = order['orderId'] ?? '';
    currentStatus = order['status'] ?? 'pending';
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      final oldStatus = currentStatus;

      final String actualOrderId = order['orderId'] ?? widget.orderDoc.id;

      await OrderService.updateOrderStatus(
        orderId: actualOrderId,
        status: newStatus,
        oldStatus: oldStatus,
      );

      setState(() {
        currentStatus = newStatus;
        order['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${widget.statusLabels[newStatus]}'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error updating order status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> _getAvailableNextStatuses() {
    final statusFlow = ['pending', 'confirmed', 'preparing', 'ready', 'picked_up_by_customer', 'completed'];
    const cancelAlwaysAvailable = 'cancelled';

    final currentIndex = statusFlow.indexOf(currentStatus);
    final List<String> nextStatuses = [];

    if (currentStatus == 'picked_up_by_customer') {
      nextStatuses.add('completed');
    }
    else if (currentIndex < statusFlow.length - 1) {
      nextStatuses.add(statusFlow[currentIndex + 1]);
    }

    if (currentStatus != 'completed' && currentStatus != 'cancelled') {
      nextStatuses.add(cancelAlwaysAvailable);
    }

    return nextStatuses;
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final specialInstructions = order['specialInstructions'] ?? '';
    final customerName = order['customerName'] ?? 'Customer';
    final customerEmail = order['customerEmail'] ?? 'No email';
    final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
    final pickupTime = (order['pickupTime'] as Timestamp?)?.toDate();
    final nextStatuses = _getAvailableNextStatuses();

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${orderId.substring(0, 8)}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: widget.statusColors[currentStatus]?.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'CURRENT STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.statusLabels[currentStatus] ?? currentStatus,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.statusColors[currentStatus],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusProgress(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CUSTOMER INFORMATION',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Name', customerName),
                    _buildInfoRow('Email', customerEmail),
                    if (pickupTime != null)
                      _buildInfoRow(
                        'Pickup Time',
                        '${Helpers.formatTime(pickupTime)} • ${Helpers.formatDate(pickupTime)}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDER ITEMS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...items.map((item) => _buildOrderItem(item)).toList(),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'RM${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (specialInstructions.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SPECIAL INSTRUCTIONS',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        specialInstructions,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDER DETAILS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Order ID', orderId),
                    _buildInfoRow('Created', '${Helpers.formatTime(createdAt)} • ${Helpers.formatDate(createdAt)}'),
                    _buildInfoRow('Payment Method', order['paymentMethod'] ?? 'Not specified'),
                    _buildInfoRow('Payment Status', order['paymentStatus'] ?? 'Unknown'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (nextStatuses.isNotEmpty) ...[
              Text(
                'UPDATE ORDER STATUS',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: nextStatuses.map((status) {
                  return ElevatedButton(
                    onPressed: () => _showStatusConfirmationDialog(status),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.statusColors[status] ?? Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'Mark as ${widget.statusLabels[status]}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusProgress() {
    final statusFlow = ['pending', 'confirmed', 'preparing', 'ready', 'picked_up_by_customer', 'completed'];
    final currentIndex = statusFlow.indexOf(currentStatus);

    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < statusFlow.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= currentIndex
                            ? widget.statusColors[statusFlow[i]] ?? Colors.grey
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusLabel(statusFlow[i]),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: i <= currentIndex
                            ? widget.statusColors[statusFlow[i]] ?? Colors.grey
                            : Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${currentIndex + 1} of ${statusFlow.length}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        if (order['pickupConfirmedByCustomer'] == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Customer confirmed pickup',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 0;
    final foodName = item['foodName'] ?? 'Unknown Item';
    final price = (item['price'] ?? 0.0).toDouble();
    final total = price * quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                quantity.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foodName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'RM${price.toStringAsFixed(2)} each',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            'RM${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'picked_up_by_customer':
        return 'Customer Confirmed';
      default:
        return widget.statusLabels[status] ?? status;
    }
  }


  Future<void> _showStatusConfirmationDialog(String newStatus) async {
    final isCancelling = newStatus == 'cancelled';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCancelling ? 'Cancel Order?' : 'Update Order Status',
          style: TextStyle(
            color: isCancelling ? Colors.red : Colors.blue,
          ),
        ),
        content: Text(
          isCancelling
              ? 'Are you sure you want to cancel this order? This action cannot be undone and the customer will be notified.'
              : 'Update order status to "${widget.statusLabels[newStatus]}"? The customer will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(newStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCancelling ? Colors.red : Colors.blue,
            ),
            child: Text(
              isCancelling ? 'Cancel Order' : 'Confirm Update',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}