import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Animations échelonnées (Staggered Animations)
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentFade;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _buttonFade;

  // 🎨 CHARTE GRAPHIQUE MA FORTUNE
  static const Color emeraldGreen = Color(0xFF0B4F36); // Sécurité & Structure
  static const Color terracotta = Color(0xFFD96B43);   // Chaleur & Action
  static const Color textDark = Color(0xFF333333);     // Lisibilité maximale
  static const Color textMedium = Color(0xFF555555);   // Sous-titres lisibles

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 1. Animation du Logo
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.45, curve: Curves.easeOutBack)),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.35, curve: Curves.easeOut)),
    );

    // 2. Animation du Contenu & Features
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.3, 0.75, curve: Curves.easeOutCubic)),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.3, 0.65, curve: Curves.easeOut)),
    );

    // 3. Animation des Boutons
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.55, 1.0, curve: Curves.easeOutCubic)),
    );
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.55, 0.9, curve: Curves.easeOut)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateTo(BuildContext context, String routeName, String fallbackMessage) {
    try {
      Navigator.pushNamed(context, routeName);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fallbackMessage),
          backgroundColor: textMedium,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 1. FOND : Blanc pur vers gris très clair (lumineux et accueillant)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF8F9FA)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          // ── Logo Épuré & Professionnel ──────────────────────
                          ScaleTransition(
                            scale: _logoScale,
                            child: FadeTransition(
                              opacity: _logoFade,
                              child: _buildLogo(),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Titre + Accroche ───────────────────────────────
                          SlideTransition(
                            position: _contentSlide,
                            child: FadeTransition(
                              opacity: _contentFade,
                              child: Column(
                                children: [
                                  // ✅ 3. TEXTES : Titre en Vert Émeraude, gras et grand
                                  const Text(
                                    'Ma Fortune',
                                    style: TextStyle(
                                      color: emeraldGreen,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // ✅ 3. TEXTES : Sous-titre en gris foncé très lisible
                                  const Text(
                                    'Gérez vos finances au quotidien,\nen toute simplicité et sécurité.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textMedium,
                                      fontSize: 16,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 40),

                                  // ── Points Forts (Design épuré) ────────────
                                  _buildFeatureTile(
                                    icon: Icons.insights_rounded,
                                    title: 'Suivi des gains',
                                    subtitle: 'Visualisez vos recettes en un coup d\'œil',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFeatureTile(
                                    icon: Icons.record_voice_over_rounded,
                                    title: 'Rapport vocal',
                                    subtitle: 'Votre bilan énoncé automatiquement',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFeatureTile(
                                    icon: Icons.wifi_off_rounded,
                                    title: 'Mode hors-ligne',
                                    subtitle: 'Fonctionne même sans connexion internet',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(flex: 3),
                          const SizedBox(height: 24),

                          // ── Boutons d'action (Charte respectée) ────────────
                          SlideTransition(
                            position: _buttonSlide,
                            child: FadeTransition(
                              opacity: _buttonFade,
                              child: Column(
                                children: [
                                  // ✅ 2. BOUTON PRINCIPAL : Terre Cuite, grand, arrondi
                                  _PressableButton(
                                    onTap: () => _navigateTo(
                                      context,
                                      '/signup',
                                      'Redirection vers l\'inscription (/signup)',
                                    ),
                                    backgroundColor: terracotta,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Créer un compte',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // ✅ 2. BOUTON SECONDAIRE : Outlined, Vert Émeraude
                                  _PressableButton(
                                    onTap: () => _navigateTo(
                                      context,
                                      '/login',
                                      'Redirection vers la connexion (/login)',
                                    ),
                                    backgroundColor: Colors.transparent,
                                    border: Border.all(color: emeraldGreen, width: 1.5),
                                    child: const Text(
                                      "J'ai déjà un compte",
                                      style: TextStyle(
                                        color: emeraldGreen,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ✅ Logo adapté au fond clair : fond vert 10% opacité, icône verte
  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: emeraldGreen.withOpacity(0.08), // Règle des 10% d'opacité
        border: Border.all(color: emeraldGreen.withOpacity(0.15), width: 2),
        boxShadow: [
          BoxShadow(
            color: emeraldGreen.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.account_balance_wallet_rounded,
          size: 48,
          color: emeraldGreen,
        ),
      ),
    );
  }

  // ✅ Tuile d'information : Fond blanc, ombre douce, icône verte sur fond clair
  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône avec fond arrondi à 10% d'opacité
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: emeraldGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: emeraldGreen, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textMedium,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bouton Dynamique avec Animation et Action Tactile ────────────────────────
class _PressableButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final Widget child;
  final Border? border;

  const _PressableButton({
    required this.onTap,
    required this.backgroundColor,
    required this.child,
    this.border,
  });

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) async {
        await _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 58, // ✅ Bouton légèrement plus grand pour l'ergonomie mobile
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(16), // ✅ Arrondi généreux
            border: widget.border,
            boxShadow: widget.border == null
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08), // Ombre douce et moderne
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}