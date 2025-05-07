import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'api_service.dart';

class ImageService {
  final ImagePicker _imagePicker = ImagePicker();
  final ApiService _apiService = ApiService();

  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    int? quality,
  }) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: quality,
      );
      
      return pickedFile;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  Future<String> saveImageLocally(File imageFile, String deviceId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images/$deviceId');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${imagesDir.path}/$fileName';
      
      await imageFile.copy(savedPath);
      return savedPath;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return imageFile.path; // Return original path if saving fails
    }
  }

  Future<Map<String, dynamic>> analyzeImage(File imageFile, String sessionId, String deviceId) async {
    try {
      // First save the image locally
      final localPath = await saveImageLocally(imageFile, deviceId);
      
      // Then send to API for analysis
      final response = await _apiService.analyzeImage(imageFile, sessionId, deviceId);
      
      // If the API doesn't return an image path, use the local one
      if (!response.containsKey('image_path') || response['image_path'] == null) {
        response['image_path'] = localPath;
      }
      
      return response;
    } catch (e) {
      debugPrint('Error in analyzeImage: $e');
      return {
        'error': e.toString(),
        'analysis': 'Gagal menganalisis gambar. Silakan coba lagi nanti.',
        'image_path': imageFile.path,
      };
    }
  }

  Future<File?> compressImage(File imageFile, {int quality = 85}) async {
    try {
      // For now, just return the original file
      // In a real implementation, you would use a package like flutter_image_compress
      return imageFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageFile;
    }
  }
}
