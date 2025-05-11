import 'package:flutter/material.dart';

enum VoiceRecordingState {
  recording,
  locked,
  paused
}

class VoiceInputOverlay extends StatefulWidget {
  final Function() onCancel;
  final Function() onFinish;
  final Function()? onLock;
  final Function()? onPause;
  final Function()? onResume;
  final String recordingTime;
  final VoiceRecordingState state;

  const VoiceInputOverlay({
    Key? key,
    required this.onCancel,
    required this.onFinish,
    this.onLock,
    this.onPause,
    this.onResume,
    required this.recordingTime,
    required this.state,
  }) : super(key: key);

  @override
  State<VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends State<VoiceInputOverlay> with SingleTickerProviderStateMixin {
  double _verticalDragOffset = 0;
  double _horizontalDragOffset = 0;
  bool _isDraggingHorizontal = false;
  bool _isDraggingVertical = false;
  final double _lockThreshold = -100; // Negative because we're dragging up
  final double _cancelThreshold = 100; // Positive because we're dragging right
  
  // Animation for the mic button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_) {
        if (widget.state != VoiceRecordingState.locked) {
          setState(() {
            _isDraggingHorizontal = true;
            _isDraggingVertical = false;
          });
        }
      },
      onHorizontalDragUpdate: (details) {
        if (widget.state != VoiceRecordingState.locked && _isDraggingHorizontal) {
          setState(() {
            _horizontalDragOffset += details.primaryDelta!;
            // Limit to only right swipe for cancel
            if (_horizontalDragOffset < 0) _horizontalDragOffset = 0;
          });
        }
      },
      onHorizontalDragEnd: (_) {
        if (widget.state != VoiceRecordingState.locked) {
          if (_horizontalDragOffset > _cancelThreshold) {
            widget.onCancel();
          }
          setState(() {
            _horizontalDragOffset = 0;
            _isDraggingHorizontal = false;
          });
        }
      },
      onVerticalDragStart: (_) {
        if (widget.state != VoiceRecordingState.locked) {
          setState(() {
            _isDraggingVertical = true;
            _isDraggingHorizontal = false;
          });
        }
      },
      onVerticalDragUpdate: (details) {
        if (widget.state != VoiceRecordingState.locked && _isDraggingVertical) {
          setState(() {
            _verticalDragOffset += details.primaryDelta!;
            // Limit to only up swipe for lock
            if (_verticalDragOffset > 0) _verticalDragOffset = 0;
          });
        }
      },
      onVerticalDragEnd: (_) {
        if (widget.state != VoiceRecordingState.locked) {
          if (_verticalDragOffset < _lockThreshold) {
            if (widget.onLock != null) {
              widget.onLock!();
            }
          }
          setState(() {
            _verticalDragOffset = 0;
            _isDraggingVertical = false;
          });
        }
      },
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _buildRecordingInterface(),
                ),
              ),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingInterface() {
    if (widget.state == VoiceRecordingState.locked) {
      return _buildLockedRecordingInterface();
    } else {
      return _buildDraggableRecordingInterface();
    }
  }

  Widget _buildDraggableRecordingInterface() {
    // Calculate opacity for lock indicator based on drag
    final lockOpacity = _verticalDragOffset < 0 
        ? ((_verticalDragOffset.abs() / _lockThreshold.abs()) * 0.8 + 0.2).clamp(0.2, 1.0)
        : 0.2;
        
    // Calculate opacity for cancel indicator based on drag
    final cancelOpacity = _horizontalDragOffset > 0 
        ? ((_horizontalDragOffset / _cancelThreshold) * 0.8 + 0.2).clamp(0.2, 1.0)
        : 0.2;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Lock indicator (top)
        Positioned(
          top: 100 + _verticalDragOffset,
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
        
        // Cancel indicator (right)
        Positioned(
          right: 100 - _horizontalDragOffset,
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
        
        // Recording time display
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
                widget.recordingTime,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockedRecordingInterface() {
    return Container(
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
            widget.recordingTime,
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
                onPressed: widget.onCancel,
                tooltip: 'Batalkan rekaman',
              ),
              SizedBox(width: 30),
              IconButton(
                icon: Icon(
                  widget.state == VoiceRecordingState.paused
                      ? Icons.play_arrow
                      : Icons.pause,
                  color: Colors.red,
                  size: 40,
                ),
                onPressed: widget.state == VoiceRecordingState.paused
                    ? widget.onResume
                    : widget.onPause,
                tooltip: widget.state == VoiceRecordingState.paused
                    ? 'Lanjutkan rekaman'
                    : 'Jeda rekaman',
              ),
              SizedBox(width: 30),
              IconButton(
                icon: Icon(Icons.send, color: Colors.green, size: 30),
                onPressed: widget.onFinish,
                tooltip: 'Kirim rekaman',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    if (widget.state == VoiceRecordingState.locked) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
