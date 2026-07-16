import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/custom_bottom_nav.dart';

class AideScreen extends StatefulWidget {
  const AideScreen({super.key});

  @override
  State<AideScreen> createState() => _AideScreenState();
}

class _AideScreenState extends State<AideScreen> {
  int _currentIndex = 4;

  final List<Map<String, dynamic>> _faqItems = [
    {
      'emoji': '➕',
      'question': 'Comment ajouter une recette ?',
      'answer':
          'Sur l\'écran d\'accueil, appuyez sur le bouton "Nouvelle Recette". Remplissez le montant, la catégorie et la date, puis appuyez sur "Enregistrer".',
    },
    {
      'emoji': '✏️',
      'question': 'Comment modifier une transaction ?',
      'answer':
          'Sur l\'écran d\'accueil, dans la liste des transactions récentes, appuyez sur "Modifier" à côté de la transaction à changer.',
    },
    {
      'emoji': '🗑️',
      'question': 'Comment supprimer une transaction ?',
      'answer':
          'Sur l\'écran d\'accueil, appuyez sur "Supprimer" à côté de la transaction, puis confirmez la suppression.',
    },
    {
      'emoji': '📊',
      'question': 'Comment consulter mes rapports ?',
      'answer':
          'Appuyez sur l\'onglet "Rapports" en bas de l\'écran. Vous pouvez choisir entre mensuel, trimestriel ou annuel.',
    },
    {
      'emoji': '👤',
      'question': 'Comment modifier mon profil ?',
      'answer':
          'Allez dans l\'onglet "Profil", puis appuyez sur "Modifier mon profil". Vous pouvez changer votre nom, téléphone et photo.',
    },
    {
      'emoji': '🔐',
      'question': 'Comment changer mon mot de passe ?',
      'answer':
          'Dans l\'onglet "Profil", appuyez sur "Changer le mot de passe". Entrez votre mot de passe actuel et le nouveau, puis confirmez.',
    },
    {
      'emoji': '🔒',
      'question': 'Mes données sont-elles sécurisées ?',
      'answer':
          'Oui. Toutes vos données sont chiffrées et stockées en sécurité dans Firebase. Vos informations ne sont jamais partagées sans votre accord.',
    },
    {
      'emoji': '📤',
      'question': 'Comment exporter mes données ?',
      'answer':
          'Allez dans "Profil" → "Confidentialité", puis appuyez sur "Exporter mes données". Un fichier avec toutes vos transactions sera téléchargé.',
    },
  ];

  Future<void> _sendEmail() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'support@mafortune.tg',
      query:
          'subject=Demande d\'aide - MaFortune&body=Bonjour,%0D%0A%0D%0AJe souhaite obtenir de l\'aide concernant :%0D%0A%0D%0A',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('Impossible d\'ouvrir l\'application email');
    }
  }

  Future<void> _makePhoneCall() async {
    final Uri uri = Uri(scheme: 'tel', path: '+22890000000');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('Impossible de passer l\'appel');
    }
  }

  Future<void> _openWebsite() async {
    final Uri uri = Uri.parse('https://www.mafortune.tg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('Impossible d\'ouvrir le site web');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $msg', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ),
    );
  }

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
          '❓ Aide & Support',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  const Text('🆘', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 14),
                  const Text(
                    'Comment pouvons-nous\nvous aider ?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Consultez la FAQ ou contactez-nous directement.',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey[600], height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Contacts ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 14),
                    child: Text(
                      'Nous contacter',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactCard(
                          emoji: '📧',
                          title: 'Email',
                          subtitle: 'support@\nmafortune.tg',
                          color: Colors.blue,
                          onTap: _sendEmail,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildContactCard(
                          emoji: '📞',
                          title: 'Téléphone',
                          subtitle: '+228\n90 00 00 00',
                          color: AppColors.primaryGreen,
                          onTap: _makePhoneCall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildContactCard(
                          emoji: '🌐',
                          title: 'Site web',
                          subtitle: 'mafortune.tg',
                          color: Colors.orange,
                          onTap: _openWebsite,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── FAQ ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 14),
                    child: Text(
                      'Questions fréquentes',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                  ...(_faqItems.map((faq) => _buildFaqItem(
                        emoji: faq['emoji'] as String,
                        question: faq['question'] as String,
                        answer: faq['answer'] as String,
                      ))),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Feedback ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    const Text('💬', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text(
                      'Vous avez une suggestion ?',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Votre avis nous aide à améliorer MaFortune.',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📝 Formulaire de feedback à venir...',
                                  style: TextStyle(fontSize: 16)),
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('⭐', style: TextStyle(fontSize: 22)),
                            SizedBox(width: 10),
                            Text('Donner mon avis',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
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

  // ─── CARTE CONTACT ───────────────────────────────────────────────────────────
  Widget _buildContactCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── FAQ ITEM ────────────────────────────────────────────────────────────────
  Widget _buildFaqItem({
    required String emoji,
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Theme(
        // Supprime le divider par défaut de ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Text(emoji, style: const TextStyle(fontSize: 26)),
          title: Text(
            question,
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
                color: AppColors.primaryGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}