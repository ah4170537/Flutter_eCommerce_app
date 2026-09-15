import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'adufqjy5';
  static const String uploadPreset = 'dzrpqsgz';

  static Uri get _uploadUrl =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');


  static Future<String?> uploadImage(File imageFile, {String? folder}) async {
    if (cloudName == 'YOUR_CLOUD_NAME' ||
        uploadPreset == 'YOUR_UPLOAD_PRESET') {
      throw StateError(
        'CloudinaryService is not configured. Set cloudName and '
        'uploadPreset in cloudinary_service.dart before uploading.',
      );
    }

    try {
      final request = http.MultipartRequest('POST', _uploadUrl)
        ..fields['upload_preset'] = uploadPreset;

      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      } else {
        // ignore: avoid_print
        print(
          'Cloudinary upload failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Cloudinary upload error: $e');
      return null;
    }
  }
}
