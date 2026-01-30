import 'dart:math';

class MLService {
  static final Map<String, List<String>> _categoryKeywords = {
    'sushi': ['sushi', 'maki', 'roll', 'sashimi', 'nigiri', 'japanese', 'tempura', 'ramen'],
    'pizza': ['pizza', 'pasta', 'italian', 'calzone', 'marinara', 'mozzarella', 'pepperoni'],
    'burger': ['burger', 'beef', 'cheeseburger', 'patty', 'bun', 'fries', 'fast food'],
    'asian': ['rice', 'noodle', 'curry', 'thai', 'chinese', 'vietnamese', 'stir fry', 'wok'],
    'dessert': ['cake', 'ice cream', 'chocolate', 'sweet', 'pastry', 'cookie', 'brownie', 'pie'],
    'mexican': ['taco', 'burrito', 'mexican', 'salsa', 'guacamole', 'quesadilla'],
    'healthy': ['salad', 'bowl', 'vegan', 'vegetarian', 'gluten free', 'organic', 'smoothie'],
    'seafood': ['fish', 'salmon', 'prawn', 'shrimp', 'crab', 'lobster', 'seafood'],
    'breakfast': ['breakfast', 'pancake', 'waffle', 'egg', 'bacon', 'toast', 'coffee'],
    'beverages': ['drink', 'juice', 'soda', 'tea', 'coffee', 'bubble tea', 'smoothie'],
  };

  static Future<List<String>> predictCategories({
    required String foodName,
    String description = '',
  }) async {
    final text = '${foodName.toLowerCase()} ${description.toLowerCase()}';
    
    final Map<String, double> categoryScores = {};
    
    for (final category in _categoryKeywords.keys) {
      double score = 0.0;
      
      for (final keyword in _categoryKeywords[category]!) {
        if (text.contains(keyword)) {
          score += 1.0;
          if (foodName.toLowerCase().contains(keyword)) {
            score += 2.0;
          }
        }
      }
      
      if (score > 0) {
        categoryScores[category] = score;
      }
    }
    
    // sort by score and return top 3 categories
    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // return top 3 categories or all if less than 3
    final predictedCategories = sortedCategories
        .take(3)
        .map((entry) => entry.key)
        .toList();
    
    // if no categories predicted, return default
    if (predictedCategories.isEmpty) {
      return ['all'];
    }
    
    return predictedCategories;
  }

  static Future<Map<String, double>> getPredictionConfidence({
    required String foodName,
    String description = '',
  }) async {
    final text = '${foodName.toLowerCase()} ${description.toLowerCase()}';
    final Map<String, double> confidenceScores = {};
    
    for (final category in _categoryKeywords.keys) {
      double score = 0.0;
      int matches = 0;
      
      for (final keyword in _categoryKeywords[category]!) {
        if (text.contains(keyword)) {
          matches++;
          score += 1.0;
          if (foodName.toLowerCase().contains(keyword)) {
            score += 2.0;
          }
        }
      }
      
      if (matches > 0) {
        final maxPossibleScore = (_categoryKeywords[category]!.length * 3).toDouble();
        confidenceScores[category] = min(score / maxPossibleScore, 1.0);
      }
    }
    
    return confidenceScores;
  }
}