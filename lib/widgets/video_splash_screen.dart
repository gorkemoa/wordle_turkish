import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const VideoSplashScreen({
    Key? key,
    required this.onFinished,
  }) : super(key: key);

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late AnimationController _textAnimationController;
  late Animation<double> _textOpacityAnimation;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeTextAnimation();
  }

  void _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset('assets/ixel.mp4');
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        
        // Video'yu oynat
        _videoController!.play();
        
        // Video bittiğinde callback'i çağır
        _videoController!.addListener(() {
          if (_videoController!.value.position >= _videoController!.value.duration) {
            widget.onFinished();
          }
        });
        
        // Minimum 2-3 saniye göster
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _videoController!.value.position >= const Duration(milliseconds: 2500)) {
            widget.onFinished();
          }
        });
      }
    } catch (e) {
      // Video yüklenemezse direkt geç
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          widget.onFinished();
        }
      });
    }
  }

  void _initializeTextAnimation() {
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _textOpacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _textAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player
          if (_isVideoInitialized && _videoController != null)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
          
          // Loading Text
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textOpacityAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacityAnimation.value,
                  child: const Text(
                    'Yükleniyor...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Loading Indicator (fallback)
          if (!_isVideoInitialized)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Yükleniyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 