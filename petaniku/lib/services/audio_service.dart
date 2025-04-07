import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  // Use the Record class directly from the package
  final _audioRecorder = Record();
  final AudioPlayer _player = AudioPlayer();
  String? _recordingPath;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  Future<void> initRecorder() async {
    if (_isRecorderInitialized) return;
    
    try {
      // Check microphone permission using permission_handler
      final status = await Permission.microphone.status;
      final isGranted = status.isGranted;
      
      if (!isGranted) {
        throw Exception('Microphone permission not granted');
      }
      
      _isRecorderInitialized = true;
      debugPrint('Recorder initialized successfully');
    } catch (e) {
      debugPrint('Error initializing recorder: $e');
      rethrow;
    }
  }

  Future<void> initPlayer() async {
    if (_isPlayerInitialized) return;
    
    try {
      _isPlayerInitialized = true;
      debugPrint('Player initialized successfully');
    } catch (e) {
      debugPrint('Error initializing player: $e');
      rethrow;
    }
  }

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  Future<String?> startRecording() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }
    
    try {
      // Get temp directory for saving the audio file
      final Directory tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      // Start recording with the correct API for record package
      await _audioRecorder.start(
        path: _recordingPath,
        encoder: AudioEncoder.wav,  // WAV format works best with Whisper
        bitRate: 128000,
        samplingRate: 16000,  // 16kHz is optimal for Whisper
      );
      
      debugPrint('Recording started at: $_recordingPath');
      return _recordingPath;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _recordingPath = null;
      rethrow;
    }
  }

  Future<String?> stopRecording() async {
    if (!await _audioRecorder.isRecording()) {
      return _recordingPath;
    }
    
    try {
      await _audioRecorder.stop();
      debugPrint('Recording stopped');
      
      // Verify the file exists and has content
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('Recording file size: $fileSize bytes');
          
          if (fileSize < 100) {
            throw Exception('Recording file is too small, possibly corrupted');
          }
        } else {
          throw Exception('Recording file does not exist');
        }
      }
      
      return _recordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      rethrow;
    }
  }

  File? getRecordingFile() {
    if (_recordingPath == null) return null;
    return File(_recordingPath!);
  }

  Future<void> playRecording() async {
    if (_recordingPath == null) return;
    
    try {
      await _player.play(DeviceFileSource(_recordingPath!));
    } catch (e) {
      debugPrint('Error playing recording: $e');
    }
  }

  Future<void> dispose() async {
    await _audioRecorder.dispose();
    await _player.dispose();
  }
}

