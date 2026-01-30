import 'package:flutter/material.dart';

class RatingUtils {
  static Widget buildStarRating(double rating, {double size = 16, Color color = Colors.amber}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, size: size, color: color);
        } else if (index < rating.ceil() && rating % 1 != 0) {
          return Icon(Icons.star_half, size: size, color: color);
        } else {
          return Icon(Icons.star_border, size: size, color: Colors.grey[300]);
        }
      }),
    );
  }

  static Widget buildClickableStarRating({
    required int selectedRating,
    required Function(int) onRatingChanged,
    double size = 40,
    Color selectedColor = Colors.amber,
    Color unselectedColor = Colors.grey,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final rating = index + 1;
        return GestureDetector(
          onTap: () => onRatingChanged(rating),
          child: Icon(
            rating <= selectedRating ? Icons.star : Icons.star_border,
            size: size,
            color: rating <= selectedRating ? selectedColor : unselectedColor,
          ),
        );
      }),
    );
  }

  static String getRatingDescription(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.5) return 'Good';
    if (rating >= 3.0) return 'Average';
    if (rating >= 2.0) return 'Below Average';
    return 'Poor';
  }

  static Color getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.0) return Colors.orange;
    return Colors.red;
  }

  static Widget buildRatingWithText({
    required double rating,
    required int reviewCount,
    double starSize = 16,
    TextStyle? textStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildStarRating(rating, size: starSize),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($reviewCount)',
          style: textStyle ?? const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  static Widget buildCompactRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 12, color: Colors.amber),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}