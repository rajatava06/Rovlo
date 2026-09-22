import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Service for uploading media to Cloudinary.
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  // Cloudinary credentials (customizable via env or constants)
  static const String _defaultCloudName = 'rovlo-cloud';
  static const String _defaultUploadPreset = 'rovlo_preset';

  /// Uploads an image file to Cloudinary and returns the hosted secure URL.
  /// Falls back to local file URI or data string if offline/unconfigured.
  Future<String?> uploadImage(XFile imageFile, {String? customPreset}) async {
    try {
      const cloudName = String.fromEnvironment(
        'CLOUDINARY_CLOUD_NAME',
        defaultValue: _defaultCloudName,
      );
      final uploadPreset = customPreset ??
          const String.fromEnvironment(
            'CLOUDINARY_UPLOAD_PRESET',
            defaultValue: _defaultUploadPreset,
          );

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'rovlo_chat_images';

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageFile.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
      }

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 15),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = json['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        }
      }

      // If Cloudinary preset is unconfigured on free tier, fallback to local path or mock
      debugPrint(
        'Cloudinary returned status: ${response.statusCode}, body: ${response.body}',
      );
      return imageFile.path;
    } catch (e) {
      debugPrint('Cloudinary upload exception: $e');
      // Graceful fallback so chat image is always displayed
      return imageFile.path;
    }
  }
}
