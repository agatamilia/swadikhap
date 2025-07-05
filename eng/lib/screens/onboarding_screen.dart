import 'package:flutter/material.dart';
import '../screens/tutorial_video_screen.dart';
import '../screens/session_list_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Ask About Agriculture",
      description: "Get information about farming techniques, crop types, and plant care from our AI assistant.",
      image: "🌱",
    ),
    OnboardingPage(
      title: "Analyze Plant Images",
      description: "Upload a photo of your plant to get a disease analysis and care suggestions.",
      image: "📷",
    ),
    OnboardingPage(
      title: "Weather Information",
      description: "Get the latest weather information and farming advice based on the weather conditions at your location.",
      image: "☁️",
    ),
    OnboardingPage(
      title: "Watch Tutorial",
      description: "Learn how to use PeTaniku through this short video.",
      image: "🎥",
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                _buildPageIndicatorAndButtons(),
              ],
            ),
            Positioned(
              top: 12,
              right: 16,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SessionListScreen()),
                  );
                },
                child: const Text("Skip", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicatorAndButtons() {
    if (_currentPage < _pages.length - 1) {
      return Padding(
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
                    color: index == _currentPage ? Colors.green[600] : Colors.green[200],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Next", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
    }

    // Last page
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentPage ? Colors.green[600] : Colors.green[200],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SessionListScreen()),
              );
            },
            icon: const Icon(Icons.chat),
            label: const Text("Start Chatting Now", style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TutorialVideoScreen()),
              );
            },
            icon: const Icon(Icons.play_circle),
            label: const Text("Watch Tutorial"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green[800],
              side: BorderSide(color: Colors.green.shade400, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String? image;

  OnboardingPage({
    required this.title,
    required this.description,
    this.image,
  });
}