import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/weather_data.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
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
      onError: (DioError e, handler) {
        _logError('DioInterceptor', e);
        return handler.next(e);
      },
    ));
  }

  Future<Response> _requestWithRetry(RequestOptions options, {int retries = 2}) async {
    DioError? lastError;
    
    for (int i = 0; i < retries; i++) {
      try {
        final response = await _dio.fetch(options);
        return response;
      } on DioError catch (e) {
        lastError = e;
        if (i < retries - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    
    throw lastError!;
  }
  
  Future<Map<String, dynamic>> transcribeAudio(
    File audioFile, 
    String sessionId,
    String deviceId,
  ) async {
    try {
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
            ...ApiConfig.headers,
            'Content-Type': 'multipart/form-data',
          },
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

  Future<List<ChatSession>> getSessions(String deviceId) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/sessions',
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
        '${ApiConfig.baseUrl}/api/sessions',
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
        '${ApiConfig.baseUrl}/api/sessions/$sessionId',
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
        '${ApiConfig.baseUrl}/api/sessions/${session.id}',
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
        '${ApiConfig.baseUrl}/api/sessions/$sessionId',
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
        '${ApiConfig.baseUrl}/api/sessions/$sessionId/messages',
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
        '${ApiConfig.baseUrl}/api/sessions/$sessionId/messages',
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
        '${ApiConfig.baseUrl}/api/sessions/$sessionId/messages',
        queryParameters: {'device_id': deviceId},
      );
    } catch (e) {
      print('Error clearing messages: $e');
      // Continue even if API fails
    }
  }
  // Weather service
  Future<WeatherData> getWeather(double latitude, double longitude) async {
    try {
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'GET',
          path: ApiConfig.weatherEndpoint,
          queryParameters: {'lat': latitude, 'lon': longitude},
        ),
      );
      return WeatherData.fromJson(response.data);
    } catch (e) {
      _logError('getWeather', e);
      rethrow;
    }
  }

  // Chat service
  Future<Map<String, dynamic>> sendMessage(String message, String sessionId, String deviceId, {List<String>? previousBotReplies}) async {
    try {
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'POST',
          path: ApiConfig.chatEndpoint,
          data: {
            'message': message,
            'session_id': sessionId,
            'device_id': deviceId,
          if (previousBotReplies != null) 'history': previousBotReplies,
          },
        ),
      );
      return response.data;
    } catch (e) {
      _logError('sendMessage', e);
      rethrow;
    }
  }

  // File upload
  Future<Map<String, dynamic>> uploadImage(File file, String sessionId, String deviceId,{String? note}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        ),
        'session_id': sessionId,
        'device_id': deviceId,
        if (note != null && note.trim().isNotEmpty) 'note': note,
      });
      
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'POST',
          path: ApiConfig.imageEndpoint,
          data: formData,
          headers: {
            ...ApiConfig.headers,
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return response.data;
    } catch (e) {
      _logError('uploadImage', e);
      rethrow;
    }
  }

  void _logError(String method, dynamic error) {
    if (error is DioError) {
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
