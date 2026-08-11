import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  static const String _cloudName = 'dkwtawuvq';
  static const String _uploadPreset = 'uni_nex_unsigne';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Upload an image file to Cloudinary using unsigned upload.
  /// Returns the secure URL of the uploaded image on success.
  Future<String?> uploadImage(File imageFile, {String? folder}) async {
    try {
      // Validate file exists and is readable
      if (!await imageFile.exists()) {
        debugPrint('Cloudinary upload error: File does not exist at ${imageFile.path}');
        return null;
      }

      final fileSize = await imageFile.length();
      debugPrint('Cloudinary: Uploading file ${imageFile.path} (${(fileSize / 1024).toStringAsFixed(1)} KB)');

      if (fileSize == 0) {
        debugPrint('Cloudinary upload error: File is empty');
        return null;
      }

      // 10 MB limit for free Cloudinary accounts
      if (fileSize > 10 * 1024 * 1024) {
        debugPrint('Cloudinary upload error: File too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');
        return null;
      }

      final uri = Uri.parse(_uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      // Cloudinary auto-detects content type, so no need to specify it
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      debugPrint('Cloudinary: Sending request to $_uploadUrl');
      debugPrint('Cloudinary: Upload preset = $_uploadPreset, folder = $folder');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Upload timed out after 60 seconds');
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      debugPrint('Cloudinary: Response status = ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        final secureUrl = jsonResponse['secure_url'] as String?;
        debugPrint('Cloudinary upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('Cloudinary upload FAILED with status ${streamedResponse.statusCode}');
        debugPrint('Cloudinary response body: $responseBody');

        // Try to parse error message from Cloudinary
        try {
          final errorJson = json.decode(responseBody);
          final errorMsg = errorJson['error']?['message'] ?? 'Unknown error';
          debugPrint('Cloudinary error message: $errorMsg');
        } catch (_) {
          // Response wasn't JSON
        }

        return null;
      }
    } on SocketException catch (e) {
      debugPrint('Cloudinary upload error (network): $e');
      debugPrint('Check your internet connection');
      return null;
    } on http.ClientException catch (e) {
      debugPrint('Cloudinary upload error (client): $e');
      return null;
    } catch (e, stackTrace) {
      debugPrint('Cloudinary upload error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}
