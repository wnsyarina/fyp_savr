class CartItem {
  final String foodId;
  final String foodName;
  final String restaurantId;
  final String restaurantName;
  final double price;
  final int quantity;
  final String? imageBase64;

  CartItem({
    required this.foodId,
    required this.foodName,
    required this.restaurantId,
    required this.restaurantName,
    required this.price,
    required this.quantity,
    this.imageBase64,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      foodId: map['foodId'] ?? '',
      foodName: map['foodName'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 0,
      imageBase64: map['imageBase64'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'foodId': foodId,
      'foodName': foodName,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'price': price,
      'quantity': quantity,
      'imageBase64': imageBase64,
    };
  }

  double get totalPrice => price * quantity;

  CartItem copyWith({
    String? foodId,
    String? foodName,
    String? restaurantId,
    String? restaurantName,
    double? price,
    int? quantity,
    String? imageBase64,
  }) {
    return CartItem(
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }

  @override
  String toString() {
    return 'CartItem{foodId: $foodId, foodName: $foodName, quantity: $quantity, price: $price}';
  }
}