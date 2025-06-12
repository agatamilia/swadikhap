import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'permission_service.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  String? _recordingPath;

  // Inisialisasi perekam
  Future<void> initRecorder() async {
    if (!_isRecorderInitialized) {
      print('Memulai inisialisasi perekam audio');
      bool hasPermission = await PermissionService.hasMicrophonePermission();
      
      if (!hasPermission) {
        print('Meminta izin mikrofon');
        hasPermission = await PermissionService.requestMicrophonePermission();
        if (!hasPermission) {
          print('Izin mikrofon ditolak');
          throw Exception('Izin mikrofon tidak diberikan');
        }
      }
      
      print('Membuka perekam');
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
      print('Perekam berhasil diinisialisasi');
    }
  }

  // Inisialisasi pemutar
  Future<void> initPlayer() async {
    if (!_isPlayerInitialized) {
      print('Memulai inisialisasi pemutar audio');
      await _player.openPlayer();
      _isPlayerInitialized = true;
      print('Pemutar berhasil diinisialisasi');
    }
  }

  // Mulai merekam
  Future<void> startRecording() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }
    
    Directory tempDir = await getTemporaryDirectory();
    _recordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    
    await _recorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );
  }

  // Hentikan perekaman
  Future<String?> stopRecording() async {
    if (_recorder.isRecording) {
      print('Menghentikan perekaman');
      await _recorder.stopRecorder();
      print('Perekaman dihentikan, file disimpan di: $_recordingPath');
      return _recordingPath;
    }
    print('Tidak sedang merekam, tidak ada yang dihentikan');
    return null;
  }

  // Cek apakah sedang merekam
  bool isRecording() {
    return _recorder.isRecording;
  }

  // Putar rekaman
  Future<void> playRecording() async {
    if (!_isPlayerInitialized) {
      print('Inisialisasi pemutar sebelum pemutaran');
      await initPlayer();
    }
    
    if (_recordingPath != null) {
      print('Memutar rekaman dari: $_recordingPath');
      await _player.startPlayer(
        fromURI: _recordingPath,
        codec: Codec.pcm16WAV,
      );
      print('Pemutaran dimulai');
    } else {
      print('Tidak ada rekaman untuk diputar');
    }
  }

  // Hentikan pemutaran
  Future<void> stopPlaying() async {
    if (_player.isPlaying) {
      print('Menghentikan pemutaran');
      await _player.stopPlayer();
      print('Pemutaran dihentikan');
    }
  }

  // Ambil file rekaman
  File? getRecordingFile() {
    if (_recordingPath != null) {
      print('Mengambil file rekaman: $_recordingPath');
      return File(_recordingPath!);
    }
    print('Tidak ada file rekaman yang tersedia');
    return null;
  }

  // Melepas sumber daya
  Future<void> dispose() async {
    print('Melepas sumber daya audio');
    if (_isRecorderInitialized) {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
      print('Perekam dilepas');
    }
    
    if (_isPlayerInitialized) {
      await _player.closePlayer();
      _isPlayerInitialized = false;
      print('Pemutar dilepas');
    }
    print('Sumber daya audio telah dilepas');
  }
}
