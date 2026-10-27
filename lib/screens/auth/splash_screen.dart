import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // ✅ AJOUT DE L'IMPORT
import '../../services/local_auth_service.dart';
import 'onboarding_screen.dart';
import 'terms_screen.dart';

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
    // Laisse le temps au système de charger les données
    final prefs = await SharedPreferences.getInstance();
    final hasDoneOnboarding = prefs.getBool('onboarding_done') ?? false;
    final hasAcceptedTerms = prefs.getBool('terms_accepted') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    final localAuth = LocalAuthService();
    final hasPin = await localAuth.hasPin();

    if (!mounted) return;

    void goTo(Widget page) {
      // ✅ ON RETIRE LE SPLASH SCREEN NATIF JUSTE AVANT LA REDIRECTION
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
      // ✅ ENCORE ICI
      FlutterNativeSplash.remove(); 
      Navigator.pushReplacementNamed(context, routeName);
    }

    // Algorithme de redirection pour MaFortune
    if (!hasDoneOnboarding) {
      goTo(const OnboardingScreen());
    } else if (!hasAcceptedTerms) {
      goTo(const TermsScreen());
    } else if (user != null) {
      if (hasPin) {
        goToNamed('/pin_verify'); 
      } else {
        goToNamed('/dashboard');
      }
    } else {
      goToNamed('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Plus besoin du gros logo dessiné ici, l'écran reste blanc ou vert 
    // en attendant que l'algorithme décide sur quelle page envoyer l'utilisateur.
    return const Scaffold(
      backgroundColor: Color(0xFF2E7D32), // Assure-toi de mettre la même couleur que dans pubspec.yaml
      body: SizedBox.shrink(), // Écran vide temporaire, invisible à l'œil nu
    );
  }
}
