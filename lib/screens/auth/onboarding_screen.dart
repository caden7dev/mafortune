import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/screenshot_wrapper.dart';

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
      'couleur': const Color(0xFF2E7D32),
      'couleurClaire': const Color(0xFFE8F5E9),
    },
    {
      'emoji': '💰',
      'titre': "J'ai vendu",
      'texte': 'Quand tu vends quelque chose,\nappuie sur le bouton vert',
      'couleur': const Color(0xFF2E7D32),
      'couleurClaire': const Color(0xFFE8F5E9),
    },
    {
      'emoji': '🛒',
      'titre': "J'ai dépensé",
      'texte': 'Quand tu achètes quelque chose,\nappuie sur le bouton rouge',
      'couleur': const Color(0xFFD32F2F),
      'couleurClaire': const Color(0xFFFFEBEE),
    },
    {
      'emoji': '📊',
      'titre': 'Vois ton argent',
      'texte': 'Regarde combien tu as gagné\net dépensé chaque jour',
      'couleur': const Color(0xFF1565C0),
      'couleurClaire': const Color(0xFFE3F2FD),
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
                      color: Colors.grey[500],
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),

            // Contenu des pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
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
                          : Colors.grey[300],
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
                    backgroundColor:
                        _pages[_currentPage]['couleur'] as Color,
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
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Texte explicatif — court et simple
          Text(
            page['texte'] as String,
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[700],
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}