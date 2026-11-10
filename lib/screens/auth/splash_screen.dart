import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../services/local_auth_service.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppStatus();
    });
  }

  Future<void> _checkAppStatus() async {
    final stopwatch = Stopwatch()..start();

    final prefs = await SharedPreferences.getInstance();
    final hasDoneOnboarding = prefs.getBool('onboarding_done') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    final hasPin = await LocalAuthService().hasPin();

    // Le splash natif reste visible au moins 2 secondes
    final remaining = const Duration(milliseconds: 2000) - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    if (!mounted) return;

    void goTo(Widget page) {
      FlutterNativeSplash.remove();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }

    void goToNamed(String routeName) {
      FlutterNativeSplash.remove();
      Navigator.pushReplacementNamed(context, routeName);
    }

    if (!hasDoneOnboarding) {
      goTo(const OnboardingScreen());
    } else if (user != null) {
      goToNamed(hasPin ? '/pin_verify' : '/dashboard');
    } else {
      goToNamed('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.shrink(),
    );
  }
}