import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:video_player/video_player.dart';

/// Splash screen that plays a video (.mp4) on app launch.
/// Falls back to showing the static logo if the video is not found.
///
/// Place your splash video at: assets/splash.mp4
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _useFallback = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _videoController =
          VideoPlayerController.asset('assets/splash.mp4');
      await _videoController!.initialize();
      _videoController!.setLooping(false);

      _videoController!.addListener(() {
        if (_videoController!.value.position >=
            _videoController!.value.duration) {
          _finishSplash();
        }
      });

      if (mounted) {
        setState(() => _videoReady = true);
        // Remove the native splash right before playing the video
        // so the transition is seamless (logo → video).
        FlutterNativeSplash.remove();
        _videoController!.play();
      }
    } catch (e) {
      // Video not found — use static logo fallback
      debugPrint('[Splash] Video not available, using logo fallback: $e');
      if (mounted) {
        setState(() => _useFallback = true);
        // Remove native splash to reveal the fallback logo
        FlutterNativeSplash.remove();
        _fadeController.forward();
        // Show logo for 1 second then proceed (reduced from 2s)
        Future.delayed(const Duration(seconds: 1), _finishSplash);
      }
    }
  }

  void _finishSplash() {
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _videoReady && _videoController != null
            ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            : _useFallback
                ? FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 280,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(
                    color: Color(0xFF1A3A5C),
                  ),
      ),
    );
  }
}
