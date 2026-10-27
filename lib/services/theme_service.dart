import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';

class ThemeService {
  static const String _themeKey = 'is_dark_mode';
  static final ThemeService _instance = ThemeService._internal();
  
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDarkMode = false;
  final ValueNotifier<bool> themeNotifier = ValueNotifier<bool>(false);

  bool get isDarkMode => _isDarkMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    themeNotifier.value = _isDarkMode;
  }

  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    themeNotifier.value = _isDarkMode; // ✅ C'est ceci qui déclenche la mise à jour globale
  }

  Future<void> toggleTheme() async {
    await setTheme(!_isDarkMode);
  }

  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryGreen,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryGreen,
        secondary: AppColors.primaryGreen,
        surface: Colors.white,
        error: Colors.red,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2)),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen)),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryGreen,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGreen,
        secondary: AppColors.primaryGreen,
        surface: Color(0xFF1E1E1E),
        error: Colors.red,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), foregroundColor: Colors.white, elevation: 0, centerTitle: true),
      cardTheme: CardThemeData(color: const Color(0xFF1E1E1E), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade700)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2)),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen)),
    );
  }
}