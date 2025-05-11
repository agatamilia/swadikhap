// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_sound/public/flutter_sound_player.dart';
// import 'package:flutter_sound/public/flutter_sound_recorder.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_sound/flutter_sound.dart';

// class AudioService {
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   final FlutterSoundPlayer _player = FlutterSoundPlayer();
//   String? _recordingPath;
//   bool _isRecorderInitialized = false;
//   bool _isPlayerInitialized = false;
//   bool _isPaused = false;
//   bool _isRecording = false;
//   bool _isPlaying = false;
//   Duration _recordingDuration = Duration.zero;
//   Timer? _recordingTimer;
//   StreamSubscription<RecordingDisposition>? _recordingSubscription;

//   // Initialize the audio recorder
//   Future<void> initRecorder() async {
//     if (_isRecorderInitialized) return;
    
//     try {
//       final status = await Permission.microphone.request();
//       if (status != PermissionStatus.granted) {
//         throw Exception('Microphone permission not granted');
//       }
      
//       await _recorder.openRecorder();
//       _isRecorderInitialized = true;
//       debugPrint('Recorder initialized successfully');
//     } catch (e) {
//       debugPrint('Error initializing recorder: $e');
//       _isRecorderInitialized = false;
//       rethrow;
//     }
//   }

//   // Initialize the audio player
//   Future<void> initPlayer() async {
//     if (_isPlayerInitialized) return;
    
//     try {
//       await _player.openPlayer();
//       _isPlayerInitialized = true;
//       debugPrint('Player initialized successfully');
//     } catch (e) {
//       debugPrint('Error initializing player: $e');
//       _isPlayerInitialized = false;
//       rethrow;
//     }
//   }

//   // Start a new recording
//   Future<String?> startRecording() async {
//     if (!_isRecorderInitialized) {
//       await initRecorder();
//     }
    
//     try {
//       final tempDir = await getTemporaryDirectory();
//       _recordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
//       await _recorder.startRecorder(
//         toFile: _recordingPath,
//         codec: Codec.pcm16WAV,
//         sampleRate: 16000,
//       );
      
//       _isRecording = true;
//       _isPaused = false;
//       _recordingDuration = Duration.zero;
      
//       // Start tracking recording duration
//       _recordingSubscription = _recorder.onProgress?.listen((disposition) {
//         _recordingDuration = disposition.duration;
//       });
      
//       debugPrint('Recording started at: $_recordingPath');
//       return _recordingPath;
//     } catch (e) {
//       debugPrint('Error starting recording: $e');
//       _isRecording = false;
//       _recordingPath = null;
//       _stopDurationTracking();
//       rethrow;
//     }
//   }

//   // Pause the current recording
//   Future<void> pauseRecording() async {
//     if (!_isRecording || _isPaused || !_isRecorderInitialized) return;
    
//     try {
//       await _recorder.pauseRecorder();
//       _isPaused = true;
//       _stopDurationTracking();
//       debugPrint('Recording paused');
//     } catch (e) {
//       debugPrint('Error pausing recording: $e');
//       rethrow;
//     }
//   }

//   // Resume a paused recording
//   Future<void> resumeRecording() async {
//     if (!_isRecording || !_isPaused || !_isRecorderInitialized) return;
    
//     try {
//       await _recorder.resumeRecorder();
//       _isPaused = false;
      
//       // Resume tracking recording duration
//       _recordingSubscription = _recorder.onProgress?.listen((disposition) {
//         _recordingDuration = disposition.duration;
//       });
      
//       debugPrint('Recording resumed');
//     } catch (e) {
//       debugPrint('Error resuming recording: $e');
//       rethrow;
//     }
//   }

//   // Stop the current recording
//   Future<String?> stopRecording() async {
//     if (!_isRecording || !_isRecorderInitialized) {
//       debugPrint('Recorder not initialized or not recording');
//       return _recordingPath;
//     }
    
//     try {
//       final path = await _recorder.stopRecorder();
//       _isRecording = false;
//       _isPaused = false;
//       _stopDurationTracking();
      
//       // Verify the file exists and has content
//       final file = File(path ?? _recordingPath ?? '');
//       if (await file.exists()) {
//         final size = await file.length();
//         debugPrint('Recording file size: $size bytes');
//         if (size == 0) {
//           debugPrint('Warning: Recording file is empty (0 bytes)');
//         }
//       } else {
//         debugPrint('Warning: Recording file does not exist: $path');
//       }
      
//       debugPrint('Recording stopped, duration: $_recordingDuration, file saved at: ${path ?? _recordingPath}');
//       return path ?? _recordingPath;
//     } catch (e) {
//       debugPrint('Error stopping recording: $e');
//       _isRecording = false;
//       _isPaused = false;
//       _stopDurationTracking();
//       rethrow;
//     }
//   }

