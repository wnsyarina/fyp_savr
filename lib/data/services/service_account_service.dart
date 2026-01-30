import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

class ServiceAccountService {
  static const String _privateKey = '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCkXVFh0p3UUmrn
WFQVbvm9CU9FTVNQoqcQTKKaCveTmpZ5YZq7RrRcpgGpIoAKyUT9uYOFEFKcS1km
jNTasYTDVW8LUmVI1EK0FVNarAHH/fPa9GyHtCLBUvWs+RZBe8i94CjfoLL1ylfr
qfq4XKj2Dc1Tr3nycZjSezqHCHyJKg9ld6Evak3uYxO/6dzHCW4zdYQqtufJGBfc
Z3gnwmBAJv4+UWeHrgKZfkcJAwLTyP91ekKfd0ik9hyOyfE0jbK+LmkiSPjrOGKY
FOuqbBB6qmQ3aO2x/P8MSfCtkA13XLvatELpsX+mZH/42nrmBkyE5Red6Qk3L2sN
VCimqOFtAgMBAAECggEACerxlrABQwcIGVaMmFB+dEgkBuAAF30BDKw7IYVo4/iv
fLqFfihpiK+hqQWCaWQ0rASuKXDPM0weoINd8qZEhw7YKPw7TVY1gi1JPs7jOqCZ
vswB4nxdnoG1fk73Z1MjTUXB4aCOO+OOQ5OZo9c/gL1bduG/P4BYQtcZtH0wGoyc
4lhDcKrog/fz+H/cd0XyxlvADkVWBDNrkvvEoQvIeLIJs+UkTTqtCvQBX6rHr/c/
uFCOzFytc/S3ImtD6Uxl21tUng5eZ388RElZsS5ED2I25c/kAtpXDkCZ0dTNwGZa
OWB3nxNA3J2r1P629Y+JpqOFATh97rnJlg2EHsB15wKBgQDWq9ZPv7SHeMPILsc2
YQ0BCWkxRrJ7rAXmDviLdKdsmGT6jIWJjl9aTMvYAF5Cb1Cl66o0/h14yvkcX3gF
UVdS1Vrvq2g/kgXdeYP0SBlKtZBTLvCotldeZhTVsLkScJEWVHYbYzROT9pbLlhz
VlWx9ZTFIwaDRn9bDuLQN+bQ0wKBgQDEAhfMsuqOTwJQOyTacA7fiJgQFNXkAMDF
T3+3ZrjXuRMBmEzfuucgWEgdjUdIGKr+czvt2ZNwdC3vgavRogC7AmrMI9q0wsX4
7m1c2ziixS5gI6PyEoIwts1cV+p1+ujd9ayP+YifbkNsLzwVuIGfseeBNEH3kiBD
RoUkwXQcvwKBgQC6u99An9G5xiMIDyja9LELJdSLOKQpUAoRhRROurqojCfKilHe
xinLsuHekvNrdskAi28Tibi5SlZHiAQvHAKJ222u7btREQRpEzrlU5IsmqNguIQ/
Pd3iD4owF/nlQGX0tqPGTxVAydV3W2k1avRASQ+QLFeN+dTusJQ762SsYQKBgF2j
llUfgHjd+//yUWfdsu1NZz//hDN5vJ5GnYAzncjJTPAtH0SfGL3WDxW3Ib+qsT4A
NTgrAontpuhN7ZSnrWup+vVth5Vlm4iR90MuI793LfGV9UO3XeUB39fm1EbqyIcJ
UBg0IPXxilpLsou56ostRajvGzi34ZviO8dUeDEnAoGAJqeYbasSdUvQFOw9KklE
JJr3z1o329S39hbnjgGQ3sVYq9OkC36JqzKNg7s0LY1jbImmBJ1b8iHd67zeKIox
QvXRyjs9wFluXaQlKMecqmdi2Ht1WkQIAqPnUUsqvGiaf1gjhlMIGUY1IxaEojsf
8VHbR6Nv9bkrY6DrBW7bcho=
-----END PRIVATE KEY-----''';

  static const String _clientEmail = 'firebase-adminsdk-fbsvc@fypsavr.iam.gserviceaccount.com';
  static const String _projectId = 'fypsavr';

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