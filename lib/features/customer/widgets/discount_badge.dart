import 'package:flutter/material.dart';

class DiscountBadge extends StatelessWidget {
  final int discountPercentage;
  final double size;
  final bool showText;

  const DiscountBadge({
    super.key,
    required this.discountPercentage,
    this.size = 60,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _getDiscountColor(discountPercentage),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getDiscountColor(discountPercentage).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        
        // Discount text
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$discountPercentage%',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (showText)
              Text(
                'OFF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _getDiscountColor(int percentage) {
    if (percentage >= 50) return Colors.red;
    if (percentage >= 30) return Colors.orange;
    return Colors.green;
  }
}