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
        throw Exception('Izin mikrofon tidak diberikan');
      }
      
      _isRecorderInitialized = true;
      debugPrint('Perekam berhasil diinisialisasi');
    } catch (e) {
      debugPrint('Kesalahan saat menginisialisasi perekam: $e');
      rethrow;
    }
  }

  Future<void> initPlayer() async {
    if (_isPlayerInitialized) return;
    
    try {
      _isPlayerInitialized = true;
      debugPrint('Pemutar berhasil diinisialisasi');
    } catch (e) {
      debugPrint('Kesalahan saat menginisialisasi pemutar: $e');
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
        encoder: AudioEncoder.wav,  // Format WAV works best with Whisper
        bitRate: 128000,
        samplingRate: 16000,  // 16kHz is optimal for Whisper
      );
      
      debugPrint('Perekaman dimulai di: $_recordingPath');
      return _recordingPath;
    } catch (e) {
      debugPrint('Kesalahan saat memulai perekaman: $e');
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
      debugPrint('Perekaman dihentikan');
      
      // Verify the file exists and has content
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('Ukuran file perekaman: $fileSize bytes');
          
          if (fileSize < 100) {
            throw Exception('File perekaman terlalu kecil, mungkin rusak');
          }
        } else {
          throw Exception('File perekaman tidak ada');
        }
      }
      
      return _recordingPath;
    } catch (e) {
      debugPrint('Kesalahan saat menghentikan perekaman: $e');
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
      debugPrint('Kesalahan saat memutar rekaman: $e');
    }
  }

  Future<void> dispose() async {
    await _audioRecorder.dispose();
    await _player.dispose();
  }
}
