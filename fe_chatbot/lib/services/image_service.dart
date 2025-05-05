import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ImageService {
  Future<Map<String, dynamic>> uploadAndAnalyzeImage(
    File imageFile, 
    String sessionId,
    String? userPrompt,
  ) async {
    try {
      // Baca file gambar sebagai bytes
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Buat request multipart
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadEndpoint}');
      final request = http.MultipartRequest('POST', uri);

      // Tambahkan headers
      request.headers.addAll(ApiConfig.headers);

      // Tambahkan file gambar
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'plant_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // Tambahkan field lainnya
      request.fields['session_id'] = sessionId;
      if (userPrompt != null) {
        request.fields['prompt'] = userPrompt;
      }

      // Kirim request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        throw Exception('Failed to upload image: ${response.statusCode} $responseBody');
      }
    } catch (e) {
      debugPrint('Error in uploadAndAnalyzeImage: $e');
      rethrow;
    }
  }
}