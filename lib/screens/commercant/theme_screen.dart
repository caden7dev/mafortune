import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../widgets/custom_bottom_nav.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  final ThemeService _themeService = ThemeService();
  bool _isDarkMode = false;
  int _currentIndex = 4; // Profil

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    await _themeService.loadTheme();
    setState(() {
      _isDarkMode = _themeService.isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Détection du mode pour l'aperçu et les cartes
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final scaffoldColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);

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
            // ── HEADER ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: emeraldDark.withOpacity(0.08), // ✅ Fond doux harmonisé
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: emeraldDark.withOpacity(0.1), // ✅ Règle des 10%
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 40,
                      color: emeraldDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Apparence',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Personnalisez l\'apparence de l\'application',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── OPTIONS DE THÈME ────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildThemeOption(
                    icon: Icons.light_mode_rounded,
                    title: 'Thème clair',
                    description: 'Apparence lumineuse par défaut',
                    isSelected: !_isDarkMode,
                    onTap: () => _setTheme(false),
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  _buildThemeOption(
                    icon: Icons.dark_mode_rounded,
                    title: 'Thème sombre',
                    description: 'Apparence sombre pour une utilisation nocturne',
                    isSelected: _isDarkMode,
                    onTap: () => _setTheme(true),
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  _buildThemeOption(
                    icon: Icons.settings_suggest_rounded,
                    title: 'Suivre le système',
                    description: 'Utiliser le thème du système',
                    isSelected: false,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                          content: Text('Fonctionnalité à venir...', style: TextStyle(fontSize: 16)),
                          backgroundColor: terracotta, // ✅ Terre Cuite pour l'info
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.all(16),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── APERÇU ──────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: emeraldDark.withOpacity(0.1), // ✅ Règle des 10%
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.visibility_outlined, color: emeraldDark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Aperçu',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scaffoldColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: emeraldDark.withOpacity(0.1), // ✅ Règle des 10%
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.person_rounded, color: emeraldDark, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'John Doe',
                                    style: TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'Commerçant',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: emeraldDark.withOpacity(0.1), // ✅ Règle des 10%
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '100 000 F',
                                style: TextStyle(
                                  color: emeraldDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: emeraldDark.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: emeraldDark.withOpacity(0.15)),
                          ),
                          child: Center(
                            child: Text(
                              'Transaction récente...',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ),
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

  // ── OPTION DE THÈME ─────────────────────────────────────────────────────
  Widget _buildThemeOption({
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? emeraldDark.withOpacity(0.1) : Colors.transparent, // ✅ Règle des 10%
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? emeraldDark : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? emeraldDark : textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
                Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: emeraldDark,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setTheme(bool isDark) async {
    await _themeService.setTheme(isDark);
    setState(() {
      _isDarkMode = isDark;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // ✅ Texte propre sans émoji
          content: Text(isDark ? 'Thème sombre activé' : 'Thème clair activé', style: const TextStyle(fontSize: 16)),
          backgroundColor: emeraldDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}