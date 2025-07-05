import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

class AudioService {
  final _audioRecorder = Record();
  final AudioPlayer _player = AudioPlayer();
  String? _recordingPath;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  // Mendapatkan direktori sementara yang valid
  Future<String> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final tempFolderPath = path.join(tempDir.path, 'audio_files');
    await Directory(tempFolderPath).create(recursive: true);  // Membuat folder jika tidak ada
    return tempFolderPath;
  }

  // Inisialisasi perekam
  Future<void> initRecorder() async {
    if (_isRecorderInitialized) return;

    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        throw Exception('Izin mikrofon tidak diberikan');
      }
      _isRecorderInitialized = true;
      debugPrint('Perekam berhasil diinisialisasi');
    } catch (e) {
      debugPrint('Kesalahan saat menginisialisasi perekam: $e');
      rethrow;
    }
  }

  // Inisialisasi pemutar audio
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

  // Memulai perekaman
  Future<String?> startListening() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }

    try {
      final tempDir = await getTempDirectory();  // Mendapatkan folder sementara
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      _recordingPath = path.join(tempDir, fileName); // Path file audio

      await _audioRecorder.start(
        path: _recordingPath,
        encoder: AudioEncoder.wav, // Format WAV
        bitRate: 128000,
        samplingRate: 16000, // 16kHz untuk hasil terbaik
      );

      debugPrint('Perekaman dimulai di: $_recordingPath');
      return _recordingPath;
    } catch (e) {
      debugPrint('Kesalahan saat memulai perekaman: $e');
      _recordingPath = null;
      return null;
    }
  }

  // Menghentikan perekaman
  Future<String?> stopRecording() async {
    if (!await _audioRecorder.isRecording()) return _recordingPath;

    try {
      await _audioRecorder.stop();
      debugPrint('Perekaman dihentikan');

      // Verifikasi file audio ada
      final file = File(_recordingPath!);
      if (await file.exists()) {
        final fileSize = await file.length();
        debugPrint('Ukuran file perekaman: $fileSize bytes');

        if (fileSize < 100) {
          throw Exception('File perekaman terlalu kecil, mungkin rusak');
        }
      } else {
        throw Exception('File perekaman tidak ditemukan');
      }

      return _recordingPath;
    } catch (e) {
      debugPrint('Kesalahan saat menghentikan perekaman: $e');
      return null;
    }
  }
  Future<void> startRecordingWithTimeout({Duration maxDuration = const Duration(seconds: 60)}) async {
    await startListening();
    Future.delayed(maxDuration, () async {
      if (await _audioRecorder.isRecording()) {
        await stopRecording();
      }
    });
  }

  // Mendapatkan file rekaman
  File? getRecordingFile() {
    if (_recordingPath == null) return null;
    return File(_recordingPath!);
  }

  // Memutar rekaman
  Future<void> playRecording() async {
    if (_recordingPath == null) return;

    try {
      await _player.play(DeviceFileSource(_recordingPath!));
    } catch (e) {
      debugPrint('Kesalahan saat memutar rekaman: $e');
    }
  }

  // Menutup recorder dan player
  Future<void> dispose() async {
    await _audioRecorder.dispose();
    await _player.dispose();
  }
}
