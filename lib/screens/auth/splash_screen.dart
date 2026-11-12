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

    // ✅ NOUVEAU : Logique de délai d'expiration pour le PIN (5 minutes)
    final lastActiveTime = prefs.getInt('last_active_time') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final timeoutDuration = 5 * 60 * 1000; // 5 minutes en millisecondes

    // Le splash natif reste visible au moins 2 secondes pour éviter l'écran blanc
    final remaining = const Duration(milliseconds: 2000) - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

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

    // ✅ LOGIQUE DE REDIRECTION INTELLIGENTE
    if (!hasDoneOnboarding) {
      goTo(const OnboardingScreen());
    } else if (user != null) {
      if (hasPin) {
        // Si l'utilisateur a un PIN, on vérifie le temps écoulé
        if (currentTime - lastActiveTime < timeoutDuration) {
          // Moins de 5 minutes : Accès direct au Dashboard (pas de PIN)
          goToNamed('/dashboard');
        } else {
          // Plus de 5 minutes : Demande du PIN pour la sécurité
          goToNamed('/pin_verify');
        }
      } else {
        // Pas de PIN configuré : Accès direct au Dashboard
        goToNamed('/dashboard');
      }
    } else {
      // Utilisateur non connecté : Page d'accueil
      goToNamed('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    // L'écran est invisible car on utilise le splash natif, 
    // mais on garde un fond blanc au cas où.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.shrink(),
    );
  }
}