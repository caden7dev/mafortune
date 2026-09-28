import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/custom_bottom_nav.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  final ThemeService _themeService = ThemeService();
  final AuthService _authService = AuthService();
  
  bool _isDarkMode = false;
  bool _isSystemMode = false;
  int _currentIndex = 4;
  
  UtilisateurModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndTheme();
  }

  Future<void> _loadUserAndTheme() async {
    _currentUser = await _authService.getCurrentUserData();
    await _themeService.loadTheme();
    
    if (mounted) {
      final systemIsDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      setState(() {
        _isDarkMode = _themeService.isDarkMode;
        _isSystemMode = (_isDarkMode == systemIsDark); 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final scaffoldColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : textDark;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final dividerColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final headerBgColor = isDark ? emeraldDark.withOpacity(0.15) : emeraldDark.withOpacity(0.08);

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.palette_outlined, size: 22, color: Colors.white),
            SizedBox(width: 8),
            Text('Thème', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: headerBgColor),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: emeraldDark.withOpacity(0.1), 
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 40,
                      color: emeraldDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Apparence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text('Personnalisez l\'apparence de l\'application', style: TextStyle(color: subTextColor, fontSize: 15), textAlign: TextAlign.center),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  _buildThemeOption(icon: Icons.light_mode_rounded, title: 'Thème clair', description: 'Apparence lumineuse par défaut', isSelected: !_isDarkMode && !_isSystemMode, textColor: textColor, subTextColor: subTextColor, onTap: () => _setTheme(false, false)),
                  Divider(height: 1, color: dividerColor),
                  _buildThemeOption(icon: Icons.dark_mode_rounded, title: 'Thème sombre', description: 'Apparence sombre pour une utilisation nocturne', isSelected: _isDarkMode && !_isSystemMode, textColor: textColor, subTextColor: subTextColor, onTap: () => _setTheme(true, false)),
                  Divider(height: 1, color: dividerColor),
                  _buildThemeOption(icon: Icons.settings_suggest_rounded, title: 'Suivre le système', description: 'Utiliser le thème de votre téléphone', isSelected: _isSystemMode, textColor: textColor, subTextColor: subTextColor, onTap: () {
                    final systemIsDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
                    _setTheme(systemIsDark, true);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.visibility_outlined, color: emeraldDark, size: 20)),
                      const SizedBox(width: 12),
                      Text('Aperçu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: scaffoldColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: dividerColor)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(width: 40, height: 40, decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.person_rounded, color: emeraldDark, size: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_currentUser?.nomComplet ?? 'Chargement...', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(_currentUser?.typeActivite ?? 'Commerçant', style: TextStyle(color: subTextColor, fontSize: 12)),
                                ],
                              ),
                            ),
                            // ✅ CORRECTION : Affichage du VRAI solde de l'utilisateur
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                '${NumberFormat('#,###', 'fr_FR').format((_currentUser?.soldeActuel ?? 0).toInt()).replaceAll(',', ' ')} F',
                                style: const TextStyle(color: emeraldDark, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          height: 60,
                          decoration: BoxDecoration(color: emeraldDark.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: emeraldDark.withOpacity(0.15))),
                          child: Center(child: Text('Transaction récente...', style: TextStyle(color: subTextColor, fontSize: 13))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0: Navigator.pushReplacementNamed(context, '/dashboard'); break;
            case 1: Navigator.pushReplacementNamed(context, '/bilans'); break;
            case 2: Navigator.pushReplacementNamed(context, '/rapports'); break;
            case 3: Navigator.pushReplacementNamed(context, '/alertes'); break;
            case 4: break;
          }
        },
      ),
    );
  }

  Widget _buildThemeOption({required IconData icon, required String title, required String description, required bool isSelected, required Color textColor, required Color? subTextColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isSelected ? emeraldDark.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: isSelected ? emeraldDark : subTextColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isSelected ? emeraldDark : textColor)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, color: subTextColor)),
              ]),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: emeraldDark, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _setTheme(bool isDark, bool isSystem) async {
    await _themeService.setTheme(isDark);
    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
        _isSystemMode = isSystem;
      });
      String message = isSystem ? 'Thème du système activé' : (isDark ? 'Thème sombre activé' : 'Thème clair activé');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontSize: 16)), backgroundColor: emeraldDark, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
    }
  }
}