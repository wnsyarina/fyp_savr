import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

class ServiceAccountService {
  static String get _privateKey => dotenv.env['FIREBASE_PRIVATE_KEY'] ?? '';
  static String get _clientEmail => dotenv.env['FIREBASE_CLIENT_EMAIL'] ?? '';
  static String get _projectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

  static Future<String?> _generateAccessToken() async {
    try {
      final now = DateTime.now().toUtc();
      final expiry = now.add(Duration(minutes: 60));

      final builder = JsonWebSignatureBuilder();
      builder.jsonContent = {
        'iss': _clientEmail,
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
        'aud': 'https://oauth2.googleapis.com/token',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
      };

      final key = JsonWebKey.fromPem(_privateKey);
      builder.addRecipient(
        key,
        algorithm: 'RS256',
      );

      final jwt = builder.build().toCompactSerialization();
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$jwt',
      );

      print('Token response status: ${response.statusCode}');
      print('Token response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'] as String?;
        if (token != null) {
          print('Access token obtained');
          return token;
        } else {
          print('No access token in response');
          return null;
        }
      }

      print('Token generation failed: ${response.body}');
      return null;
    } catch (e, stackTrace) {
      print('Error generating access token: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<bool> sendNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final Map<String, String> stringData = {};
      data.forEach((key, value) {
        stringData[key] = value.toString();
      });

      stringData['title'] = title;
      stringData['body'] = body;
      stringData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';

      if (data['orderId'] != null) {
        stringData['order_id'] = data['orderId'].toString();
      }
      if (data['type'] != null) {
        stringData['type'] = data['type'].toString();
      }
      stringData['screen'] = 'order_history';


      final accessToken = await _generateAccessToken();
      if (accessToken == null) {
        print('Failed to generate access token');
        return false;
      }

      final url = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      final requestBody = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': stringData,
          'android': {
            'priority': 'HIGH',
            'notification': {
              'title': title,
              'body': body,
              'channel_id': 'order_notifications',
              'sound': 'default',
              'icon': 'ic_notification',
              'color': '#FF6B35',
              'visibility': 'PUBLIC',
            },
          },
        },
      };

      print('Sending HTTP request...');
      final requestBodyJson = json.encode(requestBody);
      print('FCM Payload: $requestBodyJson');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: requestBodyJson,
      );


      if (response.statusCode == 200) {
        print('Notification sent via FCM v1 API');
        return true;
      } else {
        print('FCM failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('ServiceAccountService error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
}