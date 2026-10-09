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
      duration: const Duration(milliseconds: 1000), // Un peu plus rapide
    );

    // 1. Animation du Logo
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );

    // 2. Animation du Contenu & Features
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );

    // 3. Animation des Boutons
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic)),
    );
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 0.9, curve: Curves.easeOut)),
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
    // ✅ Écran compact sans ScrollView pour tout voir d'un coup
    return Scaffold(
      body: Stack(
        children: [
          // 1. IMAGE D'ARRIÈRE-PLAN (Remplace 'welcome_bg.jpg' par ton image)
          Positioned.fill(
            child: Image.asset(
              'assets/image/welcome_bg.jpeg', // ⚠️ Mets ton image ici (ex: un marché, un commerçant, ou un fond abstrait vert)
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback si l'image n'existe pas encore : un beau dégradé
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE8F5E9), Colors.white],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. VOILE BLANC pour garantir la lisibilité du texte par-dessus l'image
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.88), // Ajuste entre 0.80 et 0.95 selon ton image
            ),
          ),

          // 3. CONTENU PRINCIPAL
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Centre tout verticalement
                children: [
                  const Spacer(flex: 1),

                  // ── Vrai Logo de l'App ──────────────────────
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: _buildRealLogo(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Titre + Accroche ───────────────────────
                  SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentFade,
                      child: Column(
                        children: [
                          const Text(
                            'Ma Fortune',
                            style: TextStyle(
                              color: emeraldGreen,
                              fontSize: 32, // Légèrement réduit pour gagner de la place
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gérez vos finances au quotidien,\nen toute simplicité et sécurité.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textMedium,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Points Forts (Compactés) ────────────
                          _buildFeatureTile(
                            icon: Icons.insights_rounded,
                            title: 'Suivi des gains',
                            subtitle: 'Visualisez vos recettes en un coup d\'œil',
                          ),
                          const SizedBox(height: 10),
                          _buildFeatureTile(
                            icon: Icons.wifi_off_rounded,
                            title: 'Mode hors-ligne',
                            subtitle: 'Fonctionne même sans connexion internet',
                          ),
                          const SizedBox(height: 10),
                          // ✅ REMPLACÉ : "Rapport vocal" supprimé, mis "Sécurité"
                          _buildFeatureTile(
                            icon: Icons.shield_outlined,
                            title: 'Sécurité maximale',
                            subtitle: 'Vos données sont protégées et chiffrées',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),
                  const SizedBox(height: 16),

                  // ── Boutons d'action ─────────────────────────
                  SlideTransition(
                    position: _buttonSlide,
                    child: FadeTransition(
                      opacity: _buttonFade,
                      child: Column(
                        children: [
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
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

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ VRAI LOGO DE L'APP
  Widget _buildRealLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: emeraldGreen.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: emeraldGreen.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/logoapp.jpg', // ⚠️ Assure-toi que ce chemin est exact
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback si l'image n'est pas trouvée
            return const Center(
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 40,
                color: emeraldGreen,
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ Tuile d'information compacte
  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: emeraldGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: emeraldGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textMedium,
                    fontSize: 12,
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
          height: 54, // Légèrement réduit pour gagner de la place verticale
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: widget.border,
            boxShadow: widget.border == null
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
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