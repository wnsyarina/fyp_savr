import 'dart:math';

class DynamicPricingService {
  static double calculateSuggestedDiscount({
    required DateTime expiryTime,
    required double originalPrice,
    double baseDiscount = 10.0,
    double maxDiscount = 70.0,
  }) {
    final now = DateTime.now();
    final hoursUntilExpiry = expiryTime.difference(now).inHours;

    double discountPercentage;

    if (hoursUntilExpiry <= 1) {
      discountPercentage = maxDiscount;
    } else if (hoursUntilExpiry <= 3) {
      discountPercentage = 50.0;
    } else if (hoursUntilExpiry <= 6) {
      discountPercentage = 30.0;
    } else if (hoursUntilExpiry <= 12) {
      discountPercentage = 20.0;
    } else {
      discountPercentage = baseDiscount;
    }

    return originalPrice * (1 - discountPercentage / 100);
  }

  static Map<String, dynamic> getPricingSuggestions({
    required double originalPrice,
    required DateTime expiryTime,
    required int quantity,
  }) {
    final now = DateTime.now();
    final hoursLeft = expiryTime.difference(now).inHours;

    final aggressivePrice = calculateSuggestedDiscount(
      expiryTime: expiryTime,
      originalPrice: originalPrice,
      baseDiscount: 15.0,
      maxDiscount: 70.0,
    );

    final moderatePrice = calculateSuggestedDiscount(
      expiryTime: expiryTime,
      originalPrice: originalPrice,
      baseDiscount: 10.0,
      maxDiscount: 50.0,
    );

    final conservativePrice = calculateSuggestedDiscount(
      expiryTime: expiryTime,
      originalPrice: originalPrice,
      baseDiscount: 5.0,
      maxDiscount: 30.0,
    );

    final salesProbability = _calculateSalesProbability(
      hoursLeft: hoursLeft,
      discountPercentage: ((originalPrice - moderatePrice) / originalPrice * 100),
      quantity: quantity,
    );

    return {
      'aggressive': {
        'price': aggressivePrice,
        'discountPercentage': ((originalPrice - aggressivePrice) / originalPrice * 100).round(),
        'description': 'Quick Sale (High Discount)',
        'recommendedFor': hoursLeft <= 3 ? 'Highly Recommended' : 'Optional',
      },
      'moderate': {
        'price': moderatePrice,
        'discountPercentage': ((originalPrice - moderatePrice) / originalPrice * 100).round(),
        'description': 'Balanced Approach',
        'recommendedFor': 'Recommended',
      },
      'conservative': {
        'price': conservativePrice,
        'discountPercentage': ((originalPrice - conservativePrice) / originalPrice * 100).round(),
        'description': 'Maximum Profit',
        'recommendedFor': hoursLeft > 12 ? 'Recommended' : 'Not Recommended',
      },
      'salesProbability': salesProbability,
      'hoursUntilExpiry': hoursLeft,
      'timeBasedSuggestion': _getTimeBasedSuggestion(hoursLeft),
    };
  }

  static double _calculateSalesProbability({
    required int hoursLeft,
    required double discountPercentage,
    required int quantity,
  }) {
    double probability = 0.0;

    if (hoursLeft <= 1) probability += 40.0;
    else if (hoursLeft <= 3) probability += 30.0;
    else if (hoursLeft <= 6) probability += 20.0;

    if (discountPercentage >= 50) probability += 30.0;
    else if (discountPercentage >= 30) probability += 20.0;
    else if (discountPercentage >= 15) probability += 10.0;

    if (quantity <= 3) probability += 10.0;
    else if (quantity <= 10) probability += 5.0;

    return min(probability, 95.0);
  }

  static String _getTimeBasedSuggestion(int hoursLeft) {
    if (hoursLeft <= 1) {
      return 'Urgent: Consider higher discount for quick sale';
    } else if (hoursLeft <= 3) {
      return 'Time-sensitive: Moderate discount recommended';
    } else if (hoursLeft <= 6) {
      return 'Good timing: Standard discount works well';
    } else {
      return 'Plenty of time: Can use smaller discount';
    }
  }
}