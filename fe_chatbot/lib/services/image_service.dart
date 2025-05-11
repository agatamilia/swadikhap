import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
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
      
      // Compress and convert image to JPEG
      final compressedImage = await compressImage(imageFile);
      
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${imagesDir.path}/$fileName';
      
      await compressedImage.copy(savedPath);
      return savedPath;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return imageFile.path; // Return original path if saving fails
    }
  }

  Future<Map<String, dynamic>> analyzeImage(
    File imageFile, 
    String sessionId, 
    String deviceId,
    {String? prompt}
  ) async {
    try {
      // First save the image locally
      final localPath = await saveImageLocally(imageFile, deviceId);
      
      // Convert image to base64
      final compressedImage = await compressImage(File(localPath));
      final base64Image = await convertImageToBase64(compressedImage);
      
      // Then send to API for analysis
      final response = await _apiService.analyzeImage(
        compressedImage, 
        sessionId, 
        deviceId,
        prompt: prompt,
      );
      
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

  Future<File> compressImage(File imageFile, {int quality = 85}) async {
  try {
    // Create a temporary file for the compressed image
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // First try using flutter_image_compress which is more reliable
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        minWidth: 1024,
        minHeight: 1024,
        quality: quality,
      );
      
      if (result != null) {
        debugPrint('Image compressed successfully with flutter_image_compress: ${result.path}');
        return File(result.path);
      }
    } catch (e) {
      debugPrint('Error compressing with flutter_image_compress: $e');
      // Continue to fallback method
    }
    
    // Fallback: Use the image package
    try {
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      
      // Decode the image
      final decodedImage = img.decodeImage(imageBytes);
      
      if (decodedImage != null) {
        // Resize if larger than 1024x1024
        img.Image resizedImage = decodedImage;
        if (decodedImage.width > 1024 || decodedImage.height > 1024) {
          resizedImage = img.copyResize(
            decodedImage,
            width: decodedImage.width > decodedImage.height ? 1024 : null,
            height: decodedImage.height >= decodedImage.width ? 1024 : null,
          );
        }
        
        // Convert to JPEG (which automatically drops the alpha channel)
        final jpgBytes = img.encodeJpg(resizedImage, quality: quality);
        
        // Save to file
        final compressedFile = File(targetPath);
        await compressedFile.writeAsBytes(jpgBytes);
        
        debugPrint('Image compressed successfully with image package: ${compressedFile.path}');
        return compressedFile;
      }
    } catch (e) {
      debugPrint('Error compressing with image package: $e');
      // Continue to last fallback
    }
    
    // Last fallback: Just copy the file with a .jpg extension
    final File copiedFile = await imageFile.copy(targetPath);
    debugPrint('Image copied without compression: ${copiedFile.path}');
    return copiedFile;
  } catch (e) {
    debugPrint('Error in compressImage: $e');
    return imageFile; // Return original file if all compression methods fail
  }
}
  
  Future<String> convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      rethrow;
    }
  }
}
