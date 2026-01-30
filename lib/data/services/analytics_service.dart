import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class AnalyticsService {
  static Future<void> trackAIPrediction({
    required String foodName,
    required Map<String, double> predictedCategories,
    required List<String> finalCategories,
    required String merchantId,
  }) async {
    try {
      await FirebaseService.aiTrainingData.add({
        'foodName': foodName,
        'predictedCategories': predictedCategories.keys.toList(),
        'actualCategories': finalCategories,
        'confidenceScores': predictedCategories,
        'merchantId': merchantId,
        'timestamp': DateTime.now(),
        'wasCorrect': _checkPredictionAccuracy(predictedCategories, finalCategories),
      });

      await _updateMerchantAnalytics(merchantId, predictedCategories, finalCategories);
    } catch (e) {
      print('Analytics tracking error: $e');
    }
  }

  static bool _checkPredictionAccuracy(
      Map<String, double> predicted, List<String> actual) {
    final topPredictions = predicted.entries
        .where((entry) => entry.value > 0.5)
        .map((entry) => entry.key)
        .toList();
    
    return actual.any((category) => topPredictions.contains(category));
  }

  static Future<void> _updateMerchantAnalytics(
      String merchantId,
      Map<String, double> predictedCategories,
      List<String> finalCategories) async {
    final today = DateTime.now();
    final docId = '${merchantId}_${today.year}-${today.month}-${today.day}';
    
    final doc = await FirebaseService.merchantAnalytics.doc(docId).get();
    
    if (doc.exists) {
      await FirebaseService.merchantAnalytics.doc(docId).update({
        'aiUsage.totalPredictions': FieldValue.increment(1),
        'aiUsage.predictionsUsed': FieldValue.increment(
          predictedCategories.keys.any((cat) => finalCategories.contains(cat)) ? 1 : 0
        ),
        'aiUsage.predictionsModified': FieldValue.increment(
          finalCategories.length != predictedCategories.length ? 1 : 0
        ),
      });
    } else {
      await FirebaseService.merchantAnalytics.doc(docId).set({
        'merchantId': merchantId,
        'date': today,
        'aiUsage': {
          'totalPredictions': 1,
          'predictionsUsed': predictedCategories.keys.any((cat) => finalCategories.contains(cat)) ? 1 : 0,
          'predictionsModified': finalCategories.length != predictedCategories.length ? 1 : 0,
          'averageConfidence': predictedCategories.values.reduce((a, b) => a + b) / predictedCategories.length,
        },
        'categoryStats': {
          'mostUsedCategories': finalCategories,
          'aiSuggestedCategories': predictedCategories.keys.toList(),
        },
      });
    }
  }
}