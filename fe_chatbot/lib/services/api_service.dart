import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/weather_data.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import 'device_service.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
    ),
  );

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('API Request: ${options.method} ${options.uri}');
        print('Headers: ${options.headers}');
        print('Data: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('API Response: ${response.statusCode} ${response.requestOptions.uri}');
        print('Response Data: ${response.data}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        _logError('DioInterceptor', e);
        return handler.next(e);
      },
    ));
  }

  // Device registration
  Future<void> registerDevice(String deviceId) async {
    try {
      await _dio.post(
        ApiConfig.registerDeviceEndpoint,
        data: {'device_id': deviceId},
      );
    } catch (e) {
      print('Error registering device: $e');
      // Continue even if registration fails
    }
  }

  // Session management
  Future<List<ChatSession>> getSessions(String deviceId) async {
    try {
      final response = await _dio.get(
        ApiConfig.sessionEndpoint,
        queryParameters: {'device_id': deviceId},
      );
      return (response.data as List)
          .map((json) => ChatSession.fromMap(json))
          .toList();
    } catch (e) {
      _logError('getSessions', e);
      rethrow;
    }
  }

  Future<ChatSession> createSession(String name, String deviceId) async {
    try {
      final response = await _dio.post(
        ApiConfig.sessionEndpoint,
        data: {'name': name, 'device_id': deviceId},
      );
      return ChatSession.fromMap(response.data);
    } catch (e) {
      _logError('createSession', e);
      rethrow;
    }
  }

  Future<void> updateSession(ChatSession session) async {
    try {
      await _dio.put(
        '${ApiConfig.sessionEndpoint}/${session.id}',
        data: session.toMap(),
      );
    } catch (e) {
      _logError('updateSession', e);
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _dio.delete('${ApiConfig.sessionEndpoint}/$sessionId');
    } catch (e) {
      _logError('deleteSession', e);
      rethrow;
    }
  }

  // Message management
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages',
      );
      return (response.data as List)
          .map((json) => ChatMessage.fromMap(json))
          .toList();
    } catch (e) {
      _logError('getMessages', e);
      rethrow;
    }
  }

  Future<void> saveMessage(ChatMessage message, String sessionId) async {
    try {
      await _dio.post(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages',
        data: message.toApiMap(sessionId),
      );
    } catch (e) {
      _logError('saveMessage', e);
      rethrow;
    }
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    try {
      await _dio.delete(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages/$messageId',
      );
    } catch (e) {
      _logError('deleteMessage', e);
      rethrow;
    }
  }

  Future<void> clearMessages(String sessionId) async {
    try {
      await _dio.delete(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages',
      );
    } catch (e) {
      _logError('clearMessages', e);
      rethrow;
    }
  }

  // Weather service
  Future<WeatherData> getWeather(double latitude, double longitude) async {
    try {
      final response = await _dio.get(
        ApiConfig.weatherEndpoint,
        queryParameters: {'lat': latitude, 'lon': longitude},
      );
      return WeatherData.fromJson(response.data);
    } catch (e) {
      _logError('getWeather', e);
      rethrow;
    }
  }

  // Chat service
  Future<Map<String, dynamic>> sendMessage(String message, String sessionId, String deviceId) async {
    try {
      final response = await _dio.post(
        ApiConfig.chatEndpoint,
        data: {
          'message': message,
          'session_id': sessionId,
          'device_id': deviceId,
        },
      );
      return response.data;
    } catch (e) {
      _logError('sendMessage', e);
      rethrow;
    }
  }

  // Audio transcription with improved error handling
  Future<Map<String, dynamic>> transcribeAudio(File audioFile, String sessionId) async {
    try {
      final deviceId = await DeviceService().getDeviceId();
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'recording_${DateTime.now().millisecondsSinceEpoch}.wav',
          contentType: MediaType('audio', 'wav'),
        ),
        'session_id': sessionId,
        'device_id': deviceId,
      });

      final response = await _dio.post(
        ApiConfig.transcribeEndpoint,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Audio transcription failed with status ${response.statusCode}');
      }

      return response.data;
    } on DioException catch (e) {
      _logError('transcribeAudio', e);
      if (e.response?.data != null && e.response?.data is Map) {
        final errorData = e.response?.data as Map;
        if (errorData.containsKey('error')) {
          throw Exception('Audio transcription failed: ${errorData['error']}');
        }
      }
      throw Exception('Audio transcription failed: ${e.message}');
    } catch (e) {
      _logError('transcribeAudio', e);
      throw Exception('Audio transcription failed: $e');
    }
  }

  // Image analysis
  Future<Map<String, dynamic>> analyzeImage(File imageFile, String sessionId, String deviceId) async {
    try {
      print('Analyzing image for session: $sessionId, device: $deviceId');
      
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'plant_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'session_id': sessionId,
        'device_id': deviceId,
        'prompt': 'Analisis gambar tanaman ini dan berikan informasi tentang kondisinya.',
      });

      print('Sending image analysis request to: ${ApiConfig.visionEndpoint}');
      
      final response = await _dio.post(
        ApiConfig.visionEndpoint,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      print('Image analysis response status: ${response.statusCode}');
      print('Image analysis response: ${response.data}');
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        print('Image analysis failed with status ${response.statusCode}');
        return {
          'error': 'Image analysis failed with status ${response.statusCode}',
          'analysis': 'Maaf, saya tidak dapat menganalisis gambar saat ini. Silakan coba lagi nanti.',
          'image_path': null
        };
      }
    } on DioException catch (e) {
      _logError('analyzeImage', e);
      return {
        'error': 'Gagal menganalisis gambar: ${e.message}',
        'analysis': 'Maaf, saya tidak dapat menganalisis gambar saat ini. Silakan coba lagi nanti.',
        'image_path': null
      };
    } catch (e) {
      _logError('analyzeImage', e);
      return {
        'error': 'Gagal menganalisis gambar: $e',
        'analysis': 'Maaf, saya tidak dapat menganalisis gambar saat ini. Silakan coba lagi nanti.',
        'image_path': null
      };
    }
  }

  void _logError(String method, dynamic error) {
    if (error is DioException) {
      print('''
API Error in $method:
- Type: ${error.type}
- Path: ${error.requestOptions.path}
- Status: ${error.response?.statusCode}
- Message: ${error.message}
- Response: ${error.response?.data}
- StackTrace: ${error.stackTrace}
''');
    } else {
      print('''
Error in $method:
- Error: $error
- StackTrace: ${error is Error ? error.stackTrace : ''}
''');
    }
  }
}
