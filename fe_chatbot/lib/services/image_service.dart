import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; 
import '../config/api_config.dart';

class ImageService {
  final ImagePicker _imagePicker = ImagePicker();

  // Pick an image from gallery
  Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    double maxWidth = 1800,
    double maxHeight = 1800,
  }) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: 80, // Compress to reduce file size
      );
      
      if (pickedFile == null) return null;
      
      // Save to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      
      debugPrint('Image saved to: ${savedImage.path}');
      return savedImage;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // Upload image to server and get analysis
  Future<Map<String, dynamic>> uploadAndAnalyzeImage(File imageFile, String sessionId) async {
    try {
      // Create multipart request
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload');
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers
      request.headers.addAll(ApiConfig.headers);
      
      // Add session ID
      request.fields['session_id'] = sessionId;
      
      // Add file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: path.basename(imageFile.path),
        contentType: _getImageContentType(imageFile.path),  // Use the updated method
      );
      request.files.add(multipartFile);
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to upload image: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  // Get content type based on file extension (using http_parser's MediaType)
  MediaType _getImageContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      default:
        return MediaType('image', 'jpeg'); // Default
    }
  }
}
