import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';
import '../services/api_service.dart';

class SessionProvider with ChangeNotifier {
  final String _deviceId;
  final ApiService _apiService = ApiService();
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  bool _isLoading = false;
  bool _hasError = false;
  String? _lastErrorMessage;

  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get lastErrorMessage => _lastErrorMessage;

  SessionProvider(this._deviceId) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Register device to backend
    try {
      await _apiService.registerDevice(_deviceId);
    } catch (e) {
      print('Device registration failed: $e');
    }
    
    await _loadLastSession();
    await fetchSessions();
  }

  // Load saved sessions from API
  Future<void> fetchSessions() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      _sessions = await _apiService.getSessions(_deviceId);
      
      // If no current session and we have sessions, use the first one
      if (_currentSession == null && _sessions.isNotEmpty) {
        _currentSession = _sessions.first;
        _saveLastSessionId(_currentSession!.id);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching sessions: $e');
      _isLoading = false;
      _hasError = true;
      _lastErrorMessage = 'Failed to load chat sessions';
      notifyListeners();
      
      // Create a local session if none exists
      if (_currentSession == null) {
        await createNewSession('New Chat');
      }
    }
  }

  // Create a new session - this is the method called from session_list_screen.dart
  Future<ChatSession> createSession(String name) async {
    return await createNewSession(name);
  }

  // Create a new session
  Future<ChatSession> createNewSession(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newSession = await _apiService.createSession(name, _deviceId);
      _sessions.insert(0, newSession);
      _currentSession = newSession;
      _saveLastSessionId(newSession.id);
      
      _isLoading = false;
      notifyListeners();
      return newSession;
    } catch (e) {
      print('Error creating session: $e');
      
      // Fallback: Create local session
      final now = DateTime.now().millisecondsSinceEpoch;
      final localSession = ChatSession(
        id: 'local_${now}',
        name: name,
        createdAt: now,
        updatedAt: now,
      );
      
      _sessions.insert(0, localSession);
      _currentSession = localSession;
      _saveLastSessionId(localSession.id);
      
      _isLoading = false;
      _hasError = true;
      _lastErrorMessage = 'Failed to create a session on server';
      notifyListeners();
      return localSession;
    }
  }

  // Set current session - needed for session_list_screen.dart
  void setCurrentSession(ChatSession session) {
    _currentSession = session;
    _saveLastSessionId(session.id);
    notifyListeners();
  }

  // Rename session - needed for session_list_screen.dart
  Future<void> renameSession(ChatSession session, String newName) async {
    return await updateSessionName(session.id, newName);
  }

  // Clear session messages - needed for session_list_screen.dart
  Future<void> clearSessionMessages(ChatSession session) async {
    try {
      await _apiService.clearMessages(session.id);
      notifyListeners();
    } catch (e) {
      print('Error clearing session messages: $e');
      _hasError = true;
      _lastErrorMessage = 'Failed to clear messages';
      notifyListeners();
    }
  }

  // Delete session - needed for session_list_screen.dart
  Future<void> deleteSession(ChatSession session) async {
    return await deleteSessionById(session.id);
  }

  // Delete session by ID
  Future<void> deleteSessionById(String sessionId) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;
    
    final wasCurrentSession = _currentSession?.id == sessionId;
    _sessions.removeAt(index);
    
    if (wasCurrentSession) {
      _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
      if (_currentSession != null) {
        _saveLastSessionId(_currentSession!.id);
      } else {
        _clearLastSessionId();
      }
    }
    
    notifyListeners();
    
    try {
      await _apiService.deleteSession(sessionId);
    } catch (e) {
      print('Error deleting session: $e');
      // Continue with local deletion even if server delete fails
    }
  }

  // Switch to a different session
  Future<void> switchSession(String sessionId) async {
    if (_currentSession?.id == sessionId) return;
    
    final session = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception('Session not found'),
    );
    
    _currentSession = session;
    _saveLastSessionId(sessionId);
    notifyListeners();
  }

  // Update session name
  Future<void> updateSessionName(String sessionId, String name) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;
    
    final updatedSession = _sessions[index].copyWith(name: name);
    _sessions[index] = updatedSession;
    
    if (_currentSession?.id == sessionId) {
      _currentSession = updatedSession;
    }
    
    notifyListeners();
    
    try {
      await _apiService.updateSession(updatedSession.copyWith(deviceId: _deviceId));
    } catch (e) {
      print('Error updating session name: $e');
      // Keep local change even if server update fails
    }
  }

  // Save last session ID to SharedPreferences
  Future<void> _saveLastSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_session_id', sessionId);
    } catch (e) {
      print('Error saving last session ID: $e');
    }
  }

  // Clear last session ID from SharedPreferences
  Future<void> _clearLastSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_session_id');
    } catch (e) {
      print('Error clearing last session ID: $e');
    }
  }

  // Load last session from SharedPreferences
  Future<void> _loadLastSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSessionId = prefs.getString('last_session_id');
      
      if (lastSessionId != null) {
        // We'll set the current session once we've fetched all sessions
        print('Last session ID: $lastSessionId');
      }
    } catch (e) {
      print('Error loading last session: $e');
    }
  }
}
