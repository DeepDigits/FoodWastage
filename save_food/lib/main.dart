import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
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
      },
    );
  }
}

/// Checks token and redirects to login or home.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, loggedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 56, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              'DEMETRA',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
