import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  static const String _emailJsServiceId = 'your_service_id';
  static const String _emailJsTemplateId = 'your_template_id';
  static const String _emailJsUserId = 'your_user_id';

  static Future<void> sendVerificationEmail({
    required String toEmail,
    required String toName,
    required String restaurantName,
    required String status,
    required String notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _emailJsServiceId,
          'template_id': _emailJsTemplateId,
          'user_id': _emailJsUserId,
          'template_params': {
            'to_email': toEmail,
            'to_name': toName,
            'restaurant_name': restaurantName,
            'verification_status': status,
            'admin_notes': notes,
            'app_name': 'Savr',
          }
        }),
      );

      if (response.statusCode == 200) {
        print('Email sent successfully to $toEmail');
      } else {
        print('Email failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Email error: $e');
    }
  }

}