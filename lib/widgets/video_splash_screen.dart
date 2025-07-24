import 'package:flutter/material.dart';
import 'dart:math';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _lettersController;
  late AnimationController _shimmerController;
  late AnimationController _bgController;
  final String _title = 'HARFLE';

  static const List<Color> _wordleColors = [
    Color(0xFFB6E2A1), // soft green
    Color(0xFFF7E6A2), // soft yellow
    Color(0xFFD3D3D3), // soft gray
    Color(0xFFAED7F4), // soft blue
    Color(0xFFE1C6F7), // soft purple
    Color(0xFFFFD6B0), // soft orange
  ];

  @override
  void initState() {
    super.initState();
    _lettersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _lettersController.forward();
  }

  @override
  void dispose() {
    _lettersController.dispose();
    _shimmerController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          // Hareketli degrade arka plan
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final t = _bgController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + 2 * t, -1 + 2 * (1 - t)),
                    end: Alignment(1 - 2 * t, 1 - 2 * (1 - t)),
                    colors: const [
                      Color(0xFF23232A),
                      Color(0xFF18181C),
                      Color(0xFF23232A),
                    ],
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_title.length, (i) {
                    final animation = CurvedAnimation(
                      parent: _lettersController,
                      curve: Interval(
                        i / _title.length,
                        (i + 1) / _title.length,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return AnimatedBuilder(
                      animation: Listenable.merge([animation, _shimmerController]),
                      builder: (context, child) {
                        // Shimmer efekti için
                        final shimmerPos = (_shimmerController.value * (_title.length + 1)) - i;
                        final shimmerOpacity = (1 - (shimmerPos.abs() / 2)).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: animation.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * animation.value,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: width > 400 ? 10 : 6,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    _title[i],
                                    style: TextStyle(
                                      color: _wordleColors[i % _wordleColors.length],
                                      fontSize: width > 400 ? 64 : 38,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 4,
                                      fontFamily: 'SF Pro Display',
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.10),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Shimmer efekti
                                  Opacity(
                                    opacity: shimmerOpacity * 0.7,
                                    child: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.7),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.srcATop,
                                      child: Text(
                                        _title[i],
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: width > 400 ? 64 : 38,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 4,
                                          fontFamily: 'SF Pro Display',
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Alt çizgi
                                  Positioned(
                                    bottom: width > 400 ? -10 : -6,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: width > 400 ? 5 : 3,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: LinearGradient(
                                          colors: [
                                            _wordleColors[i % _wordleColors.length].withOpacity(0.0),
                                            _wordleColors[i % _wordleColors.length].withOpacity(0.5),
                                            _wordleColors[i % _wordleColors.length].withOpacity(0.0),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          // Powered by Rivorya + simge
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white.withOpacity(0.38), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Powered by Rivorya',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.1,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 