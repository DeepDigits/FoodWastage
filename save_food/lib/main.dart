import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/collector_login_screen.dart';
import 'screens/collector_dashboard_screen.dart';
import 'services/api_service.dart';

/// Cameras initialised once before runApp so CameraScreen never calls
/// availableCameras() on the main thread, which can crash on Android.
List<CameraDescription> appCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    appCameras = await availableCameras();
  } catch (_) {
    appCameras = [];
  }
  runApp(const DemetraApp());
}

class DemetraApp extends StatelessWidget {
  const DemetraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEMETRA',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const SplashGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/home': (_) => const HomeScreen(),
        '/collector-login': (_) => const CollectorLoginScreen(),
        '/collector-dashboard': (_) => const CollectorDashboardScreen(),
      },
    );
  }
}

/// Animated splash screen — checks token and redirects.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  // ── Icon: scale + bounce ─────────────────────────────────────────────
  late final AnimationController _iconCtrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;

  // ── Text: slide up + fade ────────────────────────────────────────────
  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  // ── Tagline: delayed fade ────────────────────────────────────────────
  late final AnimationController _tagCtrl;
  late final Animation<double> _tagOpacity;

  // ── Leaf pulse / rotate ──────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  // ── Dots loader ──────────────────────────────────────────────────────
  late final AnimationController _dotsCtrl;

  // ── Background particles ─────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgOpacity;

  @override
  void initState() {
    super.initState();

    // Icon bounces in
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _iconScale = CurvedAnimation(
      parent: _iconCtrl,
      curve: Curves.elasticOut,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _iconOpacity = CurvedAnimation(
      parent: _iconCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Text slides up
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = CurvedAnimation(
      parent: _textCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _textSlide = CurvedAnimation(
      parent: _textCtrl,
      curve: Curves.easeOutCubic,
    ).drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero));

    // Tagline fades in
    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tagOpacity = CurvedAnimation(
      parent: _tagCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Leaf gentle pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseScale = CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOut,
    ).drive(Tween(begin: 1.0, end: 1.12));

    // Dots
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Background circles fade
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bgOpacity = CurvedAnimation(
      parent: _bgCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _runSequence();
  }

  Future<void> _runSequence() async {
    _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _iconCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _tagCtrl.forward();

    // Navigate after minimum display time
    await Future.delayed(const Duration(milliseconds: 1600));
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final isCollector = await ApiService.isCollector();
    Navigator.pushReplacementNamed(
      context,
      isCollector ? '/collector-dashboard' : '/home',
    );
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _pulseCtrl.dispose();
    _dotsCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFF388E3C),
                  ],
                ),
              ),
            ),
          ),

          // ── Decorative circles ───────────────────────────────────────
          FadeTransition(
            opacity: _bgOpacity,
            child: Stack(
              children: [
                Positioned(
                  top: -size.width * 0.3,
                  right: -size.width * 0.2,
                  child: _glowCircle(size.width * 0.7, Colors.white, 0.07),
                ),
                Positioned(
                  bottom: -size.width * 0.35,
                  left: -size.width * 0.25,
                  child: _glowCircle(size.width * 0.8, Colors.white, 0.06),
                ),
                Positioned(
                  top: size.height * 0.15,
                  left: -size.width * 0.1,
                  child: _glowCircle(
                    size.width * 0.4,
                    Colors.greenAccent,
                    0.08,
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.2,
                  right: -size.width * 0.1,
                  child: _glowCircle(
                    size.width * 0.35,
                    Colors.lightGreen,
                    0.08,
                  ),
                ),
                // Scattered leaf particles
                ..._buildParticles(size),
              ],
            ),
          ),

          // ── Center content ───────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated leaf icon
                ScaleTransition(
                  scale: _iconScale,
                  child: FadeTransition(
                    opacity: _iconOpacity,
                    child: ScaleTransition(
                      scale: _pulseScale,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // DEMETRA title
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          'DEMETRA',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 8,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tagline
                FadeTransition(
                  opacity: _tagOpacity,
                  child: Text(
                    'Save Food · Save Earth',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.75),
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // Animated dots loader
                FadeTransition(
                  opacity: _tagOpacity,
                  child: _AnimatedDots(controller: _dotsCtrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }

  List<Widget> _buildParticles(Size size) {
    const positions = [
      [0.15, 0.25],
      [0.8, 0.15],
      [0.05, 0.6],
      [0.9, 0.5],
      [0.3, 0.85],
      [0.7, 0.8],
      [0.5, 0.1],
      [0.6, 0.4],
    ];
    return positions.map((p) {
      return Positioned(
        left: p[0] * size.width,
        top: p[1] * size.height,
        child: Icon(
          Icons.eco,
          size: 14 + (p[0] * 10),
          color: Colors.white.withOpacity(0.12),
        ),
      );
    }).toList();
  }
}

/// Three bouncing dots that animate sequentially.
class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 1/3 of the cycle
            final phase = (controller.value - i / 3.0) % 1.0;
            final t = sin(phase * pi).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8 + t * 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5 + t * 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}
