import 'dart:io';
import 'package:http/http.dart' as http;

class NetworkService {
  static Future<bool> hasInternetConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}