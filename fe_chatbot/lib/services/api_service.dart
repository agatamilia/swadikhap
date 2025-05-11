import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../models/message.dart';
import '../models/weather_data.dart';
import '../models/chat_session.dart';
import 'package:image/image.dart' as img;
import 'image_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ApiService {
  final Dio _dio = Dio();
  final String baseUrl = ApiConfig.baseUrl;

  ApiService() {
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: false, // Set to false to avoid logging large image data
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (object) {
        if (object is String && object.contains('image_base64')) {
          print('API Request: Contains image_base64 (content omitted)');
        } else {
          print('I/flutter: $object');
        }
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) {
        print('API Error in DioInterceptor:');
        print('- Type: ${e.type}');
        print('- Path: ${e.requestOptions.path}');
        print('- Status: ${e.response?.statusCode}');
        print('- Message: ${e.message}');
        print('- Response: ${e.response?.data}');
        print('- StackTrace: ${e.stackTrace.toString().split('\n').take(2).join('\n')}');
        handler.next(e);
      },
    ));
  }

  // Session endpoints
  Future<List<ChatSession>> getSessions(String deviceId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/sessions',
        queryParameters: {'device_id': deviceId},
      );
      
      final List<dynamic> sessionsData = response.data;
      return sessionsData.map((data) => ChatSession.fromMap(data)).toList();
    } catch (e) {
      print('Error getting sessions: $e');
      return [];
    }
  }

  Future<ChatSession> createSession(String name, String deviceId) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/sessions',
        data: {
          'device_id': deviceId,
          'name': name,
        },
      );
      return ChatSession.fromMap(response.data);
    } catch (e) {
      print('Error creating session: $e');
      // Create a local session if API fails
      final now = DateTime.now().millisecondsSinceEpoch;
      return ChatSession(
        id: 'local_$now',
        name: name,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      );
    }
  }

  Future<ChatSession> getSessionById(String sessionId, String deviceId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/sessions/$sessionId',
        queryParameters: {'device_id': deviceId},
      );
      return ChatSession.fromMap(response.data);
    } catch (e) {
      print('Error getting session by ID: $e');
      rethrow;
    }
  }

  Future<void> updateSession(ChatSession session, String deviceId) async {
    try {
      await _dio.put(
        '$baseUrl/api/sessions/${session.id}',
        data: {
          'device_id': deviceId,
          'name': session.name,
        },
      );
    } catch (e) {
      print('Error updating session: $e');
      // Continue with local update even if API fails
    }
  }

  Future<void> deleteSession(String sessionId, String deviceId) async {
    try {
      await _dio.delete(
        '$baseUrl/api/sessions/$sessionId',
        queryParameters: {'device_id': deviceId},
      );
    } catch (e) {
      print('Error deleting session: $e');
      // Continue with local deletion even if API fails
    }
  }

  // Message endpoints
  Future<List<ChatMessage>> getMessages(String sessionId, String deviceId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/sessions/$sessionId/messages',
        queryParameters: {'device_id': deviceId},
      );
      
      final List<dynamic> messagesData = response.data;
      return messagesData.map((data) => ChatMessage.fromMap(data)).toList();
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveMessage(ChatMessage message, String sessionId, String deviceId) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/sessions/$sessionId/messages',
        data: {
          'content': message.content,
          'role': message.role == MessageRole.user ? 'user' : 'assistant',
          'image_path': message.imageUrl,
          'audio_path': message.audioUrl,
          'device_id': deviceId,
        },
      );
      return response.data;
    } catch (e) {
      print('Error saving message: $e');
      // Return a mock response if API fails
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'session_id': sessionId,
        'content': message.content,
        'role': message.role == MessageRole.user ? 'user' : 'assistant',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'image_path': message.imageUrl,
        'audio_path': message.audioUrl
      };
    }
  }

  Future<void> clearMessages(String sessionId, String deviceId) async {
    try {
      await _dio.delete(
        '$baseUrl/api/sessions/$sessionId/messages',
        queryParameters: {'device_id': deviceId},
      );
    } catch (e) {
      print('Error clearing messages: $e');
      // Continue even if API fails
    }
  }

  // Chat endpoint
  Future<Map<String, dynamic>> sendMessage(String message, String sessionId, String deviceId) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/chat',
        data: {
          'message': message,
          'session_id': sessionId,
          'device_id': deviceId,
        },
      );
      return response.data;
    } catch (e) {
      print('Error sending message: $e');
      // Return a mock response if API fails
      return {
        'response': 'Maaf, saya tidak dapat terhubung ke server saat ini. Silakan coba lagi nanti.',
        'session_id': sessionId
      };
    }
  }

  // Weather endpoint
  Future<WeatherData> getWeather(double lat, double lon) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/weather',
        queryParameters: {
          'lat': lat,
          'lon': lon,
        },
      );
      
      return WeatherData.fromJson(response.data);
    } catch (e) {
      print('Error getting weather: $e');
      // Return mock data if API fails
      return WeatherData(
        temperature: 28,
        condition: 'Clear',
        description: 'Cerah',
        location: 'Unknown Location',
        advice: 'Cocok untuk panen atau pengeringan hasil panen',
        mock: true,
      );
    }
  }

  // File upload endpoints
  Future<String> uploadAudio(File audioFile, String deviceId) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.wav',
          contentType: MediaType('audio', 'wav'),
        ),
        'device_id': deviceId,
      });
      
      final response = await _dio.post(
        '$baseUrl/api/upload/audio',
        data: formData,
      );
      
      return response.data['file_url'] ?? audioFile.path;
    } catch (e) {
      print('Error uploading audio: $e');
      return audioFile.path; // Return local path if upload fails
    }
  }

  Future<String> uploadImage(File imageFile, String deviceId) async {
    try {
      // Convert image to JPEG if needed
      File fileToUpload = await _ensureJpegFormat(imageFile);
      
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          fileToUpload.path,
          filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        'device_id': deviceId,
      });
      
      final response = await _dio.post(
        '$baseUrl/api/upload/image',
        data: formData,
      );
      
      return response.data['file_url'] ?? fileToUpload.path;
    } catch (e) {
      print('Error uploading image: $e');
      return imageFile.path; // Return local path if upload fails
    }
  }

  // Transcribe endpoint
  Future<Map<String, dynamic>> transcribeAudio(File audioFile, String sessionId, String deviceId) async {
    try {
      print('Transcribing audio file: ${audioFile.path}');
      print('Session ID: $sessionId, Device ID: $deviceId');
      print('Audio file size: ${await audioFile.length()} bytes');
      
      // Create a copy of the audio file with a proper extension
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      final copiedFile = await audioFile.copy(targetPath);
      
      print('Copied audio file to: ${copiedFile.path}');
      print('Copied file size: ${await copiedFile.length()} bytes');
      
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          copiedFile.path,
          filename: 'recording.wav',
          contentType: MediaType('audio', 'wav'),
        ),
        'device_id': deviceId,
        'session_id': sessionId,
      });
      
      print('Sending transcription request to: $baseUrl/api/transcribe');
      final response = await _dio.post(
        '$baseUrl/api/transcribe',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      
      print('Transcription response status: ${response.statusCode}');
      print('Transcription response: ${response.data}');
      
      return response.data;
    } catch (e) {
      print('Error transcribing audio: $e');
      return {
        'error': 'Failed to transcribe audio',
        'transcription': 'Maaf, saya tidak dapat mengenali suara Anda saat ini.',
        'ai_response': 'Silakan coba lagi nanti atau ketik pesan Anda.',
        'audio_path': audioFile.path,
      };
    }
  }

  // Vision endpoint
  Future<Map<String, dynamic>> analyzeImage(
  File imageFile, 
  String sessionId, 
  String deviceId, {
  String? prompt,
}) async {
  try {
    debugPrint('Analyzing image for session: $sessionId, device: $deviceId');
    
    // Convert image to JPEG and prepare for base64 encoding
    File fileToSend = imageFile;
    String? base64Image;
    
    try {
      // Use ImageService to properly compress and convert the image
      final imageService = ImageService();
      fileToSend = await imageService.compressImage(imageFile);
      
      // Convert to base64
      final bytes = await fileToSend.readAsBytes();
      base64Image = base64Encode(bytes);
      
      debugPrint('Successfully converted image to base64 (length: ${base64Image.length})');
    } catch (e) {
      debugPrint('Error preparing image: $e');
      // Continue with original file if conversion fails
    }
    
    // First try the base64 JSON approach
    if (base64Image != null) {
      try {
        final jsonData = {
          'image_base64': base64Image,
          'device_id': deviceId,
          'session_id': sessionId,
          'prompt': prompt ?? 'Analisis gambar tanaman ini dan berikan informasi tentang kondisinya.',
        };
        
        final jsonResponse = await _dio.post(
          ApiConfig.visionEndpoint,
          data: jsonData,
        );
        
        return {
          'status': 'success',
          'analysis': jsonResponse.data['analysis'],
          'image_path': jsonResponse.data['image_path'] ?? fileToSend.path,
        };
      } catch (e) {
        debugPrint('Error with base64 approach: $e');
        // Fall back to form data approach
      }
    }
    
    // Fallback to form data approach
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        fileToSend.path,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
      'device_id': deviceId,
      'session_id': sessionId,
      'prompt': prompt ?? 'Analisis gambar tanaman ini dan berikan informasi tentang kondisinya.',
    });
    
    final response = await _dio.post(
      ApiConfig.visionEndpoint,
      data: formData,
    );
    
    return {
      'status': 'success',
      'analysis': response.data['analysis'] ?? 'Tidak dapat menganalisis gambar.',
      'image_path': response.data['image_path'] ?? fileToSend.path,
    };
  } catch (e) {
    debugPrint('API Error in analyzeImage: $e');
    return {
      'error': 'Gagal menganalisis gambar: ${e.toString()}',
      'analysis': 'Maaf, saya tidak dapat menganalisis gambar saat ini. Silakan coba lagi nanti.',
      'image_path': imageFile.path,
    };
  }
}

  // Helper method to ensure image is in JPEG format and properly sized
  Future<File> _ensureJpegFormat(File imageFile) async {
  try {
    // Create a temporary file for the converted image
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // First try using flutter_image_compress which is more reliable
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      
      if (result != null) {
        print('Image converted to JPEG successfully with flutter_image_compress: ${result.path}');
        return File(result.path);
      }
    } catch (e) {
      print('Error converting with flutter_image_compress: $e');
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
        img.Image processedImage = decodedImage;
        if (decodedImage.width > 1024 || decodedImage.height > 1024) {
          processedImage = img.copyResize(
            decodedImage,
            width: decodedImage.width > decodedImage.height ? 1024 : null,
            height: decodedImage.height >= decodedImage.width ? 1024 : null,
          );
        }
        
        // Encode as JPEG (which automatically drops the alpha channel)
        final jpgBytes = img.encodeJpg(processedImage, quality: 85);
        
        // Save to file
        final jpgFile = File(targetPath);
        await jpgFile.writeAsBytes(jpgBytes);
        
        print('Image converted to JPEG successfully with image package: ${jpgFile.path}');
        return jpgFile;
      }
    } catch (e) {
      print('Error converting with image package: $e');
      // Continue to last fallback
    }
    
    // Last fallback: Just copy the file with a .jpg extension
    final File copiedFile = await imageFile.copy(targetPath);
    print('Image copied without conversion: ${copiedFile.path}');
    return copiedFile;
  } catch (e) {
    print('Error in _ensureJpegFormat: $e');
    return imageFile; // Return original file if all conversion methods fail
  }
}

  // Device registration
  Future<Map<String, dynamic>> registerDevice(String deviceId) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/device',
        data: {'device_id': deviceId},
      );
      return response.data;
    } catch (e) {
      print('Error registering device: $e');
      return {'status': 'error', 'device_id': deviceId};
    }
  }
}
