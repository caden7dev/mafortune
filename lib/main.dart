import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'core/constants/app_colors.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/users_screen.dart';
import 'screens/admin/stats_screen.dart';
import 'screens/admin/settings_screen.dart';
import 'screens/admin/notifications_screen.dart';
import 'screens/commercant/budget_screen.dart';
import 'screens/auth/reset_pin_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();

  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(MyApp(themeService: themeService));
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
          home: const AuthGate(),
          routes: {
            // Auth routes
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/pin_setup': (context) => const PinSetupScreen(),
            '/pin_verify': (context) => const PinVerifyScreen(),
            
            // Commercant routes
            '/dashboard': (context) => const DashboardScreen(),
            '/bilans': (context) => const BilansScreen(),
            '/rapports': (context) => const RapportsScreen(),
            '/profil': (context) => const ProfilScreen(),
            '/theme': (context) => const ThemeScreen(),
        
            '/budget': (context) => const BudgetScreen(),
            
            // Admin routes
           
            '/admin/dashboard': (context) => const AdminDashboardScreen(),
            '/admin/users': (context) => const AdminUsersScreen(),
            '/admin/stats': (context) => const AdminStatsScreen(),
            '/admin/settings': (context) => const AdminSettingsScreen(),
            '/admin/notifications': (context) => const AdminNotificationsScreen(),
            '/reset_pin':  (context) => const ResetPinScreen(),
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  Future<void> _redirect() async {
    final user = _authService.currentUser;
    if (user != null) {
      final hasPin = await _localAuth.hasPin();
      if (hasPin) {
        if (mounted) Navigator.pushReplacementNamed(context, '/pin_verify');
      } else {
        if (mounted) Navigator.pushReplacementNamed(context, '/pin_setup');
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
    }
    if (mounted) setState(() => _isLoading = false);
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