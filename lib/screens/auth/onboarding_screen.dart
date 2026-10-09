import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/screenshot_wrapper.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE
const Color emeraldGreen = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);
const Color textMedium = Color(0xFF555555);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'emoji': '👋',
      'titre': 'Bienvenue sur MaFortune',
      'texte': 'Ton assistant pour gérer\nton argent au marché',
      'couleur': emeraldGreen,
      'couleurClaire': emeraldGreen.withOpacity(0.1), // ✅ Fond léger cohérent
    },
    {
      'emoji': '💰',
      'titre': "J'ai vendu",
      'texte': 'Quand tu vends quelque chose,\nappuie sur le bouton Terre Cuite',
      'couleur': terracotta,
      'couleurClaire': terracotta.withOpacity(0.1),
    },
    {
      'emoji': '🛒',
      'titre': "J'ai dépensé",
      'texte': 'Quand tu achètes quelque chose,\nappuie sur le bouton Rouge Brique',
      'couleur': brickRed,
      'couleurClaire': brickRed.withOpacity(0.1),
    },
    {
      'emoji': '📊',
      'titre': 'Vois ton argent',
      'texte': 'Regarde combien tu as gagné\net dépensé chaque jour',
      'couleur': emeraldGreen, // ✅ On revient à l'Émeraude pour le bilan (confiance)
      'couleurClaire': emeraldGreen.withOpacity(0.1),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _terminer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  void _pageSuivante() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _terminer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton passer en haut à droite
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _terminer,
                  child: Text(
                    'Passer',
                    style: TextStyle(
                      color: textMedium, // ✅ Couleur de texte secondaire
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Contenu des pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page);
                },
              ),
            ),

            // Indicateurs de page
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? _pages[_currentPage]['couleur'] as Color
                          : Colors.grey.shade300, // ✅ Gris clair standardisé
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Bouton suivant / commencer
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _pageSuivante,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage]['couleur'] as Color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1
                        ? 'Suivant →'
                        : '✅ Commencer',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> page) {
    final couleur = page['couleur'] as Color;
    final couleurClaire = page['couleurClaire'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Grande icône / emoji
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: couleurClaire,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                page['emoji'] as String,
                style: const TextStyle(fontSize: 90),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Titre
          Text(
            page['titre'] as String,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800, // ✅ Plus gras pour l'impact
              color: couleur,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Texte explicatif — court et simple
          Text(
            page['texte'] as String,
            style: TextStyle(
              fontSize: 18, // ✅ Légèrement ajusté pour une meilleure lisibilité
              color: textMedium, // ✅ Gris anthracite moyen de la charte
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}