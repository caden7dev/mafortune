import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/custom_bottom_nav.dart';

class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({super.key});

  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  int _currentIndex = 4;

  final List<Map<String, dynamic>> _sections = [
    {
      'emoji': '📋',
      'titre': 'Acceptation des conditions',
      'texte':
          'En utilisant MaFortune, vous acceptez les présentes conditions d\'utilisation. Si vous n\'acceptez pas ces conditions, veuillez ne pas utiliser l\'application.',
    },
    {
      'emoji': '📱',
      'titre': 'Utilisation de l\'application',
      'texte':
          'MaFortune est destinée aux commerçants du secteur informel au Togo pour gérer leurs finances. Vous vous engagez à utiliser l\'application de manière légale et honnête.',
    },
    {
      'emoji': '👤',
      'titre': 'Votre compte',
      'texte':
          'Vous êtes responsable de la confidentialité de votre code PIN et de votre mot de passe. Ne partagez jamais vos identifiants avec une autre personne.',
    },
    {
      'emoji': '💰',
      'titre': 'Vos données financières',
      'texte':
          'Les données financières que vous saisissez dans MaFortune vous appartiennent. Nous ne les partageons pas avec des tiers sans votre consentement.',
    },
    {
      'emoji': '🔒',
      'titre': 'Sécurité',
      'texte':
          'Nous faisons tout notre possible pour protéger vos données. Cependant, aucun système n\'est infaillible. Utilisez un mot de passe fort et ne partagez pas votre téléphone.',
    },
    {
      'emoji': '🚫',
      'titre': 'Utilisations interdites',
      'texte':
          'Il est interdit d\'utiliser MaFortune pour des activités illégales, de tenter de pirater l\'application, ou d\'usurper l\'identité d\'un autre utilisateur.',
    },
    {
      'emoji': '🔄',
      'titre': 'Modifications',
      'texte':
          'Nous pouvons modifier ces conditions à tout moment. Nous vous informerons des changements importants via une notification dans l\'application.',
    },
    {
      'emoji': '📞',
      'titre': 'Nous contacter',
      'texte':
          'Pour toute question sur ces conditions, contactez-nous à : contact@mafortune.tg ou au +228 90 00 00 00.',
    },
  ];

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '📄 Conditions d\'utilisation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
              ),
              child: Column(
                children: [
                  const Text('📄', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 14),
                  const Text(
                    'Conditions d\'utilisation',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dernière mise à jour : 1er janvier 2024',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Text('💡', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'En utilisant MaFortune, vous acceptez ces conditions.',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Sections ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(_sections.length, (i) {
                  final s = _sections[i];
                  return _buildSection(
                    emoji: s['emoji'] as String,
                    numero: '${i + 1}',
                    titre: s['titre'] as String,
                    texte: s['texte'] as String,
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // ── Footer acceptation ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    const Text(
                      'Vous avez accepté ces conditions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'En continuant à utiliser MaFortune, vous confirmez avoir lu et accepté ces conditions d\'utilisation.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '© 2024 MaFortune — Tous droits réservés',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
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
            case 0:
              Navigator.pushReplacementNamed(context, '/dashboard');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/bilans');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/rapports');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/alertes');
              break;
            case 4:
              break;
          }
        },
      ),
    );
  }

  // ─── SECTION ────────────────────────────────────────────────────────────────
  Widget _buildSection({
    required String emoji,
    required String numero,
    required String titre,
    required String texte,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: EdgeInsets.zero,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Numéro
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    numero,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(emoji, style: const TextStyle(fontSize: 22)),
            ],
          ),
          title: Text(
            titre,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          iconColor: AppColors.primaryGreen,
          collapsedIconColor: Colors.grey,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                texte,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}