import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String? _recordingPath;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  Future<void> initRecorder() async {
    if (_isRecorderInitialized) return;
    
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }
      
      // Open recorder
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
      print('Recorder initialized successfully');
    } catch (e) {
      print('Error initializing recorder: $e');
      _isRecorderInitialized = false;
      rethrow;
    }
  }

  Future<void> initPlayer() async {
    if (_isPlayerInitialized) return;
    
    try {
      await _player.openPlayer();
      _isPlayerInitialized = true;
      print('Player initialized successfully');
    } catch (e) {
      print('Error initializing player: $e');
      _isPlayerInitialized = false;
      rethrow;
    }
  }

  Future<void> startRecording() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }
    
    try {
      // Create temp directory for recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      print('Starting recording to: $_recordingPath');
      
      // Start recording
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        audioSource: AudioSource.microphone,
      );
      
      print('Recording started');
    } catch (e) {
      print('Error starting recording: $e');
      rethrow;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecorderInitialized || !_recorder.isRecording) {
      print('Recorder not initialized or not recording');
      return null;
    }
    
    try {
      print('Stopping recording');
      final path = await _recorder.stopRecorder();
      print('Recording stopped, file saved at: $path');
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  Future<void> playRecording(String path) async {
    if (!_isPlayerInitialized) {
      await initPlayer();
    }
    
    try {
      await _player.startPlayer(
        fromURI: path,
        codec: Codec.pcm16WAV,
      );
    } catch (e) {
      print('Error playing recording: $e');
      rethrow;
    }
  }

  Future<void> stopPlaying() async {
    if (!_isPlayerInitialized || !_player.isPlaying) return;
    
    try {
      await _player.stopPlayer();
    } catch (e) {
      print('Error stopping player: $e');
    }
  }

  File? getRecordingFile() {
    if (_recordingPath == null) return null;
    
    final file = File(_recordingPath!);
    if (!file.existsSync()) {
      print('Recording file does not exist: $_recordingPath');
      return null;
    }
    
    return file;
  }

  void dispose() {
    try {
      if (_isRecorderInitialized) {
        _recorder.closeRecorder();
      }
      if (_isPlayerInitialized) {
        _player.closePlayer();
      }
    } catch (e) {
      print('Error disposing audio service: $e');
    }
  }
}
