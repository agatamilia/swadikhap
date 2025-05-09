import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
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

  Future<Map<String, dynamic>> transcribeAudio(File audioFile, String sessionId) async {
      try {
        var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/api/upload/audio'));
        request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
        request.fields['session_id'] = sessionId;

        var response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          return json.decode(responseData);  // Kembalikan hasil transkripsi audio
        } else {
          throw Exception('Gagal mengirim audio');
        }
      } catch (e) {
        print('Error sending audio: $e');
        throw Exception('Error sending audio: $e');
      }
    }
  }
  // Image analysis
  Future<Map<String, dynamic>> analyzeImage(File imageFile, String sessionId, String deviceId) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/api/upload/image'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      request.fields['session_id'] = sessionId;
      request.fields['device_id'] = deviceId;

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return json.decode(responseData);  // Kembalikan hasil analisis gambar
      } else {
        throw Exception('Gagal mengirim gambar');
      }
    } catch (e) {
      print('Error sending image: $e');
      throw Exception('Error sending image: $e');
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

