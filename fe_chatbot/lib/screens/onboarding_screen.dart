// screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'chat_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late VideoPlayerController _videoController;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isVideoInitialized = false;

  final List<Map<String, String>> onboardingData = [
    {
      'title': 'Welcome to PeTaniku',
      'description': 'Your agricultural assistant for farming questions and advice',
      'image': 'assets/onboarding1.png',
    },
    {
      'title': 'Ask Anything',
      'description': 'Get answers to your farming questions instantly',
      'image': 'assets/onboarding2.png',
    },
    {
      'title': 'Video Tutorial',
      'description': 'Watch this quick guide to get started',
      'image': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize video controller
    _videoController = VideoPlayerController.asset('assets/tutorial.mp4')
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.setLooping(true);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _skipOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(), // Hapus MultiProvider
      ),
    );
  }
  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      _skipOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skipOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ),
            
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingData.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  // Pause video when not on video page
                  if (index != 2 && _videoController.value.isPlaying) {
                    _videoController.pause();
                  }
                },
                itemBuilder: (context, index) {
                  if (index == 2) {
                    // Video tutorial page
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isVideoInitialized)
                          AspectRatio(
                            aspectRatio: _videoController.value.aspectRatio,
                            child: VideoPlayer(_videoController),
                          )
                        else
                          const CircularProgressIndicator(),
                        
                        const SizedBox(height: 20),
                        
                        IconButton(
                          icon: Icon(
                            _videoController.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 40,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_videoController.value.isPlaying) {
                                _videoController.pause();
                              } else {
                                _videoController.play();
                              }
                            });
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Text(
                          onboardingData[index]['title']!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            onboardingData[index]['description']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Regular onboarding page
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          onboardingData[index]['image']!,
                          height: 250,
                        ),
                        
                        const SizedBox(height: 40),
                        
                        Text(
                          onboardingData[index]['title']!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            onboardingData[index]['description']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
            
            // Page indicator and next button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicator
                  Row(
                    children: List.generate(
                      onboardingData.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.green
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                  
                  // Next button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      _currentPage == onboardingData.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: const TextStyle(color: Colors.white),
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