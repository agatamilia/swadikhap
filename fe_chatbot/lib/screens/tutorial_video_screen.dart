import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';

class TutorialVideoScreen extends StatefulWidget {
  const TutorialVideoScreen({Key? key}) : super(key: key);

  @override
  State<TutorialVideoScreen> createState() => _TutorialVideoScreenState();
}

class _TutorialVideoScreenState extends State<TutorialVideoScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoFinished = false;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset("assets/videos/tutorial.mp4")
      ..initialize().then((_) {
        setState(() {});
        _videoController.play();

        // Listen untuk posisi dan status akhir
        _videoController.addListener(() {
          final position = _videoController.value.position;
          final duration = _videoController.value.duration;

          setState(() {
            _currentPosition = position;
            if (position >= duration && !_isVideoFinished) {
              _isVideoFinished = true;
            }
          });
        });
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
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
        child: Stack(
          children: [
            if (_videoController.value.isInitialized)
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _videoController.value.aspectRatio,
                        child: VideoPlayer(_videoController),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: const TextStyle(color: Colors.white),
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
                                  final newPosition = Duration(seconds: value.toInt());
                                  _videoController.seekTo(newPosition);
                                },
                              ),
                            ),
                            Text(
                              _formatDuration(totalDuration),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  )
                ],
              )
            else
              const Center(child: CircularProgressIndicator()),

            // Tombol kembali
            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () {
                  _videoController.pause();
                  Navigator.of(context).pop();
                },
              ),
            ),

            // Tombol selesai
            if (_isVideoFinished)
              Positioned(
                bottom: 40,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
    );
  }
}
