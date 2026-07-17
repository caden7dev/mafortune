import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

// Services
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'services/local_auth_service.dart';
import 'services/network_service.dart';
import 'services/bilan_notification_service.dart';

// Screens
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/pin_verify_screen.dart';
import 'screens/auth/reset_pin_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/commercant/dashboard_screen.dart';
import 'screens/commercant/bilans_screen.dart';
import 'screens/commercant/rapports_screen.dart';
import 'screens/commercant/profil_screen.dart';
import 'screens/commercant/theme_screen.dart';
import 'screens/commercant/budget_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/users_screen.dart';
import 'screens/admin/stats_screen.dart';
import 'screens/admin/settings_screen.dart';
import 'screens/admin/notifications_screen.dart';

// Core & Widgets
import 'core/constants/app_colors.dart';
import 'widgets/screenshot_wrapper.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation de Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();

  // Capture des erreurs avec Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Paramètres Firestore (Cache illimité)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Instanciation des services requis au démarrage
  final networkService = NetworkService();
  await networkService.initialize();

  await BilanNotificationService.initialize();

  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NetworkService>.value(value: networkService),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<LocalAuthService>(create: (_) => LocalAuthService()),
        //  Cette écriture est correcte car ton application écoute déjà le ValueNotifier directement
Provider<ThemeService>.value(value: themeService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);

    return ValueListenableBuilder<bool>(
      valueListenable: themeService.themeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'MaFortune',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.1,
                  ),
            ),
            child: ScreenshotWrapper(
              child: child!,
            ),
          ),

          home: const AuthGate(),
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          routes: {
            '/welcome':             (context) => const WelcomeScreen(),
            '/login':               (context) => const LoginScreen(),
            '/signup':              (context) => const SignupScreen(),
            '/pin_setup':           (context) => const PinSetupScreen(),
            '/pin_verify':          (context) => const PinVerifyScreen(),
            '/dashboard':           (context) => const DashboardScreen(),
            '/bilans':              (context) => const BilansScreen(),
            '/rapports':            (context) => const RapportsScreen(),
            '/profil':              (context) => const ProfilScreen(),
            '/theme':               (context) => const ThemeScreen(),
            '/budget':              (context) => const BudgetScreen(),
            '/admin/dashboard':     (context) => const AdminDashboardScreen(),
            '/admin/users':         (context) => const AdminUsersScreen(),
            '/admin/stats':         (context) => const AdminStatsScreen(),
            '/admin/settings':      (context) => const AdminSettingsScreen(),
            '/admin/notifications': (context) => const AdminNotificationsScreen(),
            '/reset_pin':           (context) => const ResetPinScreen(),
            '/onboarding':          (context) => const OnboardingScreen(),
          },
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (!mounted) return;

    if (!onboardingDone) {
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    // Récupération sécurisée des services depuis le Provider
    final authService = Provider.of<AuthService>(context, listen: false);
    final localAuth = Provider.of<LocalAuthService>(context, listen: false);

    final user = authService.currentUser;
    if (user != null) {
      BilanNotificationService.planifierBilanQuotidien();
      final hasPin = await localAuth.hasPin();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          hasPin ? '/pin_verify' : '/pin_setup',
        );
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 20),
            Text('Chargement...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}