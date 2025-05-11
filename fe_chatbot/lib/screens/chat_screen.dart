import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import '../providers/session_provider.dart';
import '../services/permission_service.dart';
import '../widgets/chat_message_item.dart';
import '../widgets/weather_widget.dart';
import '../widgets/suggestion_chips.dart';
import '../models/message.dart';
import '../services/location_service.dart';
import 'session_list_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LocationService _locationService = LocationService();
  bool _permissionsChecked = false;
  
  // Voice recording variables
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  bool _isRecordingPaused = false;
  double _dragVertical = 0;
  double _dragHorizontal = 0;
  String _recordingTime = "0:00";
  
  // Animation controller for recording pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(_pulseController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _loadSessionMessages();
      _locationService.getCurrentLocation();
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSessionMessages();
  }

  Future<void> _loadSessionMessages() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (sessionProvider.currentSession != null) {
      await chatProvider.loadMessages(sessionProvider.currentSession!.id);
    }
  }

  Future<void> _checkPermissions() async {
    if (_permissionsChecked) return;

    bool hasLocationPermission = await PermissionService.hasLocationPermission();
    if (!hasLocationPermission && mounted) {
      bool granted = await PermissionService.requestLocationPermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Lokasi');
      }
    }
    
    bool hasMicrophonePermission = await PermissionService.hasMicrophonePermission();
    if (!hasMicrophonePermission && mounted) {
      bool granted = await PermissionService.requestMicrophonePermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Mikrofon');
      }
    }
    
    bool hasStoragePermission = await PermissionService.hasStoragePermission();
    if (!hasStoragePermission && mounted) {
      bool granted = await PermissionService.requestStoragePermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Penyimpanan');
      }
    }
    
    _permissionsChecked = true;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(BuildContext context, String text) {
    if (text.isEmpty && !Provider.of<ChatProvider>(context, listen: false).hasImagePending) return;
    
    _textController.clear();
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    if (sessionProvider.currentSession != null) {
      // Using sendMessage that sends to API
      chatProvider.sendMessage(text, sessionProvider.currentSession!.id, sessionProvider);
    }
    
    _scrollToBottom();
  }

  void _onSuggestionSelected(String suggestion) {
    _textController.text = suggestion;
  }

  void _showSessionList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SessionListScreen(),
      ),
    );
  }

  void _showImageOptions() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.green),
            title: const Text('Ambil Foto'),
            onTap: () {
              Navigator.pop(context);
              chatProvider.pickImageFromCamera(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.green),
            title: const Text('Pilih dari Galeri'),
            onTap: () {
              Navigator.pop(context);
              chatProvider.pickImage(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceOutputToggle(ChatProvider chatProvider) {
    return Tooltip(
      message: "Aktifkan/nonaktifkan suara untuk jawaban asisten",
      child: Row(
        children: [
          Icon(
            chatProvider.useVoiceOutput ? Icons.volume_up : Icons.volume_off,
            size: 20,
            color: Colors.white,
          ),
          Switch(
            value: chatProvider.useVoiceOutput,
            onChanged: (value) {
              chatProvider.toggleVoiceOutput();
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.green[300]!,
            inactiveThumbColor: Colors.green[100]!,
            inactiveTrackColor: Colors.green[200]!,
          ),
        ],
      ),
    );
  }

  // Start recording
  void _startRecording(ChatProvider chatProvider) {
    setState(() {
      _isRecording = true;
      _dragVertical = 0;
      _dragHorizontal = 0;
    });
    chatProvider.startRecordingHold(context);
  }

  // Handle recording lock
  void _lockRecording(ChatProvider chatProvider) {
    setState(() {
      _isRecordingLocked = true;
    });
    chatProvider.lockRecording();
  }

  // Handle recording pause/resume
  void _togglePauseRecording(ChatProvider chatProvider) {
    if (_isRecordingPaused) {
      setState(() {
        _isRecordingPaused = false;
      });
      chatProvider.resumeRecording();
    } else {
      setState(() {
        _isRecordingPaused = true;
      });
      chatProvider.pauseRecording();
    }
  }

  // Cancel recording
  void _cancelRecording(ChatProvider chatProvider) {
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _isRecordingPaused = false;
      _dragVertical = 0;
      _dragHorizontal = 0;
    });
    chatProvider.cancelRecordingHold();
  }

  // Finish and send recording
  void _finishRecording(ChatProvider chatProvider, SessionProvider sessionProvider) {
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _isRecordingPaused = false;
      _dragVertical = 0;
      _dragHorizontal = 0;
    });
    
    if (sessionProvider.currentSession != null) {
      chatProvider.stopRecordingHold(
        sessionProvider.currentSession!.id,
        sessionProvider,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    final deviceId = sessionProvider.currentSession?.deviceId ?? '';
    
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.messages.isNotEmpty) {
          _scrollToBottom();
        }
        
        // Update recording time from provider
        if (_isRecording) {
          _recordingTime = chatProvider.recordingTime;
        }
        
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              sessionProvider.currentSession?.name ?? 'PeTaniku',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green[700],
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _showSessionList,
                tooltip: 'Riwayat Chat',
              ),
              _buildVoiceOutputToggle(chatProvider),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Weather widget
                  WeatherWidget(
                    weatherData: _locationService.weatherData,
                    location: _locationService.placemark?.locality ?? 'Lokasi Anda',
                    isLoading: _locationService.isLoading,
                  ),
                  
                  Expanded(
                    child: chatProvider.messages.isEmpty
                        ? _buildWelcomeScreen()
                        : _buildChatList(chatProvider, sessionProvider),
                  ),
                  _buildInputArea(chatProvider, sessionProvider),
                ],
              ),
              
              // Recording overlay - only shown when recording
              if (_isRecording)
                _buildRecordingOverlay(chatProvider, sessionProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordingOverlay(ChatProvider chatProvider, SessionProvider sessionProvider) {
    // Calculate opacity for lock indicator based on drag
    final lockOpacity = _dragVertical < 0 
        ? ((_dragVertical.abs() / 100) * 0.8 + 0.2).clamp(0.2, 1.0)
        : 0.2;
        
    // Calculate opacity for cancel indicator based on drag
    final cancelOpacity = _dragHorizontal > 0 
        ? ((_dragHorizontal / 100) * 0.8 + 0.2).clamp(0.2, 1.0)
        : 0.2;
    
    if (_isRecordingLocked) {
      // Locked recording UI
      return Container(
        color: Colors.black.withOpacity(0.7),
        child: SafeArea(
          child: Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rekaman Terkunci',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _recordingTime,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.white, size: 30),
                        onPressed: () => _cancelRecording(chatProvider),
                        tooltip: 'Batalkan rekaman',
                      ),
                      SizedBox(width: 30),
                      IconButton(
                        icon: Icon(
                          _isRecordingPaused ? Icons.play_arrow : Icons.pause,
                          color: Colors.red,
                          size: 40,
                        ),
                        onPressed: () => _togglePauseRecording(chatProvider),
                        tooltip: _isRecordingPaused ? 'Lanjutkan rekaman' : 'Jeda rekaman',
                      ),
                      SizedBox(width: 30),
                      IconButton(
                        icon: Icon(Icons.send, color: Colors.green, size: 30),
                        onPressed: () => _finishRecording(chatProvider, sessionProvider),
                        tooltip: 'Kirim rekaman',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // Regular recording UI with drag gestures
      return GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragVertical += details.delta.dy;
            // Limit to only up swipe for lock
            if (_dragVertical > 0) _dragVertical = 0;
            
            // Check if we should lock
            if (_dragVertical < -100) {
              _lockRecording(chatProvider);
            }
          });
        },
        onVerticalDragEnd: (_) {
          setState(() {
            _dragVertical = 0;
          });
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            _dragHorizontal += details.delta.dx;
            // Limit to only right swipe for cancel
            if (_dragHorizontal < 0) _dragHorizontal = 0;
            
            // Check if we should cancel
            if (_dragHorizontal > 100) {
              _cancelRecording(chatProvider);
            }
          });
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _dragHorizontal = 0;
          });
        },
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: SafeArea(
            child: Stack(
              children: [
                // Lock indicator (top)
                Positioned(
                  top: 100 + _dragVertical,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock,
                          color: Colors.white.withOpacity(lockOpacity),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Geser ke atas untuk mengunci',
                          style: TextStyle(
                            color: Colors.white.withOpacity(lockOpacity),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Cancel indicator (right)
                Positioned(
                  right: 100 - _dragHorizontal,
                  top: MediaQuery.of(context).size.height / 2,
                  child: Row(
                    children: [
                      Text(
                        'Geser ke kanan untuk membatalkan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(cancelOpacity),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.cancel,
                        color: Colors.white.withOpacity(cancelOpacity),
                        size: 40,
                      ),
                    ],
                  ),
                ),
                
                // Recording time and waveform
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic,
                              color: Colors.red,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              _recordingTime,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),
                            // Simple waveform visualization
                            Container(
                              width: 150,
                              height: 30,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(
                                  15,
                                  (index) => AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    width: 4,
                                    height: (index % 3 == 0) 
                                        ? 20.0 * _pulseAnimation.value
                                        : 10.0 * _pulseAnimation.value,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Lepas untuk mengirim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green[200],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                "🌾",
                style: TextStyle(fontSize: 60),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Welcome to PeTaniku!",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.green[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Tanyakan tentang teknik bertani, cuaca, atau hama tanaman",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.green[700],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _textController.text = "Hi, saya ingin bertanya";
              _handleSubmitted(context, _textController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              "Mulai Bertanya",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(ChatProvider chatProvider, SessionProvider sessionProvider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatProvider.messages.length && chatProvider.isLoading) {
          return ChatMessageItem(
            message: ChatMessage(
              content: "...",
              role: MessageRole.assistant,
            ),
            isTyping: true,
          );
        }
        
        final message = chatProvider.messages[index];
        
        return ChatMessageItem(
          message: message,
        );
      },
    );
  }

  Widget _buildInputArea(ChatProvider chatProvider, SessionProvider sessionProvider) {
    final bool hasText = _textController.text.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Image picker button
              FloatingActionButton(
                onPressed: chatProvider.isLoading || _isRecording
                    ? null 
                    : () => _showImageOptions(),
                mini: true,
                backgroundColor: Colors.green[600],
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: chatProvider.hasImagePending 
                          ? "Ketik pertanyaan tentang gambar ini..."
                          : "Tanyakan sesuatu tentang pertanian...",
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                      suffixIcon: chatProvider.hasImagePending
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.green),
                              onPressed: chatProvider.clearPendingImage,
                            )
                          : null,
                    ),
                    style: TextStyle(color: Colors.green[800]),
                    enabled: !_isRecording && !chatProvider.isLoading,
                    onSubmitted: (text) => _handleSubmitted(context, text),
                    onChanged: (text) {
                      // Force rebuild to update send/voice button
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),  
              
              // Dynamic button: Voice when empty, Send when has text
              GestureDetector(
                onLongPressStart: (details) {
                  if (!hasText && !chatProvider.isLoading && !_isRecording) {
                    _startRecording(chatProvider);
                  }
                },
                onLongPressEnd: (details) {
                  if (_isRecording && !_isRecordingLocked) {
                    _finishRecording(chatProvider, sessionProvider);
                  }
                },
                child: FloatingActionButton(
                  onPressed: chatProvider.isLoading || _isRecording
                      ? null 
                      : hasText
                          ? () => _handleSubmitted(context, _textController.text)
                          : () => _startRecording(chatProvider),
                  mini: true,
                  backgroundColor: Colors.green[600],
                  child: Icon(
                    hasText ? Icons.send : Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          SuggestionChips(
            onSuggestionSelected: _onSuggestionSelected,
            chipColor: Colors.green[100]!,
            textColor: Colors.green[800]!,
          ),
        ],
      ),
    );
  }
}
