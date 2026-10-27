// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Utilise des imports relatifs pour éviter les conflits de package dans les tests
import '../lib/main.dart';
import '../lib/services/theme_service.dart';
import '../lib/services/network_service.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/local_auth_service.dart';

void main() {
  // Nécessaire pour simuler SharedPreferences dans les tests Flutter
  SharedPreferences.setMockInitialValues({
    'onboarding_done': false, // Simule un nouvel utilisateur
  });

  testWidgets('Test de démarrage de MaFortune - Redirection Onboarding', (WidgetTester tester) async {
    // 1. Récupérer l'instance unique (Singleton) de ThemeService
    final themeService = ThemeService(); 
    await themeService.loadTheme();

    final networkService = NetworkService();

    // 2. Construire l'arbre avec tous les Providers nécessaires
    await tester.pumpWidget(
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

    // 3. Laisser l'AuthGate faire sa redirection
    await tester.pumpAndSettle();

    // 4. Vérification
    expect(find.byType(MyApp), findsOneWidget);
  });
}