import 'package:flutter/material.dart';

/// Couleurs de l'application MaFortune
class AppColors {
  // Couleurs principales
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenLight = Color(0xFF43A047);
  static const Color primaryGreenDark = Color(0xFF1B5E20);
  
  // Couleurs secondaires
  static const Color secondaryBlue = Color(0xFF1565C0);
  static const Color secondaryBlueLight = Color(0xFF1976D2);
  static const Color secondaryBlueDark = Color(0xFF0D47A1);
  
  // Couleurs de statut
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF29B6F6);
  
  // Couleurs de transaction
  static const Color incomeGreen = Color(0xFF2E7D32);
  static const Color expenseRed = Color(0xFFD32F2F);
  
  // Couleurs de fond
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // Couleurs de texte
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // Couleurs de bordure
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);
  static const Color borderDark = Color(0xFF757575);
  
  // Couleurs d'overlay
  static const Color overlayLight = Color(0x1A000000); // 10% noir
  static const Color overlayMedium = Color(0x4D000000); // 30% noir
  static const Color overlayDark = Color(0x80000000); // 50% noir
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, primaryGreenLight],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryBlue, secondaryBlueLight],
  );
  
  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
  );
  
  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
  );
  
  // Couleurs pour graphiques
  static const List<Color> chartColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFFA726),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFFEB3B),
    Color(0xFF795548),
  ];
}