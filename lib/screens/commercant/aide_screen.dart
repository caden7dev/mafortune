import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/custom_bottom_nav.dart'; // ✅ Import

class AideScreen extends StatefulWidget {
  const AideScreen({super.key});

  @override
  State<AideScreen> createState() => _AideScreenState();
}

class _AideScreenState extends State<AideScreen> {
  final List<Map<String, dynamic>> _faqItems = [
    {
      'question': 'Comment ajouter une recette ?',
      'answer': 'Sur l\'écran d\'accueil, cliquez sur le bouton "Nouvelle Recette". Remplissez le montant, la catégorie, la description et la date, puis cliquez sur "Enregistrer".',
    },
    {
      'question': 'Comment modifier une transaction ?',
      'answer': 'Sur l\'écran d\'accueil, dans la liste des transactions récentes, cliquez sur le bouton "Modifier" de la transaction que vous souhaitez modifier.',
    },
    {
      'question': 'Comment supprimer une transaction ?',
      'answer': 'Sur l\'écran d\'accueil, dans la liste des transactions récentes, cliquez sur le bouton "Supprimer" de la transaction que vous souhaitez supprimer, puis confirmez la suppression.',
    },
    {
      'question': 'Comment consulter mes rapports ?',
      'answer': 'Appuyez sur l\'onglet "Rapports" en bas de l\'écran. Vous pouvez choisir entre rapport mensuel, trimestriel, annuel ou personnalisé.',
    },
    {
      'question': 'Comment modifier mon profil ?',
      'answer': 'Allez dans l\'onglet "Profil", puis cliquez sur "Modifier le profil". Vous pourrez modifier vos informations personnelles.',
    },
    {
      'question': 'Comment changer mon mot de passe ?',
      'answer': 'Dans l\'onglet "Profil", cliquez sur "Changer le mot de passe". Entrez votre mot de passe actuel et le nouveau mot de passe, puis confirmez.',
    },
    {
      'question': 'Mes données sont-elles sécurisées ?',
      'answer': 'Oui, toutes vos données sont chiffrées et stockées de manière sécurisée dans Firebase. Vos informations personnelles ne sont jamais partagées sans votre consentement.',
    },
    {
      'question': 'Comment exporter mes données ?',
      'answer': 'Allez dans l\'onglet "Profil" → "Confidentialité", puis cliquez sur "Exporter mes données". Un fichier JSON sera téléchargé avec toutes vos transactions.',
    },
  ];

  // ✅ Index de la barre de navigation (4 = Profil)
  int _currentIndex = 4;

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@mafortune.tg',
      query: 'subject=Demande d\'aide - MaFortune&body=Bonjour,%0D%0A%0D%0AJe souhaite obtenir de l\'aide concernant :%0D%0A%0D%0A',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Impossible d\'ouvrir l\'application email')),
      );
    }
  }

  Future<void> _makePhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+22890000000');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Impossible de passer l\'appel')),
      );
    }
  }

  Future<void> _openWebsite() async {
    final Uri websiteUri = Uri.parse('https://www.mafortune.tg');
    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Impossible d\'ouvrir le site web')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Aide & Support'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
              ),
              child: Column(
                children: [
                  const Icon(Icons.help_center, size: 60, color: AppColors.primaryGreen),
                  const SizedBox(height: 10),
                  Text(
                    'Comment pouvons-nous vous aider ?',
                    style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Consultez notre FAQ ou contactez-nous directement',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Contact Cards
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildContactCard(
                      icon: Icons.email,
                      title: 'Email',
                      subtitle: 'support@mafortune.tg',
                      color: Colors.blue,
                      onTap: _sendEmail,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildContactCard(
                      icon: Icons.phone,
                      title: 'Téléphone',
                      subtitle: '+228 90 00 00 00',
                      color: Colors.green,
                      onTap: _makePhoneCall,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildContactCard(
                      icon: Icons.language,
                      title: 'Site web',
                      subtitle: 'mafortune.tg',
                      color: Colors.orange,
                      onTap: _openWebsite,
                    ),
                  ),
                ],
              ),
            ),
            
            // FAQ Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.question_answer, color: AppColors.primaryGreen),
                  const SizedBox(width: 10),
                  Text(
                    'Questions fréquentes',
                    style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // FAQ List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _faqItems.length,
              itemBuilder: (context, index) {
                final faq = _faqItems[index];
                return _buildFaqItem(
                  question: faq['question'] as String,
                  answer: faq['answer'] as String,
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Feedback Section
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.feedback, size: 40, color: AppColors.primaryGreen),
                  const SizedBox(height: 10),
                  Text(
                    'Vous avez une suggestion ?',
                    style: AppTextStyles.h6,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Votre avis nous intéresse !',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📝 Formulaire de feedback à venir...')),
                        );
                      },
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Donner mon avis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
      // ✅ AJOUT DE LA BARRE DE NAVIGATION
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          
          // Navigation selon l'index
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
              // Déjà sur Profil/Aide
              break;
          }
        },
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline, color: AppColors.primaryGreen),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}