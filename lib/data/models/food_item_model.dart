import 'package:cloud_firestore/cloud_firestore.dart';

class FoodItem {
  final String id;
  final String name;
  final String restaurantId;
  final String restaurantName;
  final String description;
  final double originalPrice;
  final double discountPrice;
  final int quantityAvailable;
  final DateTime pickupStart;
  final DateTime pickupEnd;
  final String? imageBase64;
  final List<String> categories;
  final bool isActive;
  final DateTime createdAt;
  final bool aiSuggestedCategories;

  FoodItem({
    required this.id,
    required this.name,
    required this.restaurantId,
    required this.restaurantName,
    required this.description,
    required this.originalPrice,
    required this.discountPrice,
    required this.quantityAvailable,
    required this.pickupStart,
    required this.pickupEnd,
    this.imageBase64,
    required this.categories,
    required this.isActive,
    required this.createdAt,
    this.aiSuggestedCategories = false,
  });

  factory FoodItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodItem(
      id: doc.id,
      name: data['name'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      description: data['description'] ?? '',
      originalPrice: (data['originalPrice'] ?? 0).toDouble(),
      discountPrice: (data['discountPrice'] ?? 0).toDouble(),
      quantityAvailable: data['quantityAvailable'] ?? 0,
      pickupStart: (data['pickupStart'] as Timestamp).toDate(),
      pickupEnd: (data['pickupEnd'] as Timestamp).toDate(),
      imageBase64: data['imageBase64'],
      categories: List<String>.from(data['categories'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      aiSuggestedCategories: data['aiSuggestedCategories'] ?? false,
    );
  }

  double get discountPercentage =>
      ((originalPrice - discountPrice) / originalPrice * 100).roundToDouble();

  bool get isExpired => DateTime.now().isAfter(pickupEnd);
  bool get isAvailable => isActive && !isExpired && quantityAvailable > 0;
}