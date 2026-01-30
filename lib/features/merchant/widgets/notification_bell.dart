import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/notification_service.dart';
import '../../../data/services/firebase_service.dart';
import '../../customer/pages/customer_order_detail_Page.dart';
import '../pages/order_management_page.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  void _subscribeToNotifications() {
    final user = FirebaseService.auth.currentUser;
    if (user != null) {
      _notificationSubscription = NotificationService
          .getUnreadCount(user.uid)
          .listen((count) {
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsPage(),
              ),
            );
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              if (user != null) {
                NotificationService.markAllAsRead(user.uid);
              }
            },
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please login to view notifications'))
          : StreamBuilder<QuerySnapshot>(
        stream: NotificationService.getUserNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;

              return ListTile(
                leading: _getNotificationIcon(data['type']),
                title: Text(data['title'] ?? ''),
                subtitle: Text(data['body'] ?? ''),
                trailing: data['isRead'] == false
                    ? Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                )
                    : null,
                onTap: () {
                  NotificationService.markAsRead(user.uid, doc.id);

                  _handleNotificationTap(context, data);
                },
              );
            },
          );
        },
      ),
    );
  }

  Icon _getNotificationIcon(String type) {
    switch (type) {
      case 'new_order':
        return const Icon(Icons.shopping_cart, color: Colors.green);
      case 'order_status_update':
        return const Icon(Icons.update, color: Colors.blue);
      case 'payment_received':
        return const Icon(Icons.attach_money, color: Colors.green);
      case 'low_stock':
        return const Icon(Icons.warning, color: Colors.orange);
      default:
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'];
    final notificationData = data['data'] as Map<String, dynamic>?;

    switch (type) {
      case 'new_order':
      case 'order_status_update':
      case 'payment_received':
        final orderId = notificationData?['orderId'];
        if (orderId != null) {
          _navigateToOrderDetail(context, orderId, notificationData);
        }
        break;
    }
  }

  Future<void> _navigateToOrderDetail(BuildContext context, String orderId, Map<String, dynamic>? extraData) async {
    try {
      final orderDoc = await FirebaseService.orders.doc(orderId).get();
      if (!orderDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order not found')),
        );
        return;
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final restaurantId = orderData['restaurantId'];
      final currentUserId = FirebaseService.auth.currentUser?.uid;

      if (currentUserId == null) return;

      if (orderData['customerId'] == currentUserId) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerOrderDetailPage(
              orderDoc: orderDoc as QueryDocumentSnapshot,
              statusColors: _getStatusColors(),
              statusLabels: _getStatusLabels(),
            ),
          ),
        );
      } else if (restaurantId == currentUserId) {
        _navigateToMerchantOrderDetail(context, orderDoc as QueryDocumentSnapshot, orderData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You don\'t have permission to view this order')),
        );
      }
    } catch (e) {
      print('Error navigating to order detail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _navigateToMerchantOrderDetail(BuildContext context, QueryDocumentSnapshot orderDoc, Map<String, dynamic> orderData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailPage(
          orderDoc: orderDoc,
          statusColors: _getStatusColors(),
          statusLabels: _getStatusLabels(),
        ),
      ),
    );
  }

  Map<String, Color> _getStatusColors() {
    return {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': Colors.purple,
      'ready': Colors.green,
      'completed': Colors.grey,
      'cancelled': Colors.red,
    };
  }

  Map<String, String> _getStatusLabels() {
    return {
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'preparing': 'Preparing',
      'ready': 'Ready for Pickup',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
    };
  }
}