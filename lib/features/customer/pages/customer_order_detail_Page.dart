import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:fyp_savr/utils/helpers.dart';
import 'package:fyp_savr/data/services/rating_service.dart';
import 'package:fyp_savr/utils/rating_utils.dart';
import 'package:fyp_savr/data/services/order_service.dart';
import '../../../data/services/notification_service.dart';

class CustomerOrderDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot orderDoc;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;

  const CustomerOrderDetailPage({
    super.key,
    required this.orderDoc,
    required this.statusColors,
    required this.statusLabels,
  });

  @override
  State<CustomerOrderDetailPage> createState() =>
      _CustomerOrderDetailPageState();
}

class _CustomerOrderDetailPageState extends State<CustomerOrderDetailPage> {
  late Map<String, dynamic> order;
  late String currentStatus;
  late String restaurantId;
  late bool _hasRated = false;
  late bool _isRating = false;
  int? _selectedRating;

  StreamSubscription? _orderStatusSubscription;

  @override
  void initState() {
    super.initState();
    order = widget.orderDoc.data() as Map<String, dynamic>;
    currentStatus = order['status'] ?? 'pending';
    restaurantId = order['restaurantId'] ?? '';
    _checkIfRated();
    _listenForStatusChanges();
  }

  void _listenForStatusChanges() {
    _orderStatusSubscription = FirebaseService.orders
        .doc(widget.orderDoc.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final newData = snapshot.data() as Map<String, dynamic>;
        final newStatus = newData['status'] ?? 'pending';

        if (newStatus != currentStatus && mounted) {
          setState(() {
            currentStatus = newStatus;
          });

          NotificationService.showInAppNotification(
            context: context,
            title: 'Order Status Updated',
            body: 'Order #${widget.orderDoc.id.substring(0, 8)} is now ${newStatus.replaceFirst(newStatus[0], newStatus[0].toUpperCase())}',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _orderStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkIfRated() async {
    final user = FirebaseService.auth.currentUser;
    if (user != null) {
      final hasRated = await RatingService.hasUserRatedOrder(
        widget.orderDoc.id,
        user.uid,
      );

      if (hasRated) {
        final ratingData = await RatingService.getUserRatingForOrder(
          widget.orderDoc.id,
          user.uid,
        );

        setState(() {
          _hasRated = hasRated;
          _selectedRating = ratingData?['rating'] as int?;
        });
      } else {
        setState(() {
          _hasRated = false;
        });
      }
    }
  }

  Future<void> _submitRating(int rating) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null || _hasRated || _isRating) return;

    setState(() {
      _isRating = true;
      _selectedRating = rating;
    });

    try {
      await RatingService.submitOrderRating(
        orderId: widget.orderDoc.id,
        restaurantId: restaurantId,
        userId: user.uid,
        userName: user.displayName ?? order['customerName'] ?? 'Customer',
        rating: rating,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your rating!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _hasRated = true;
        _isRating = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting rating: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isRating = false;
        _selectedRating = null;
      });
    }
  }

  Future<void> _openGoogleMapsNavigation() async {
    try {
      final restaurantDoc =
      await FirebaseService.restaurants.doc(restaurantId).get();
      if (!restaurantDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restaurant location not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final restaurantData = restaurantDoc.data() as Map<String, dynamic>;
      final location = restaurantData['location'];
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restaurant location not available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final double latitude = location.latitude;
      final double longitude = location.longitude;
      final restaurantName = restaurantData['name'] ?? 'Restaurant';
      final address = restaurantData['address'] ?? '';

      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
      } catch (e) {
        print('Error getting current position: $e');
      }

      String url;
      if (currentPosition != null) {
        url =
        'https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=$latitude,$longitude&destination_place_id=${Uri.encodeComponent(restaurantName)}&travelmode=driving';
      } else {
        url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude&query_place_id=${Uri.encodeComponent(restaurantName)}';
      }

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening maps: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final specialInstructions = order['specialInstructions'] ?? '';
    final restaurantName = order['restaurantName'] ?? 'Restaurant';
    final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
    final pickupTime = (order['pickupTime'] as Timestamp?)?.toDate();

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order['orderId']?.toString().substring(0, 8) ?? ''}'),
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
                      'ORDER STATUS',
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
                    _buildStatusProgressBar(),
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
                      'RESTAURANT',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      restaurantName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (currentStatus == 'ready')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openGoogleMapsNavigation,
                          icon: const Icon(Icons.directions),
                          label: const Text('Navigate to Restaurant'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (currentStatus == 'ready')
                      const SizedBox(height: 8),
                    if (currentStatus == 'ready')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _confirmPickup,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Confirm Pickup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
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
                    _buildInfoRow('Order ID', order['orderId'] ?? ''),
                    _buildInfoRow('Ordered', '${Helpers.formatTime(createdAt)} • ${Helpers.formatDate(createdAt)}'),
                    if (pickupTime != null)
                      _buildInfoRow(
                        'Pickup Time',
                        '${Helpers.formatTime(pickupTime)} • ${Helpers.formatDate(pickupTime)}',
                      ),
                    _buildInfoRow('Payment Method', order['paymentMethod'] ?? 'Not specified'),
                    _buildInfoRow('Payment Status', order['paymentStatus'] ?? 'Unknown'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (currentStatus == 'completed') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'RATE YOUR EXPERIENCE',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_hasRated)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check, size: 12, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rated',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (!_hasRated)
                        Column(
                          children: [
                            const Text(
                              'How was your experience?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RatingUtils.buildClickableStarRating(
                              selectedRating: _selectedRating ?? 0,
                              onRatingChanged: _submitRating,
                              size: 40,
                            ),
                            if (_isRating)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: CircularProgressIndicator(),
                              ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap a star to rate',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 48,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You rated this order ${_selectedRating ?? 0} star${(_selectedRating ?? 0) == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Thank you for your feedback!',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusProgressBar() {
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
        if (currentStatus == 'ready')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Ready for pickup! Please confirm when you pick up.',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (currentStatus == 'picked_up_by_customer')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pickup confirmed! Waiting for merchant verification.',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
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

  Future<void> _confirmPickup() async {
    try {
      final user = FirebaseService.auth.currentUser;
      if (user == null) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Pickup'),
          content: const Text('Have you picked up your order? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Confirming pickup...'),
                    duration: Duration(seconds: 2),
                  ),
                );

                await OrderService.updateOrderStatus(
                  orderId: widget.orderDoc.id,
                  status: 'picked_up_by_customer',
                  oldStatus: currentStatus,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pickup confirmed! Merchant will now verify.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Yes, I Picked Up', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming pickup: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}