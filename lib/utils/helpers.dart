import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class Helpers {
  static String formatCurrency(double amount) {
    return 'RM${amount.toStringAsFixed(2)}';
  }
  

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
  
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM').format(date);
  }
  
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
  
  static String formatDateTimeForAnalytics(DateTime date) {
    return DateFormat('MMM dd').format(date);
  }
  
  static String getTimeRemaining(DateTime endTime) {
    final now = DateTime.now();
    final difference = endTime.difference(now);
    
    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Less than a minute';
    }
  }
  
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }
  
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()} m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }
  
  static String formatLargeNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
  
  static String formatPercentage(double value, double total) {
    if (total == 0) return '0%';
    final percentage = (value / total * 100);
    return '${percentage.toStringAsFixed(1)}%';
  }
  
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }
  
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^[0-9]{10,11}$');
    return phoneRegex.hasMatch(phone);
  }
  
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  static String truncateWithEllipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  static List<Color> getChartColors() {
    return [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];
  }
  
  static Color getColorForIndex(int index) {
    final colors = getChartColors();
    return colors[index % colors.length];
  }
  
  static Color getColorForCategory(String category) {
    final colors = getChartColors();
    final index = category.hashCode % colors.length;
    return colors[index];
  }
  
  static Map<String, DateTime> getTimePeriodDates(int days) {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }
  
  static List<String> getLastNDays(int days) {
    final List<String> dates = [];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      dates.add(formatDateShort(date));
    }
    return dates;
  }
  
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
  
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }
  
  static String getRatingDescription(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.5) return 'Good';
    if (rating >= 3.0) return 'Average';
    if (rating >= 2.0) return 'Poor';
    return 'Very Poor';
  }
  
  static int calculateDiscountPercentage(double originalPrice, double discountPrice) {
    if (originalPrice <= 0) return 0;
    return ((originalPrice - discountPrice) / originalPrice * 100).round();
  }
  
  static String formatDiscountPercentage(double originalPrice, double discountPrice) {
    final percentage = calculateDiscountPercentage(originalPrice, discountPrice);
    return '$percentage% OFF';
  }
}