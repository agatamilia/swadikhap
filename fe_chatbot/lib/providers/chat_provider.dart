import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/permission_service.dart';
import '../services/image_service.dart';
import 'session_provider.dart';
import '../services/tts_service.dart';
import '../services/device_service.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final ApiService _apiService = ApiService();
  final AudioService _audioService = AudioService();
  final TTSService _ttsService = TTSService();
  final ImageService _imageService = ImageService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isListening = false;
  bool _useVoiceOutput = true;
  bool _isInitialized = false;
  File? _pendingImage;
  String _currentSessionId = '';
  String _deviceId = '';

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  bool get useVoiceOutput => _useVoiceOutput;
  bool get hasImagePending => _pendingImage != null;

  ChatProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      final deviceService = DeviceService();
      _deviceId = await deviceService.getDeviceId();
      
      await _ttsService.initialize();
      await _initAudio();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing ChatProvider: $e');
    }
  }

  Future<void> _initAudio() async {
    await _audioService.initRecorder();
    await _audioService.initPlayer();
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> loadMessages(String sessionId) async {
    if (_currentSessionId == sessionId && _messages.isNotEmpty) return;
    
    _messages.clear();
    _currentSessionId = sessionId;
    _isLoading = true;
    notifyListeners();
    
    try {
      final savedMessages = await _apiService.getMessages(sessionId);
      
      if (savedMessages.isNotEmpty) {
        // Filter out duplicates by comparing content and role
        final uniqueMessages = <ChatMessage>[];
        final seen = <String>{};
        
        for (final msg in savedMessages) {
          final key = '${msg.role}:${msg.content}';
          if (!seen.contains(key)) {
            uniqueMessages.add(msg);
            seen.add(key);
          }
        }
        
        _messages.addAll(uniqueMessages);
      } else {
        _addWelcomeMessage(sessionId);
      }
    } catch (e) {
      print('Error loading messages: $e');
      _addWelcomeMessage(sessionId);
      
      if (_messages.isEmpty) {
        _addConnectionErrorMessage();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearPendingImage() {
    _pendingImage = null;
    notifyListeners();
  }

  void _addWelcomeMessage(String sessionId) {
    _messages.add(ChatMessage(
      content: "Selamat datang di PeTaniku! Saya siap membantu dengan pertanyaan seputar pertanian.",
      role: MessageRole.assistant,
    ));
  }

  void _addConnectionErrorMessage() {
    _messages.add(ChatMessage(
      content: "Saya tidak dapat terhubung ke server saat ini. Beberapa fitur mungkin terbatas. "
               "Pesan Anda akan disimpan secara lokal dan akan disinkronkan ketika koneksi pulih.",
      role: MessageRole.assistant,
    ));
  }

  void toggleVoiceOutput() {
    _useVoiceOutput = !_useVoiceOutput;
    notifyListeners();
  }

  Future<void> sendMessage(String text, String sessionId, SessionProvider sessionProvider) async {
    if (text.isEmpty && !hasImagePending) return;

    // Create new session if this is the first message
    if (_messages.isEmpty && sessionId.isEmpty) {
      final newSession = await sessionProvider.createSession(
        text.isNotEmpty ? (text.length > 30 ? '${text.substring(0, 30)}...' : text) : 'Analisis Gambar'
      );
      sessionId = newSession.id;
    }

    // Process image if there's a pending image
    if (_pendingImage != null) {
      await _processImage(sessionId, text); // Pass the text prompt along with the image
      return;
    }
    
    // For text-only messages
    final userMessage = ChatMessage(
      content: text,
      role: MessageRole.user,
    );
    _messages.add(userMessage);
    notifyListeners();

    try {
      await _apiService.saveMessage(userMessage, sessionId);
    } catch (e) {
      print('Failed to save message: $e');
    }

    // Process regular text message
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.sendMessage(text, sessionId, _deviceId);
      await _addBotMessage(response['response'], sessionId);
    } catch (e) {
      print('Error sending message: $e');
      await _addBotMessage(_getErrorMessage(e), sessionId);
    }
  }

// Update the image processing method
  Future<void> _processImage(String sessionId, String prompt) async {
    if (_pendingImage == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // First, add the user message with the image
      final userMessage = ChatMessage(
        content: prompt.isNotEmpty ? prompt : "Analisis gambar tanaman ini",
        role: MessageRole.user,
        imageUrl: _pendingImage!.path,
      );
      
      _messages.add(userMessage);
      notifyListeners();
      
      try {
        await _apiService.saveMessage(userMessage, sessionId);
      } catch (e) {
        print('Failed to save user message with image: $e');
      }
      
      // Send image for analysis
      final response = await _imageService.analyzeImage(
        _pendingImage!, 
        sessionId, 
        _deviceId,
        prompt: prompt.isNotEmpty ? prompt : null,
      );
      
      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
      
      // Update the user message with the server image path if available
      if (response.containsKey('image_path')) {
        final lastIndex = _messages.length - 1;
        _messages[lastIndex] = _messages[lastIndex].copyWith(
          imageUrl: response['image_path'],
        );
        notifyListeners();
      }
      
      // Add the bot response
      final analysis = response['analysis'] ?? 'Tidak dapat menganalisis gambar.';
      await _addBotMessage(analysis, sessionId);
      
      _pendingImage = null;
    } catch (e) {
      debugPrint('Error processing image: $e');
      await _addBotMessage(
        'Gagal menganalisis gambar. Silakan coba lagi. Error: ${e.toString()}',
        sessionId,
      );
      _pendingImage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }   
  String _getErrorMessage(dynamic error) {
    return "Terjadi kesalahan tak terduga. Silakan coba lagi.";
  }

  Future<void> _addBotMessage(String content, String sessionId) async {
    final cleanContent = content.replaceAll('*', '');
    final botMessage = ChatMessage(
      content: content,
      cleanContent: cleanContent,
      role: MessageRole.assistant,
    );
    
    _messages.add(botMessage);
    
    try {
      await _apiService.saveMessage(botMessage, sessionId);
    } catch (e) {
      print('Failed to save bot message: $e');
    }
    
    _isLoading = false;
    notifyListeners();
    
    if (_useVoiceOutput) {
      _speakText(botMessage.cleanContent ?? cleanContent);
    }
  }

  Future<void> _speakText(String text) async {
    try {
      final cleanText = text.replaceAll('*', '');
      await _ttsService.speak(cleanText);
    } catch (e) {
      print('Error speaking text: $e');
    }
  }

  Future<void> startListening(BuildContext context) async {
    try {
      if (!await PermissionService.hasMicrophonePermission()) {
        final granted = await PermissionService.requestMicrophonePermission();
        if (!granted && context.mounted) {
          await PermissionService.showPermissionDialog(context, 'Mikrofon');
          return;
        }
      }

      await _audioService.initRecorder();
      await _audioService.startRecording();
      
      _isListening = true;
      notifyListeners();
    } catch (e) {
      _isListening = false;
      notifyListeners();
      _showErrorSnackbar(context, 'Gagal memulai rekaman: ${e.toString()}');
    }
  }

  Future<void> stopListening(String sessionId, SessionProvider sessionProvider) async {
    if (!_isListening) return;
    
    _isListening = false;
    _isLoading = true;
    notifyListeners();

    try {
      final recordingPath = await _audioService.stopRecording();
      if (recordingPath == null) {
        throw Exception('No recording path available');
      }

      final recordingFile = _audioService.getRecordingFile();
      if (recordingFile == null || !await recordingFile.exists()) {
        throw Exception('Recording file not found');
      }

      final audioMessage = ChatMessage(
        id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
        content: 'Mengolah pesan suara...',
        role: MessageRole.user,
        isAudio: true,
      );
      _addMessage(sessionId, audioMessage);

      final response = await _apiService.transcribeAudio(recordingFile, sessionId);
      final transcription = response['transcription'] as String;
      final aiResponse = response['ai_response'] as String;
      
      final index = messages.indexWhere((m) => m.id == audioMessage.id);
      if (index != -1) {
        messages[index] = messages[index].copyWith(content: transcription);
        notifyListeners();
      }

      await _addBotMessage(aiResponse, sessionId);
    } catch (e) {
      _addBotMessage("Gagal memproses rekaman suara: ${e.toString()}", sessionId);
      print('Error in stopListening: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void cancelListening() {
    _isListening = false;
    _audioService.stopRecording();
    notifyListeners();
  }

  void _addMessage(String sessionId, ChatMessage message) {
    messages.add(message);
    notifyListeners();
    _apiService.saveMessage(message, sessionId);
  }

  Future<void> pickImage(BuildContext context) async {
    try {
      final hasPermission = await PermissionService.hasStoragePermission();
      if (!hasPermission && await PermissionService.requestStoragePermission() == false) {
        if (context.mounted) {
          await PermissionService.showPermissionDialog(context, 'Penyimpanan');
        }
        return;
      }
      
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      
      if (pickedFile == null) return;
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      
      _pendingImage = savedImage;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Gambar telah dipilih. Silakan ketik pertanyaan Anda dan kirim.'),
                ),
                const SizedBox(width: 10),
                Image.file(
                  savedImage,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green[700],
          )
        );
      }
      
      notifyListeners();
    } catch (e) {
      print('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memilih gambar. Silakan coba lagi.'),
            duration: Duration(seconds: 3),
        ));
      }
    }
  }

  Future<void> deleteMessage(String messageId, String sessionId) async {
    try {
      // First delete from server
      await _apiService.deleteMessage(sessionId, messageId);
      
      // Then delete locally
      _messages.removeWhere((message) => message.id == messageId);
      notifyListeners();
      
    } catch (e) {
      print('Failed to delete message: $e');
      // Show error to user
      _messages.add(ChatMessage(
        content: 'Gagal menghapus pesan dari server. Silakan coba lagi.',
        role: MessageRole.assistant,
      ));
      notifyListeners();
    }
  }
  Future<void> saveMessageLocally(ChatMessage message, String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_${_deviceId}_$sessionId';
    
    List<String> messages = prefs.getStringList(key) ?? [];
    messages.add(jsonEncode({
      'id': message.id,
      'content': message.content,
      'role': message.role.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'imageUrl': message.imageUrl,
      'isAudio': message.isAudio,
    }));
    await prefs.setStringList(key, messages);
  }

  Future<List<ChatMessage>> getLocalMessages(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_${_deviceId}_$sessionId';
    
    List<String> messages = prefs.getStringList(key) ?? [];
    return messages.map((json) {
      final map = jsonDecode(json);
      return ChatMessage(
        id: map['id'],
        content: map['content'],
        role: map['role'] == 'MessageRole.user' ? MessageRole.user : MessageRole.assistant,
        imageUrl: map['imageUrl'],
        isAudio: map['isAudio'] ?? false,
      );
    }).toList();
  }

  @override
  void dispose() {
    _audioService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
