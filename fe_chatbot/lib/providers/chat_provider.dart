import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import '../services/storage_service.dart';
import 'session_provider.dart';
import '../services/tts_service.dart';
import '../services/device_service.dart';
import '../widgets/voice_input_overlay.dart';

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
  bool _isRecordingHeld = false;
  DateTime? _recordingStartTime;
  String _recordingTime = "0:00";
  Timer? _recordingTimer;
  VoiceRecordingState _recordingState = VoiceRecordingState.recording;
  bool _isRecordingPaused = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  bool get useVoiceOutput => _useVoiceOutput;
  bool get hasImagePending => _pendingImage != null;
  bool get isRecordingHeld => _isRecordingHeld;
  String get recordingTime => _recordingTime;
  VoiceRecordingState get recordingState => _recordingState;

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
      // If we're already showing messages for this session, don't reload
      return;
    }
    
    // Clear messages when switching sessions
    _messages.clear();
    _currentSessionId = sessionId;
    _isLoading = true;
    notifyListeners();
    
    try {
      // First try to load from local storage
      final localMessages = await StorageService.getMessages(sessionId, _deviceId);
      if (localMessages.isNotEmpty) {
        _messages.addAll(localMessages);
        _isLoading = false;
        notifyListeners();
      }
      
      // Then try to fetch from API
      try {
        final savedMessages = await _apiService.getMessages(sessionId, _deviceId);
        
        if (savedMessages.isNotEmpty) {
          // Clear local messages to avoid duplicates
          _messages.clear();
          
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
          
          // Save to local storage
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
    
    // Save welcome message to local storage
    StorageService.saveMessages(sessionId, _messages, _deviceId);
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

    // If this is the first message, set session name
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

    // Process image if there's a pending image
    if (_pendingImage != null) {
      await _processImage(sessionId, text);
      return;
    }
    
    // For text-only messages
    final userMessage = ChatMessage(
      content: text,
      role: MessageRole.user,
    );
    _messages.add(userMessage);
    notifyListeners();

    // Save to local storage
    await StorageService.saveMessages(sessionId, _messages, _deviceId);

    try {
      await _apiService.saveMessage(userMessage, sessionId, _deviceId);
    } catch (e) {
      print('Failed to save message to API: $e');
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

  // Update the _processImage method to properly handle image conversion and base64 encoding

Future<void> _processImage(String sessionId, String prompt) async {
  if (_pendingImage == null) return;
  
  _isLoading = true;
  notifyListeners();
  
  try {
    print('Processing image: ${_pendingImage!.path}');
    
    // First, add the user message with the image
    final userMessage = ChatMessage(
      content: prompt.isNotEmpty ? prompt : "Analisis gambar tanaman ini",
      role: MessageRole.user,
      imageUrl: _pendingImage!.path,
    );
    
    _messages.add(userMessage);
    notifyListeners();
    
    // Save to local storage
    await StorageService.saveMessages(sessionId, _messages, _deviceId);
    
    try {
      await _apiService.saveMessage(userMessage, sessionId, _deviceId);
    } catch (e) {
      print('Failed to save user message with image to API: $e');
    }
    
    // Properly convert and compress the image before sending
    File imageToSend = _pendingImage!;
    
    try {
      // Use the ImageService to properly compress and convert the image
      final imageService = ImageService();
      imageToSend = await imageService.compressImage(_pendingImage!);
      
      print('Successfully compressed image: ${imageToSend.path}');
    } catch (e) {
      print('Error compressing image: $e');
      // Continue with original image if compression fails
    }
    
    // Then send the image for analysis
    print('Sending image for analysis, session: $sessionId, device: $_deviceId');
    
    final response = await _apiService.analyzeImage(
      imageToSend, 
      sessionId, 
      _deviceId,
      prompt: prompt.isNotEmpty ? prompt : null,
    );
    
    print('Image analysis response: $response');
    
    if (response.containsKey('error') && response['error'] != null) {
      print('Error in image analysis: ${response['error']}');
      throw Exception(response['error']);
    }
    
    // Update the user message with the server image path if available
    if (response.containsKey('image_path') && response['image_path'] != null) {
      final lastIndex = _messages.length - 1;
      _messages[lastIndex] = _messages[lastIndex].copyWith(
        imageUrl: response['image_path'],
      );
      notifyListeners();
      
      // Update in local storage
      await StorageService.saveMessages(sessionId, _messages, _deviceId);
    }
    
    // Add the bot response
    final analysis = response['analysis'] ?? 'Tidak dapat menganalisis gambar.';
    await _addBotMessage(analysis, sessionId);
    
    _pendingImage = null;
  } catch (e) {
    print('Error processing image: $e');
    await _addBotMessage(
      'Gagal menganalisis gambar. Silakan coba lagi nanti.',
      sessionId,
    );
    _pendingImage = null;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  String _getErrorMessage(dynamic error) {
    return "Terjadi kesalahan. Silakan coba lagi.";
  }

  Future<void> _addBotMessage(String content, String sessionId) async {
    // Filter out the "maaf saya hanya dapat membantu terkait pertanian" message
    if (content.contains("Maaf, saya hanya dapat membantu tentang pertanian")) {
      // Replace with a more generic response
      content = "Silakan tanyakan tentang pertanian, tanaman, atau cuaca untuk pertanian.";
    }
    
    final cleanContent = content.replaceAll('*', '');
    final botMessage = ChatMessage(
      content: content,
      cleanContent: cleanContent,
      role: MessageRole.assistant,
    );
    
    _messages.add(botMessage);
    
    // Save to local storage
    await StorageService.saveMessages(sessionId, _messages, _deviceId);
    
    try {
      await _apiService.saveMessage(botMessage, sessionId, _deviceId);
    } catch (e) {
      print('Failed to save bot message to API: $e');
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

  void _startRecordingTimer() {
    int seconds = 0;
    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      seconds++;
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      _recordingTime = '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
      notifyListeners();
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingTime = "0:00";
  }

  // Start recording when button is pressed
  Future<void> startRecordingHold(BuildContext context) async {
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
      _isRecordingHeld = true;
      _recordingStartTime = DateTime.now();
      _recordingState = VoiceRecordingState.recording;
      _startRecordingTimer();
      notifyListeners();
    } catch (e) {
      _isListening = false;
      _isRecordingHeld = false;
      notifyListeners();
      _showErrorSnackbar(context, 'Gagal memulai rekaman: ${e.toString()}');
    }
  }

  void lockRecording() {
    if (!_isRecordingHeld) return;
    
    _recordingState = VoiceRecordingState.locked;
    notifyListeners();
  }

  void pauseRecording() {
    if (_recordingState != VoiceRecordingState.locked) return;
    
    _audioService.pauseRecording();
    _recordingState = VoiceRecordingState.paused;
    _recordingTimer?.cancel();
    notifyListeners();
  }

  void resumeRecording() {
    if (_recordingState != VoiceRecordingState.paused) return;
    
    _audioService.resumeRecording();
    _recordingState = VoiceRecordingState.locked;
    _startRecordingTimer();
    notifyListeners();
  }

  // Cancel recording when swiped to cancel
  void cancelRecordingHold() {
    if (!_isRecordingHeld) return;
    
    _isListening = false;
    _isRecordingHeld = false;
    _stopRecordingTimer();
    _recordingState = VoiceRecordingState.recording;
    _audioService.stopRecording();
    notifyListeners();
  }

  Future<void> stopRecordingHold(String sessionId, SessionProvider sessionProvider) async {
    if (!_isRecordingHeld) return;
    
    _isRecordingHeld = false;
    _stopRecordingTimer();
    
    // Check if recording was too short (less than 1 second)
    final now = DateTime.now();
    final recordingDuration = now.difference(_recordingStartTime ?? now);
    if (recordingDuration.inMilliseconds < 500) {
      // Cancel recording if it was too short
      _isListening = false;
      _audioService.stopRecording();
      notifyListeners();
      return;
    }
    
    _isListening = false;
    _isLoading = true;
    notifyListeners();

    try {
      print('Stopping recording for session: $sessionId');
      final recordingPath = await _audioService.stopRecording();
      
      if (recordingPath == null) {
        print('No recording path available, trying to get from audio service');
        final recordingFile = _audioService.getRecordingFile();
        if (recordingFile == null) {
          throw Exception('No recording file available');
        }
        
        await _processAudioFile(recordingFile, sessionId, sessionProvider);
      } else {
        final recordingFile = File(recordingPath);
        if (!await recordingFile.exists()) {
          throw Exception('Recording file not found at path: $recordingPath');
        }
        
        await _processAudioFile(recordingFile, sessionId, sessionProvider);
      }
    } catch (e) {
      print('Error in stopRecordingHold: $e');
      await _addBotMessage("Maaf, saya tidak dapat memproses pesan suara Anda. Silakan coba lagi.", sessionId);
    } finally {
      _isLoading = false;
      _recordingState = VoiceRecordingState.recording;
      notifyListeners();
    }
  }

  Future<void> _processAudioFile(File audioFile, String sessionId, SessionProvider sessionProvider) async {
    print('Processing audio file: ${audioFile.path}');
    
    // Verify the audio file exists and has content
    if (!await audioFile.exists()) {
      print('Audio file does not exist: ${audioFile.path}');
      throw Exception('Audio file does not exist');
    }
    
    final fileSize = await audioFile.length();
    print('Audio file size: $fileSize bytes');
    
    if (fileSize == 0) {
      print('Audio file is empty (0 bytes)');
      throw Exception('Audio file is empty');
    }
    
    // Create a copy of the audio file in a known location
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      final copiedFile = await audioFile.copy(targetPath);
      
      print('Copied audio file to: ${copiedFile.path}');
      print('Copied file size: ${await copiedFile.length()} bytes');
      
      // Use the copied file for processing
      audioFile = copiedFile;
    } catch (e) {
      print('Error copying audio file: $e');
      // Continue with original file if copying fails
    }
    
    final audioMessage = ChatMessage(
      id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Mengolah pesan suara...',
      role: MessageRole.user,
      isAudio: true,
      audioUrl: audioFile.path,
    );
    
    _addMessage(sessionId, audioMessage);

    print('Sending audio for transcription, session: $sessionId, device: $_deviceId');
    print('Transcribing audio file: ${audioFile.path}');
    print('Session ID: $sessionId, Device ID: $_deviceId');
    print('Audio file size: ${await audioFile.length()} bytes');
    
    final response = await _apiService.transcribeAudio(audioFile, sessionId, _deviceId);
    print('Transcription response: $response');
    
    String transcription = 'Tidak dapat mengenali suara';
    String aiResponse = 'Maaf, saya tidak dapat memproses pesan suara Anda saat ini.';
    
    if (response.containsKey('transcription') && response['transcription'] != null) {
      transcription = response['transcription'] as String;
      
      // If transcription is "Pesan suara kosong", provide a better message
      if (transcription == "Pesan suara kosong") {
        transcription = "Saya tidak mendengar apa-apa. Silakan coba lagi.";
      }
    }
    
    if (response.containsKey('ai_response') && response['ai_response'] != null) {
      aiResponse = response['ai_response'] as String;
      
      // Filter out the "maaf saya hanya dapat membantu terkait pertanian" message
      if (aiResponse.contains("Maaf, saya hanya dapat membantu tentang pertanian")) {
        // Replace with a more generic response
        aiResponse = "Silakan tanyakan tentang pertanian, tanaman, atau cuaca untuk pertanian.";
      }
    }
    
    final index = messages.indexWhere((m) => m.id == audioMessage.id);
    if (index != -1) {
      messages[index] = messages[index].copyWith(content: transcription);
      // Save to local storage
      await StorageService.saveMessages(sessionId, _messages, _deviceId);
      notifyListeners();
    }

    await _addBotMessage(aiResponse, sessionId);
  }

  // Cancel recording when button press is canceled
  void cancelListening() {
    _isListening = false;
    _stopRecordingTimer();
    _recordingState = VoiceRecordingState.recording;
    _audioService.stopRecording();
    notifyListeners();
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
      _recordingState = VoiceRecordingState.recording;
      _startRecordingTimer();
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
    _stopRecordingTimer();
    notifyListeners();

    try {
      final recordingPath = await _audioService.stopRecording();
      if (recordingPath == null) {
        throw Exception('No recording path available');
      }

      final recordingFile = File(recordingPath);
      if (!await recordingFile.exists()) {
        throw Exception('Recording file not found');
      }

      await _processAudioFile(recordingFile, sessionId, sessionProvider);
    } catch (e) {
      _addBotMessage("Gagal memproses rekaman suara: ${e.toString()}", sessionId);
      print('Error in stopListening: $e');
    } finally {
      _isLoading = false;
      _recordingState = VoiceRecordingState.recording;
      notifyListeners();
    }
  }

  void _addMessage(String sessionId, ChatMessage message) {
    messages.add(message);
    notifyListeners();
    
    // Save to local storage
    StorageService.saveMessages(sessionId, _messages, _deviceId);
    
    // Try to save to API
    _apiService.saveMessage(message, sessionId, _deviceId).catchError((e) {
      print('Failed to save message to API: $e');
    });
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
          )
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
        ));
      }
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _ttsService.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }
}
