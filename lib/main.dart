import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Services
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'services/local_auth_service.dart';
import 'services/network_service.dart';
import 'services/bilan_notification_service.dart';

// AuthProvider
import 'providers/auth_provider.dart';

// Screens Auth
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/pin_verify_screen.dart';
import 'screens/auth/reset_pin_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/cgu_screen.dart';

// Screens Commerçant
import 'screens/commercant/dashboard_screen.dart' as commercant_dashboard;
import 'screens/commercant/bilans_screen.dart';
import 'screens/commercant/rapports_screen.dart';
import 'screens/commercant/profil_screen.dart';
import 'screens/commercant/theme_screen.dart';
import 'screens/commercant/budget_screen.dart';
import 'screens/commercant/mes_produits_screen.dart';

// Admin
import 'screens/admin/dashboard_screen.dart' as admin_dashboard;
import 'screens/admin/users_screen.dart';
import 'screens/admin/stats_screen.dart';
import 'screens/admin/settings_screen.dart';
import 'screens/admin/notifications_screen.dart';

// Core & Widgets
import 'widgets/screenshot_wrapper.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:ui';
import 'screens/commercant/messages_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Fige le splash natif jusqu'a ce que SplashScreen appelle remove()
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialisation de Firebase et Crashlytics
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();

    await Supabase.initialize(
    url: 'https://atipntzkupciirorqvud.supabase.co',
    anonKey: 'sb_publishable_Psu4y1xyfkHaz5eGujGQzw_-20CrGR-',
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Services requis au demarrage
  final networkService = NetworkService();
  await networkService.initialize();

  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NetworkService>.value(value: networkService),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<LocalAuthService>(create: (_) => LocalAuthService()),
        Provider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Lance en arriere-plan, sans bloquer l'affichage du logo
  BilanNotificationService.initialize();
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

          theme: themeService.lightTheme.copyWith(
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: themeService.darkTheme.copyWith(
            scaffoldBackgroundColor: Colors.white,
          ),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.1,
              ),
            ),
            child: ScreenshotWrapper(child: child!),
          ),

          home: const SplashScreen(),

          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/pin_setup': (context) => const PinSetupScreen(),
            '/pin_verify': (context) => const PinVerifyScreen(),
            '/cgu': (context) => const CguScreen(),
            '/dashboard': (context) => const commercant_dashboard.DashboardScreen(),
            '/bilans': (context) => const BilansScreen(),
            '/rapports': (context) => const RapportsScreen(),
            '/profil': (context) => const ProfilScreen(),
            '/theme': (context) => const ThemeScreen(),
            '/budget': (context) => const BudgetScreen(),
            '/admin/dashboard': (context) => const admin_dashboard.AdminDashboardScreen(),
            '/messages': (context) => const MessagesScreen(),
            '/admin/users': (context) => const AdminUsersScreen(),
            '/admin/stats': (context) => const AdminStatsScreen(),
            '/admin/settings': (context) => const AdminSettingsScreen(),
            '/admin/notifications': (context) => const AdminNotificationsScreen(),
            '/reset_pin': (context) => const ResetPinScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/mes_produits': (context) => const MesProduitsScreen(isOnboarding: true),
            '/mes_produits_gestion': (context) => const MesProduitsScreen(isOnboarding: false),
          },
        );
      },
    );
  }
}