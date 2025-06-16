import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TutorialVideoScreen extends StatefulWidget {
  const TutorialVideoScreen({Key? key}) : super(key: key);

  @override
  State<TutorialVideoScreen> createState() => _TutorialVideoScreenState();
}

class _TutorialVideoScreenState extends State<TutorialVideoScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoFinished = false;
  Duration _currentPosition = Duration.zero;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset("assets/videos/tutorial.mp4")
      ..initialize().then((_) {
        setState(() {});
        _videoController.play();
        _videoController.addListener(() {
          final position = _videoController.value.position;
          final duration = _videoController.value.duration;
          setState(() {
            _currentPosition = position;
            if (position >= duration && !_isVideoFinished) {
              _isVideoFinished = true;
              _showControls = true;
              _hideTimer?.cancel();
            }
          });
        });
        _startHideTimer();
      });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isVideoFinished) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && !_isVideoFinished) {
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = _videoController.value.isInitialized
        ? _videoController.value.duration
        : Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // VIDEO
              _videoController.value.isInitialized
                  ? SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height,
                      child: VideoPlayer(_videoController),
                    )
                  : const Center(child: CircularProgressIndicator()),

              // SLIDER & DURASI
              if (_videoController.value.isInitialized && _showControls)
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          activeColor: Colors.green,
                          inactiveColor: Colors.grey[600],
                          min: 0,
                          max: totalDuration.inSeconds.toDouble(),
                          value: _currentPosition.inSeconds
                              .clamp(0, totalDuration.inSeconds)
                              .toDouble(),
                          onChanged: (value) {
                            final newPosition =
                                Duration(seconds: value.toInt());
                            _videoController.seekTo(newPosition);
                          },
                        ),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // TOMBOL PAUSE/PLAY
              if (_videoController.value.isInitialized &&
                  !_isVideoFinished &&
                  _showControls)
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 60,
                        icon: Icon(
                          _videoController.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_videoController.value.isPlaying) {
                              _videoController.pause();
                            } else {
                              _videoController.play();
                              _startHideTimer();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ),

              // TOMBOL BACK (lebih atas dan selalu putih)
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () {
                      _videoController.pause();
                      Navigator.of(context).pop();
                    },
                  ),
                ),

              // TOMBOL SELESAI
              if (_isVideoFinished)
                Positioned(
                  bottom: 140,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Selesai Menonton"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
