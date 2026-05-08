import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← NOUVEAU
import 'package:provider/provider.dart';               // ← NOUVEAU
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/pin_verify_screen.dart';
import 'screens/commercant/dashboard_screen.dart';
import 'screens/commercant/bilans_screen.dart';
import 'screens/commercant/rapports_screen.dart';
import 'screens/commercant/profil_screen.dart';
import 'screens/commercant/theme_screen.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'services/local_auth_service.dart';
import 'services/network_service.dart';               // ← NOUVEAU
import 'core/constants/app_colors.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/users_screen.dart';
import 'screens/admin/stats_screen.dart';
import 'screens/admin/settings_screen.dart';
import 'screens/admin/notifications_screen.dart';
import 'screens/commercant/budget_screen.dart';
import 'screens/auth/reset_pin_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:ui';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();

  // ✅ Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ✅ NOUVEAU — Cache offline Firestore (1 seule ligne, tout le reste est automatique)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ✅ NOUVEAU — Initialiser le service réseau
  final networkService = NetworkService();
  await networkService.initialize();

  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(
    // ✅ NOUVEAU — Provider pour que OfflineBanner fonctionne partout
    ChangeNotifierProvider<NetworkService>.value(
      value: networkService,
      child: MyApp(themeService: themeService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final ThemeService themeService;
  const MyApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
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
    child: child!,
  ),

 
          home: const AuthGate(),
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          routes: {
            '/welcome':          (context) => const WelcomeScreen(),
            '/login':            (context) => const LoginScreen(),
            '/signup':           (context) => const SignupScreen(),
            '/pin_setup':        (context) => const PinSetupScreen(),
            '/pin_verify':       (context) => const PinVerifyScreen(),
            '/dashboard':        (context) => const DashboardScreen(),
            '/bilans':           (context) => const BilansScreen(),
            '/rapports':         (context) => const RapportsScreen(),
            '/profil':           (context) => const ProfilScreen(),
            '/theme':            (context) => const ThemeScreen(),
            '/budget':           (context) => const BudgetScreen(),
            '/admin/dashboard':  (context) => const AdminDashboardScreen(),
            '/admin/users':      (context) => const AdminUsersScreen(),
            '/admin/stats':      (context) => const AdminStatsScreen(),
            '/admin/settings':   (context) => const AdminSettingsScreen(),
            '/admin/notifications': (context) => const AdminNotificationsScreen(),
            '/reset_pin':        (context) => const ResetPinScreen(),
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
  final AuthService _authService = AuthService();
  final LocalAuthService _localAuth = LocalAuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    final user = _authService.currentUser;
    if (user != null) {
      final hasPin = await _localAuth.hasPin();
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