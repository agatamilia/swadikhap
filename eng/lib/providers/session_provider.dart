import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';

class SessionProvider with ChangeNotifier {
  final ApiService _apiService;
  final DeviceService _deviceService;
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  bool _isLoading = false;
  bool _hasError = false;
  String? _lastErrorMessage;
  String _deviceId = '';

  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get lastErrorMessage => _lastErrorMessage;
  String get deviceId => _deviceId;

  SessionProvider({
    required ApiService apiService,
    required DeviceService deviceService,
  })  : _apiService = apiService,
        _deviceService = deviceService {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _deviceId = await _deviceService.getDeviceId();
      await _loadLastSession();
      await fetchSessions();
    } catch (e) {
      debugPrint('Error initializing SessionProvider: $e');
      _hasError = true;
      _lastErrorMessage = 'Failed to initialize session provider';
      notifyListeners();
    }
  }

  Future<void> fetchSessions() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final List<ChatSession> fetchedSessions =
          await _apiService.getSessions(_deviceId);
      _sessions = fetchedSessions;

      // Restore last session if available
      final prefs = await SharedPreferences.getInstance();
      final lastSessionId = prefs.getString('last_session_id');

      if (lastSessionId != null) {
        try {
          _currentSession = _sessions.firstWhere(
            (s) => s.id == lastSessionId,
            orElse: () => _sessions.isNotEmpty
                ? _sessions.first
                : throw Exception('No sessions'),
          );
        } catch (e) {
          _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
        }
      } else if (_sessions.isNotEmpty) {
        _currentSession = _sessions.first;
      }
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      _hasError = true;
      _lastErrorMessage = 'Failed to load chat sessions';

      // Create a local session if none exists
      if (_currentSession == null) {
        await _createLocalSession('New Chat');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatSession> createSession(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final ChatSession newSession =
          await _apiService.createSession(name, _deviceId);
      _sessions.insert(0, newSession);
      _currentSession = newSession;
      await _saveLastSessionId(newSession.id);
      return newSession;
    } catch (e) {
      debugPrint('Error creating session: $e');
      return await _createLocalSession(name);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatSession> _createLocalSession(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final localSession = ChatSession(
      id: 'local_$now',
      name: name,
      createdAt: now,
      updatedAt: now,
      deviceId: _deviceId,
    );

    _sessions.insert(0, localSession);
    _currentSession = localSession;
    await _saveLastSessionId(localSession.id);

    _hasError = true;
    _lastErrorMessage = 'Failed to create session on server';
    notifyListeners();

    return localSession;
  }

  void setCurrentSession(ChatSession session) {
    if (_currentSession?.id == session.id) return;

    _currentSession = session;
    _saveLastSessionId(session.id);
    notifyListeners();
  }

  Future<void> renameSession(ChatSession session, String newName) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) return;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedSession = _sessions[index].copyWith(name: newName);
      _sessions[index] = updatedSession;

      if (_currentSession?.id == session.id) {
        _currentSession = updatedSession;
      }

      await _apiService.updateSession(updatedSession, _deviceId);
      await _saveLastSessionId(updatedSession.id);
    } catch (e) {
      debugPrint('Error renaming session: $e');
      _hasError = true;
      _lastErrorMessage = 'Failed to rename session';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSessionMessages(ChatSession session) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.clearMessages(session.id, _deviceId);
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      _hasError = true;
      _lastErrorMessage = 'Failed to clear messages';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSession(ChatSession session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.deleteSession(session.id, _deviceId);
      _sessions.removeAt(index);

      if (_currentSession?.id == session.id) {
        _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
        if (_currentSession != null) {
          await _saveLastSessionId(_currentSession!.id);
        } else {
          await _clearLastSessionId();
        }
      }
    } catch (e) {
      debugPrint('Error deleting session: $e');
      _hasError = true;
      _lastErrorMessage = 'Failed to delete session';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveLastSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_session_id', sessionId);
    } catch (e) {
      debugPrint('Error saving last session ID: $e');
    }
  }

  Future<void> _clearLastSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_session_id');
    } catch (e) {
      debugPrint('Error clearing last session ID: $e');
    }
  }

  Future<void> _loadLastSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSessionId = prefs.getString('last_session_id');

      if (lastSessionId != null &&
          _sessions.any((s) => s.id == lastSessionId)) {
        _currentSession = _sessions.firstWhere((s) => s.id == lastSessionId);
      }
    } catch (e) {
      debugPrint('Error loading last session: $e');
    }
  }
}
