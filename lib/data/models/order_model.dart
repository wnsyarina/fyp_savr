import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderItem {
  final String foodId;
  final String foodName;
  final int quantity;
  final double price;
  final String? imageBase64;

  OrderItem({
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.price,
    this.imageBase64,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      foodId: map['foodId'] ?? '',
      foodName: map['foodName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      imageBase64: map['imageBase64'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'foodId': foodId,
      'foodName': foodName,
      'quantity': quantity,
      'price': price,
      'imageBase64': imageBase64,
    };
  }

  double get totalPrice => price * quantity;

  OrderItem copyWith({
    String? foodId,
    String? foodName,
    int? quantity,
    double? price,
    String? imageBase64,
  }) {
    return OrderItem(
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String restaurantId;
  final String restaurantName;
  final List<OrderItem> items;
  final double totalAmount;
  final String status;
  final DateTime orderDate;
  final DateTime pickupTime;
  final String? specialInstructions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? orderNumber;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    required this.pickupTime,
    this.specialInstructions,
    required this.createdAt,
    required this.updatedAt,
    this.paymentMethod,
    this.paymentStatus,
    this.orderNumber,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<OrderItem> items = [];
    if (data['items'] != null) {
      items = List<Map<String, dynamic>>.from(data['items'])
          .map((itemMap) => OrderItem.fromMap(itemMap))
          .toList();
    }

    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerEmail: data['customerEmail'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      items: items,
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'pending',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      pickupTime: (data['pickupTime'] as Timestamp).toDate(),
      specialInstructions: data['specialInstructions'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      paymentMethod: data['paymentMethod'],
      paymentStatus: data['paymentStatus'],
      orderNumber: data['orderNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'orderDate': orderDate,
      'pickupTime': pickupTime,
      'specialInstructions': specialInstructions,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'orderNumber': orderNumber,
    };
  }

  // helper methods
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isReady => status == 'ready';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  String get formattedTotalAmount => 'RM${totalAmount.toStringAsFixed(2)}';

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'ready':
        return 'Ready for Pickup';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool get canBeCancelled => isPending || isConfirmed;

  bool get isActive => !isCompleted && !isCancelled;

  String get estimatedPreparationTime {
    if (isReady || isCompleted) return 'Ready';
    if (isConfirmed) return '15-25 min';
    return 'Preparing...';
  }

  OrderModel copyWith({
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? restaurantId,
    String? restaurantName,
    List<OrderItem>? items,
    double? totalAmount,
    String? status,
    DateTime? orderDate,
    DateTime? pickupTime,
    String? specialInstructions,
    DateTime? updatedAt,
    String? paymentMethod,
    String? paymentStatus,
  }) {
    return OrderModel(
      id: id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      pickupTime: pickupTime ?? this.pickupTime,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderNumber: orderNumber,
    );
  }

  @override
  String toString() {
    return 'OrderModel{id: $id, restaurant: $restaurantName, total: $totalAmount, status: $status}';
  }
}