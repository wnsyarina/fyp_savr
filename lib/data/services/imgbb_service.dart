import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImgBBService {
  static const String apiKey = 'c8222fd8186ccf739f30e2c11be946f4';
  static const String uploadUrl = 'https://api.imgbb.com/1/upload';

  static Future<String?> uploadImage(File imageFile) async {
    try {
      print('=== Uploading image to ImgBB ===');
      print('File path: ${imageFile.path}');
      print('File size: ${(await imageFile.length() / 1024).toStringAsFixed(2)} KB');

      final fileSize = await imageFile.length();
      if (fileSize > 32 * 1024 * 1024) {
        print('ERROR: File too large for ImgBB free tier');
        return null;
      }

      final uri = Uri.parse('$uploadUrl?key=$apiKey');
      final request = http.MultipartRequest('POST', uri);

      // Add image file
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData) as Map<String, dynamic>;

      print('ImgBB Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final imageUrl = jsonResponse['data']['url'] as String;
        final thumbUrl = jsonResponse['data']['thumb']['url'] as String?;
        final mediumUrl = jsonResponse['data']['medium']['url'] as String?;

        print('✅ Image uploaded successfully!');
        print('Full URL: $imageUrl');
        print('Thumbnail URL: $thumbUrl');
        print('Medium URL: $mediumUrl');

        return imageUrl;
      } else {
        print('❌ ImgBB upload failed: ${jsonResponse['error']['message']}');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading to ImgBB: $e');
      return null;
    }
  }

  static bool isImgBBUrl(String url) {
    return url.contains('i.ibb.co') || url.contains('imgbb.com');
  }

  static String getThumbnailUrl(String fullUrl) {
    return fullUrl.replaceAll('/image/', '/thumb/');
  }
}