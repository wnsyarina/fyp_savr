import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _getCategoryColor(category);
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: isSelected ? Colors.white : chipColor),
            const SizedBox(width: 4),
          ],
          Text(
            _capitalize(category),
            style: TextStyle(
              color: isSelected ? Colors.white : chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      checkmarkColor: Colors.white,
      selectedColor: chipColor,
      backgroundColor: chipColor.withOpacity(0.1),
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? chipColor : chipColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'sushi':
        return Colors.blue;
      case 'pizza':
        return Colors.red;
      case 'burger':
        return Colors.orange;
      case 'asian':
        return Colors.green;
      case 'dessert':
        return Colors.pink;
      case 'healthy':
        return Colors.purple;
      case 'mexican':
        return Colors.brown;
      case 'seafood':
        return Colors.cyan;
      case 'breakfast':
        return Colors.amber;
      case 'beverages':
        return Colors.teal;
      default:
        return Colors.deepOrange;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}