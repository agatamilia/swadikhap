import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class StorageService {
  static const String _sessionPrefix = 'session_';
  static const String _messagesPrefix = 'messages_';
  
  // Save session data to local storage
  static Future<void> saveSession(String sessionId, Map<String, dynamic> sessionData, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_sessionPrefix}${deviceId}_$sessionId';
    await prefs.setString(key, jsonEncode(sessionData));
  }
  
  // Get session data from local storage
  static Future<Map<String, dynamic>?> getSession(String sessionId, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_sessionPrefix}${deviceId}_$sessionId';
    final data = prefs.getString(key);
    
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    
    return null;
  }
  
  // Save messages to local storage
  static Future<void> saveMessages(String sessionId, List<ChatMessage> messages, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_messagesPrefix}${deviceId}_$sessionId';
    
    final messagesJson = messages.map((msg) => msg.toJson()).toList();
    await prefs.setString(key, jsonEncode(messagesJson));
  }
  
  // Get messages from local storage
  static Future<List<ChatMessage>> getMessages(String sessionId, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_messagesPrefix}${deviceId}_$sessionId';
    final data = prefs.getString(key);
    
    if (data != null) {
      final List<dynamic> messagesJson = jsonDecode(data);
      return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
    }
    
    return [];
  }
  
  // Delete session and its messages
  static Future<void> deleteSession(String sessionId, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = '${_sessionPrefix}${deviceId}_$sessionId';
    final messagesKey = '${_messagesPrefix}${deviceId}_$sessionId';
    
    await prefs.remove(sessionKey);
    await prefs.remove(messagesKey);
  }
  
  // Get all sessions for a device
  static Future<List<String>> getAllSessionIds(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final sessionPrefix = '${_sessionPrefix}$deviceId';
    
    return allKeys
        .where((key) => key.startsWith(sessionPrefix))
        .map((key) => key.substring(sessionPrefix.length + 1))
        .toList();
  }
}
