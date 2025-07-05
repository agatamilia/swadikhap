import 'dart:io' show File;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/device_service.dart';
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
  String get deviceId => _deviceId;

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
      final localMessages =
          await StorageService.getMessages(sessionId, _deviceId);
      if (localMessages.isNotEmpty) {
        _messages.addAll(localMessages);
        _isLoading = false;
        notifyListeners();
      }

      try {
        final savedMessages =
            await _apiService.getMessages(sessionId, _deviceId);

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
      content:
          "Welcome to PeTaniku! I'm ready to help with your agriculture-related questions.",
      role: MessageRole.assistant,
    ));
  }

  void _addConnectionErrorMessage() {
    _messages.add(ChatMessage(
      content:
          "I can't connect to the server right now. Some features may be limited. "
          "Your messages will be saved locally and will be synced when the connection is restored.",
      role: MessageRole.assistant,
    ));
  }

  void toggleVoiceOutput() {
    _useVoiceOutput = !_useVoiceOutput;

    if (!_useVoiceOutput) {
      _ttsService.stop();
    }

    notifyListeners();
  }

  Future<void> sendMessage(
    String text,
    String sessionId,
    SessionProvider sessionProvider, {
    VoidCallback? scrollToBottomCallback,
  }) async {
    if (text.isEmpty && !hasImagePending) return;

    if (_messages.isEmpty) {
      final sessionName = text.isNotEmpty
          ? (text.length > 30 ? '${text.substring(0, 30)}...' : text)
          : 'Image Analysis';
      try {
        await sessionProvider.renameSession(
            sessionProvider.currentSession!, sessionName);
      } catch (_) {}
    }

    if (_pendingImage != null) {
      // If there is an image
      final userImageMessage = ChatMessage(
        content: text,
        role: MessageRole.user,
        imageUrl: _pendingImage!.path,
      );
      _messages.add(userImageMessage);
      notifyListeners();
      scrollToBottomCallback?.call();

      await _apiService.saveMessage(userImageMessage, sessionId, _deviceId);
      await _processImage(sessionId); // will continue on its own
      return;
    }

    // If only text
    final userMessage = ChatMessage(
      content: text,
      role: MessageRole.user,
    );
    _messages.add(userMessage);
    notifyListeners();
    scrollToBottomCallback?.call();

    await StorageService.saveMessages(sessionId, _messages, _deviceId);
    await _apiService.saveMessage(userMessage, sessionId, _deviceId);

    _isLoading = true;
    notifyListeners();

    try {
      final last5BotMessages = _messages
          .where((m) => m.role == MessageRole.assistant)
          .toList()
          .reversed
          .take(5)
          .map((m) => m.content)
          .toList();

      final response = await _apiService.sendMessage(
        text,
        sessionId,
        _deviceId,
        previousBotReplies: last5BotMessages,
      );

      await _addBotMessage(response['response'], sessionId);
    } catch (e) {
      await _addBotMessage("An error occurred. Please try again.", sessionId);
    }
  }

  String _getErrorMessage(dynamic error) {
    return "An unexpected error occurred. Please try again.";
  }

  Future<void> _addBotMessage(String content, String sessionId) async {
    final botMessage = ChatMessage(
      content: content,
      cleanContent: content.replaceAll('*', ''),
      role: MessageRole.assistant,
    );

    _messages.add(botMessage);
    notifyListeners();

    try {
      await _apiService.saveMessage(botMessage, sessionId, _deviceId);
    } catch (e) {
      print('Failed to save bot message: $e');
    }

    _isLoading = false;

    if (_useVoiceOutput) {
      _speakText(botMessage.cleanContent ?? content);
    }
    notifyListeners();
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
      _isListening = true;
      notifyListeners();
      final recordingPath = await _audioService.startListening();
      if (recordingPath != null) {
        _isRecording = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error starting listening: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening(String sessionId, String deviceId) async {
    try {
      final recordingPath = await _audioService.stopRecording();
      if (recordingPath != null) {
        _isRecording = false;
        _isTranscribing = true;
        notifyListeners();

        // Add a temporary transcription bubble
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        final tempMessage = ChatMessage(
          id: tempId,
          content: "Processing audio...",
          role: MessageRole.user,
        );
        _messages.add(tempMessage);
        notifyListeners();

        // Send to Whisper
        final response =
            await _apiService.transcribeAudio(File(recordingPath), sessionId, deviceId);
        final transcription = response['transcription'];

        // Replace the temporary bubble's content with the transcription result
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: tempId,
            content: transcription,
            role: MessageRole.user,
          );
          notifyListeners();

          // Save to server
          await _apiService.saveMessage(_messages[index], sessionId, deviceId);
        }

        // Show loading animation
        _isLoading = true;
        notifyListeners();

        // Send to bot
        final last5BotMessages = _messages
            .where((m) => m.role == MessageRole.assistant)
            .toList()
            .reversed
            .take(5)
            .map((m) => m.content)
            .toList();

        final assistantResponse = await _apiService.sendMessage(
          transcription,
          sessionId,
          deviceId,
          previousBotReplies: last5BotMessages,
        );
        final assistantMessage = ChatMessage(
          content: assistantResponse['response'],
          role: MessageRole.assistant,
        );
        _messages.add(assistantMessage);
        notifyListeners();
        await _apiService.saveMessage(assistantMessage, sessionId, deviceId);
        if (_useVoiceOutput) {
          _speakText(assistantMessage.content);
        }
      }
    } catch (e) {
      print('Error stopping listening: $e');
      _messages.add(ChatMessage(
        content: "Failed to process voice recording: ${e.toString()}",
        role: MessageRole.assistant,
      ));
      notifyListeners();
    } finally {
      _isListening = false;
      _isTranscribing = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void cancelListening() {
    _isListening = false;
    _audioService.stopRecording();
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
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
      if (!hasPermission &&
          await PermissionService.requestStoragePermission() == false) {
        if (context.mounted) {
          await PermissionService.showPermissionDialog(context, 'Storage');
        }
        return;
      }

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: null,
      );

      if (pickedFile == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage =
          await File(pickedFile.path).copy('${appDir.path}/$fileName');

      _pendingImage = savedImage;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                      'Image selected. Please type your question and send.'),
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
            content: Text('Failed to select image. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> pickImageFromCamera(BuildContext context) async {
    try {
      final hasPermission = await PermissionService.hasCameraPermission();
      if (!hasPermission &&
          await PermissionService.requestCameraPermission() == false) {
        if (context.mounted) {
          await PermissionService.showPermissionDialog(context, 'Camera');
        }
        return;
      }

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: null,
      );

      if (pickedFile == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage =
          await File(pickedFile.path).copy('${appDir.path}/$fileName');

      _pendingImage = savedImage;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                      'Image selected. Please type your question and send.'),
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
            content: Text('Failed to take picture. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _processImage(String sessionId) async {
    if (_pendingImage == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Convert to .jpg if needed
      final jpgImage = await _convertToJpgIfNeeded(_pendingImage!);

      // Compress the image after ensuring it's a .jpg
      final compressed = await _compressImage(jpgImage);

      final start = DateTime.now(); // start time
      final response = await _imageService.uploadAndAnalyzeImage(
        compressed,
        sessionId,
        _deviceId,
      );
      final end = DateTime.now();
      print(
          "Image analysis time: ${end.difference(start).inMilliseconds} ms");

      final label = response['detected'];
      final confidence = response['confidence'];
      final explanation =
          response['explanation'] ?? "No disease found.";

      String messageText = (label != null)
          ? "Detection: *$label* ($confidence%)\n\n$explanation"
          : explanation;

      if (response.containsKey("image_url")) {
        final botMessage = ChatMessage(
          content: messageText,
          role: MessageRole.assistant,
          imageUrl: response["image_url"],
        );
        _messages.add(botMessage);
        notifyListeners();
        await _apiService.saveMessage(botMessage, sessionId, _deviceId);

        if (_useVoiceOutput) {
          _speakText(botMessage.content);
        }
      } else {
        await _addBotMessage(messageText, sessionId);
      }

      _pendingImage = null;
    } catch (e) {
      print('Error processing image: $e');
      await _addBotMessage('Error analyzing image: ${e.toString()}', sessionId);
      _pendingImage = null;
    } finally {
      _pendingImage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<File> _convertToJpgIfNeeded(File imageFile) async {
    final originalPath = imageFile.path;

    // If it's already .jpg or .jpeg, return directly
    if (originalPath.endsWith('.jpg') || originalPath.endsWith('.jpeg')) {
      return imageFile;
    }

    // Change extension to .jpg
    final newPath = path.setExtension(originalPath, '.jpg');
    final renamedFile = await imageFile.copy(newPath);
    return renamedFile;
  }

  Future<File> _compressImage(File file) async {
    final targetPath =
        '${file.parent.path}/compressed_${path.basename(file.path)}';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // change as needed
    );

    if (result != null) {
      return File(result.path);
    }
    // If compression fails, return the original file
    return file;
  }

  void addLocalImageMessage(File image, String text) {
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      role: MessageRole.user,
      imageUrl: image.path,
    );

    _messages.add(newMessage);
    notifyListeners();
  }

  @override
  void dispose() {
    _audioService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}