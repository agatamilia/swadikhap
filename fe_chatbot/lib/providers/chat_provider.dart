import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:peTaniku/services/device_service.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/permission_service.dart';
import '../services/image_service.dart';
import 'session_provider.dart';
import '../services/tts_service.dart';
import '../services/storage_service.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final ApiService _apiService = ApiService();
  final TTSService _ttsService = TTSService();
  final ImageService _imageService = ImageService();
  final ImagePicker _imagePicker = ImagePicker();
  final audioFile = File('path');
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  bool _isTranscribing = false;

  bool get isRecording => _isRecording;
  bool get isTranscribing => _isTranscribing;

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
  File? get selectedImage => _pendingImage;

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
    if (_currentSessionId == sessionId && _messages.isNotEmpty) {
      return;
    }
    
    _messages.clear();
    _currentSessionId = sessionId;
    _isLoading = true;
    notifyListeners();
    
    try {
      final localMessages = await StorageService.getMessages(sessionId, _deviceId);
      if (localMessages.isNotEmpty) {
        _messages.addAll(localMessages);
        _isLoading = false;
        notifyListeners();
      }
      
      try {
        final savedMessages = await _apiService.getMessages(sessionId, _deviceId);
        
        if (savedMessages.isNotEmpty) {
          _messages.clear();
          
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
          
          await StorageService.saveMessages(sessionId, _messages, _deviceId);
        } else if (_messages.isEmpty) {
          _addWelcomeMessage(sessionId);
        }
      } catch (e) {
        print('Error loading messages from API: $e');
        if (_messages.isEmpty) {
          _addWelcomeMessage(sessionId);
        }
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

    if (_messages.isEmpty) {
      final sessionName = text.isNotEmpty 
          ? (text.length > 30 ? '${text.substring(0, 30)}...' : text)
          : 'Analisis Gambar';
      try {
        await sessionProvider.renameSession(sessionProvider.currentSession!, sessionName);
      } catch (e) {
        print('Failed to update session name: $e');
      }
    }

    if (_pendingImage != null) {
      await _processImage(sessionId);
      return;
    }
    
    final userMessage = ChatMessage(
      content: text,
      role: MessageRole.user,
    );
    _messages.add(userMessage);
    notifyListeners();

    await StorageService.saveMessages(sessionId, _messages, _deviceId);

    try {
      await _apiService.saveMessage(userMessage, sessionId, _deviceId);
    } catch (e) {
      print('Failed to save message to API: $e');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.sendMessage(text, sessionId);
      await _addBotMessage(response['response'], sessionId);
    } catch (e) {
      print('Error sending message: $e');
      await _addBotMessage(_getErrorMessage(e), sessionId);
    }
  }

  Future<void> _processImage(String sessionId) async {
    if (_pendingImage == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _imageService.uploadAndAnalyzeImage(_pendingImage!, sessionId);
      await _addBotMessage(response['analysis'], sessionId);
      _pendingImage = null;
    } catch (e) {
      print('Error processing image: $e');
      await _addBotMessage('Error analyzing image: ${e.toString()}', sessionId);
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
      await _apiService.saveMessage(botMessage, sessionId, _deviceId);
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
      final recordingPath = await _audioService.startListening();
      if (recordingPath != null) {
        _isRecording = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error starting listening: $e');
    }
  }
  Future<void> stopListening(String sessionId, String deviceId) async {
    try {
      final recordingPath = await _audioService.stopRecording();
      if (recordingPath != null) {
        _isRecording = false;
        _isTranscribing = true;
        notifyListeners();

        final audioFile = File(recordingPath);
        await ApiService().transcribeAudio(audioFile, sessionId, deviceId);
        _isTranscribing = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error stopping listening: $e');
      _isTranscribing = false;
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
    StorageService.saveMessages(sessionId, _messages, _deviceId);
    _apiService.saveMessage(message, sessionId, _deviceId).catchError((e) {
      print('Failed to save message to API: $e');
    });
  }

  Future<void> pickImageFromGallery(BuildContext context) async {
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
          ),
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
          ),
        );
      }
    }
  }

  Future<void> pickImageFromCamera(BuildContext context) async {
    try {
      final hasPermission = await PermissionService.hasCameraPermission();
      if (!hasPermission && await PermissionService.requestCameraPermission() == false) {
        if (context.mounted) {
          await PermissionService.showPermissionDialog(context, 'Kamera');
        }
        return;
      }
      
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
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
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      print('Error taking picture: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil gambar. Silakan coba lagi.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
