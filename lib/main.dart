import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/commercant/dashboard_screen.dart';
import 'screens/commercant/bilans_screen.dart';
import 'screens/commercant/rapports_screen.dart';
import 'screens/commercant/alertes_screen.dart';
import 'screens/commercant/profil_screen.dart';
import 'screens/commercant/theme_screen.dart';

import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting();
  
  // Charger le thème avant de lancer l'application
  final themeService = ThemeService();
  await themeService.loadTheme();
  
  runApp(MyApp(themeService: themeService));
}

class MyApp extends StatefulWidget {
  final ThemeService themeService;
  const MyApp({super.key, required this.themeService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ValueNotifier<bool> _themeNotifier;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier(widget.themeService.isDarkMode);
    widget.themeService.addListener(_themeNotifier);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_themeNotifier);
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _themeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'MaFortune',
          debugShowCheckedModeBanner: false,
          theme: widget.themeService.lightTheme,
          darkTheme: widget.themeService.darkTheme,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/welcome',
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/bilans': (context) => const BilansScreen(),
            '/rapports': (context) => const RapportsScreen(),
            '/alertes': (context) => const AlertesScreen(),
            '/profil': (context) => const ProfilScreen(),
            '/theme': (context) => const ThemeScreen(),
          },
        );
      },
    );
  }
}