//   // Play the recorded audio
//   Future<void> playRecording(String filePath) async {
//     if (!_isPlayerInitialized) {
//       await initPlayer();
//     }
    
//     try {
//       await _player.startPlayer(
//         fromURI: filePath,
//         codec: Codec.pcm16WAV,
//         whenFinished: () {
//           _isPlaying = false;
//           debugPrint('Playback finished');
//         },
//       );
//       _isPlaying = true;
//       debugPrint('Playback started');
//     } catch (e) {
//       debugPrint('Error playing recording: $e');
//       _isPlaying = false;
//       rethrow;
//     }
//   }

//   // Stop playback
//   Future<void> stopPlayback() async {
//     if (!_isPlaying || !_isPlayerInitialized) return;
    
//     try {
//       await _player.stopPlayer();
//       _isPlaying = false;
//       debugPrint('Playback stopped');
//     } catch (e) {
//       debugPrint('Error stopping playback: $e');
//       rethrow;
//     }
//   }

//   // Pause playback
//   Future<void> pausePlayback() async {
//     if (!_isPlaying || !_isPlayerInitialized) return;
    
//     try {
//       await _player.pausePlayer();
//       _isPlaying = false;
//       debugPrint('Playback paused');
//     } catch (e) {
//       debugPrint('Error pausing playback: $e');
//       rethrow;
//     }
//   }

//   // Resume playback
//   Future<void> resumePlayback() async {
//     if (_isPlaying || !_isPlayerInitialized) return;
    
//     try {
//       await _player.resumePlayer();
//       _isPlaying = true;
//       debugPrint('Playback resumed');
//     } catch (e) {
//       debugPrint('Error resuming playback: $e');
//       rethrow;
//     }
//   }

//   // Get the current recording duration
//   Duration get currentDuration => _recordingDuration;

//   // Stop duration tracking
//   void _stopDurationTracking() {
//     _recordingSubscription?.cancel();
//     _recordingSubscription = null;
//     _recordingTimer?.cancel();
//     _recordingTimer = null;
//   }

//   // Clean up resources
//   Future<void> dispose() async {
//     try {
//       if (_isRecording) {
//         await stopRecording();
//       }
//       if (_isPlaying) {
//         await stopPlayback();
//       }
//       _stopDurationTracking();
//       await _recorder.closeRecorder();
//       await _player.closePlayer();
//       _isRecorderInitialized = false;
//       _isPlayerInitialized = false;
//       debugPrint('AudioService disposed');
//     } catch (e) {
//       debugPrint('Error disposing AudioService: $e');
//       rethrow;
//     }
//   }

//   // Getters for state information
//   bool get isRecording => _isRecording;
//   bool get isPaused => _isPaused;
//   bool get isPlaying => _isPlaying;
//   String? get recordingPath => _recordingPath;
// }
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
  bool _isPaused = false;

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
      
      // Make sure the directory exists
      final recordingFile = File(_recordingPath!);
      if (!await recordingFile.parent.exists()) {
        await recordingFile.parent.create(recursive: true);
      }
      
      // Start recording
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        audioSource: AudioSource.microphone,
      );
      
      _isPaused = false;
      print('Recording started');
    } catch (e) {
      print('Error starting recording: $e');
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    if (!_isRecorderInitialized || !_recorder.isRecording || _isPaused) {
      return;
    }
    
    try {
      await _recorder.pauseRecorder();
      _isPaused = true;
      print('Recording paused');
    } catch (e) {
      print('Error pausing recording: $e');
    }
  }

  Future<void> resumeRecording() async {
    if (!_isRecorderInitialized || !_isPaused) {
      return;
    }
    
    try {
      await _recorder.resumeRecorder();
      _isPaused = false;
      print('Recording resumed');
    } catch (e) {
      print('Error resuming recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecorderInitialized) {
      print('Recorder not initialized');
      return null;
    }
    
    if (_isPaused) {
      await resumeRecording();
    }
    
    if (!_recorder.isRecording) {
      print('Recorder is not recording');
      return _recordingPath; // Return the path if we have it, even if not recording
    }
    
    try {
      print('Stopping recording');
      final path = await _recorder.stopRecorder();
      print('Recording stopped, file saved at: $path');
      
      // Verify the file exists and has content
      final file = File(path ?? _recordingPath ?? '');
      if (await file.exists()) {
        final size = await file.length();
        print('Recording file size: $size bytes');
        if (size == 0) {
          print('Warning: Recording file is empty (0 bytes)');
        }
      } else {
        print('Warning: Recording file does not exist: $path');
      }
      
      return path ?? _recordingPath;
    } catch (e) {
      print('Error stopping recording: $e');
      return _recordingPath; // Return the path we have even if stopping failed
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
    if (_recordingPath == null) {
      print('No recording path available');
      return null;
    }
    
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
