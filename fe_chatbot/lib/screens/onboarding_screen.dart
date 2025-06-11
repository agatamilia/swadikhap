import 'package:flutter/material.dart';
import 'package:peTaniku/screens/session_list_screen.dart';
import 'package:video_player/video_player.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  late VideoPlayerController _videoController;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Tanya Tentang Pertanian",
      description:
          "Dapatkan informasi tentang teknik bertani, jenis tanaman, dan perawatan tanaman dari asisten AI kami.",
      image: "🌱",
    ),
    OnboardingPage(
      title: "Analisis Gambar Tanaman",
      description:
          "Unggah foto tanaman Anda untuk mendapatkan analisis penyakit tanaman dan saran perawatan.",
      image: "📷",
    ),
    OnboardingPage(
      title: "Informasi Cuaca",
      description:
          "Dapatkan informasi cuaca terkini dan saran pertanian berdasarkan kondisi cuaca di lokasi Anda.",
      image: "☁️",
    ),
    OnboardingPage(
      title: "Tonton Tutorial",
      description: "Pelajari cara menggunakan PeTaniku lewat video singkat ini.",
      isVideo: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset("assets/videos/tutorial.mp4")
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SessionListScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    if (_pages[index].isVideo) {
                      _videoController.play();
                    } else {
                      _videoController.pause();
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!page.isVideo)
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                page.image ?? '',
                                style: const TextStyle(fontSize: 80),
                              ),
                            ),
                          )
                        else if (_videoController.value.isInitialized)
                          AspectRatio(
                            aspectRatio: _videoController.value.aspectRatio,
                            child: VideoPlayer(_videoController),
                          ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.green[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentPage
                              ? Colors.green[600]
                              : Colors.green[200],
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentPage < _pages.length - 1 ? "Lanjut" : "Mulai",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String? image;
  final bool isVideo;

  OnboardingPage({
    required this.title,
    required this.description,
    this.image,
    this.isVideo = false,
  });
}
