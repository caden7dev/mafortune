import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/custom_bottom_nav.dart'; // ✅ Import

class AProposScreen extends StatefulWidget {
  const AProposScreen({super.key});

  @override
  State<AProposScreen> createState() => _AProposScreenState();
}

class _AProposScreenState extends State<AProposScreen> {
  final List<Map<String, dynamic>> _versions = [
    {
      'version': '1.0.0',
      'date': '15 Mars 2024',
      'features': [
        '✨ Première version de l\'application',
        '📊 Gestion des recettes et dépenses',
        '📈 Tableau de bord avec statistiques',
        '📑 Génération de rapports',
        '🔔 Système d\'alertes',
        '👤 Gestion du profil utilisateur',
      ],
    },
  ];

  // ✅ Index de la barre de navigation (4 = Profil)
  int _currentIndex = 4;

  Future<void> _openWebsite() async {
    final Uri uri = Uri.parse('https://www.mafortune.tg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Impossible d\'ouvrir le site web')),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri uri = Uri.parse('https://www.mafortune.tg/confidentialite');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Impossible d\'ouvrir la page')),
      );
    }
  }

  Future<void> _openTerms() async {
    final Uri uri = Uri.parse('https://www.mafortune.tg/conditions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Impossible d\'ouvrir la page')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('À propos'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Logo et nom de l'application
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Center(
                      child: Text(
                        '💰',
                        style: TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'MaFortune',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Gestion financière pour commerçants',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            // Description
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Text(
                        'À propos de MaFortune',
                        style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'MaFortune est une application de gestion financière conçue spécialement pour les commerçants du secteur informel au Togo. '
                    'Elle vous aide à suivre vos recettes et dépenses, générer des rapports et mieux gérer votre activité.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Notre mission est de digitaliser la gestion financière des petits commerçants pour les aider à prendre de meilleures décisions et à développer leur activité.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            
            // Fonctionnalités
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Text(
                        'Fonctionnalités',
                        style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ..._versions.first['features'].map<Widget>((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 16)),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Liens utiles
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Text(
                        'Liens utiles',
                        style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildLinkItem(
                    icon: Icons.language,
                    title: 'Site web',
                    onTap: _openWebsite,
                  ),
                  _buildLinkItem(
                    icon: Icons.privacy_tip,
                    title: 'Politique de confidentialité',
                    onTap: _openPrivacyPolicy,
                  ),
                  _buildLinkItem(
                    icon: Icons.description,
                    title: 'Conditions d\'utilisation',
                    onTap: _openTerms,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Informations légales
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gavel, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Text(
                        'Informations légales',
                        style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildInfoRow('Développeur', 'MaFortune Team'),
                  _buildInfoRow('Email', 'contact@mafortune.tg'),
                  _buildInfoRow('Téléphone', '+228 90 00 00 00'),
                  _buildInfoRow('Année', '2024'),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Crédits
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.code, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Text(
                        'Crédits',
                        style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildCreditItem('Flutter', 'Framework de développement'),
                  _buildCreditItem('Firebase', 'Base de données et authentification'),
                  _buildCreditItem('Icons8', 'Icônes utilisées'),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '© 2024 MaFortune - Tous droits réservés',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
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
              // Déjà sur Profil/À propos
              break;
          }
        },
      ),
    );
  }

  Widget _buildLinkItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 22, color: AppColors.primaryGreen),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditItem(String name, String role) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}