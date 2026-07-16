import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/custom_bottom_nav.dart';

class AProposScreen extends StatefulWidget {
  const AProposScreen({super.key});

  @override
  State<AProposScreen> createState() => _AProposScreenState();
}

class _AProposScreenState extends State<AProposScreen> {
  int _currentIndex = 4;

  final List<String> _features = [
    '📊 Suivi de vos recettes et dépenses',
    '📈 Tableau de bord avec vos statistiques',
    '📑 Génération de rapports PDF',
    '🔔 Alertes et notifications',
    '🎯 Budget mensuel',
    '👤 Gestion du profil commerçant',
  ];

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Impossible d\'ouvrir la page',
                style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          'ℹ️ À propos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header logo ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('💰', style: TextStyle(fontSize: 52)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'MaFortune',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Gestion financière pour commerçants',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── À propos ─────────────────────────────────────────────────────
            _buildSection(
              emoji: 'ℹ️',
              title: 'À propos de MaFortune',
              child: Column(
                children: [
                  _buildParagraph(
                    'MaFortune est une application de gestion financière conçue pour les commerçants du secteur informel au Togo. Elle vous aide à suivre vos recettes et dépenses, générer des rapports et mieux gérer votre activité.',
                  ),
                  const SizedBox(height: 12),
                  _buildParagraph(
                    'Notre mission : digitaliser la gestion financière des petits commerçants pour les aider à prendre de meilleures décisions et à développer leur activité.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Fonctionnalités ───────────────────────────────────────────────
            _buildSection(
              emoji: '⭐',
              title: 'Fonctionnalités',
              child: Column(
                children: _features.map((f) => _buildFeatureItem(f)).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Liens utiles ─────────────────────────────────────────────────
            _buildSection(
              emoji: '🔗',
              title: 'Liens utiles',
              child: Column(
                children: [
                  _buildLinkItem(
                    emoji: '🌐',
                    title: 'Site web',
                    onTap: () => _openUrl('https://www.mafortune.tg'),
                  ),
                  _buildLinkItem(
                    emoji: '🔒',
                    title: 'Politique de confidentialité',
                    onTap: () =>
                        _openUrl('https://www.mafortune.tg/confidentialite'),
                  ),
                  _buildLinkItem(
                    emoji: '📄',
                    title: 'Conditions d\'utilisation',
                    onTap: () =>
                        _openUrl('https://www.mafortune.tg/conditions'),
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Informations légales ─────────────────────────────────────────
            _buildSection(
              emoji: '⚖️',
              title: 'Informations légales',
              child: Column(
                children: [
                  _buildInfoRow('👨‍💻', 'Développeur', 'MaFortune Team'),
                  _buildInfoRow('📧', 'Email', 'contact@mafortune.tg'),
                  _buildInfoRow('📞', 'Téléphone', '+228 90 00 00 00'),
                  _buildInfoRow('📅', 'Année', '2024'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Crédits ──────────────────────────────────────────────────────
            _buildSection(
              emoji: '👏',
              title: 'Crédits',
              child: Column(
                children: [
                  _buildCreditItem('Flutter', '📱', 'Framework de développement'),
                  _buildCreditItem('Firebase', '🔥', 'Base de données et auth'),
                  _buildCreditItem('fl_chart', '📊', 'Graphiques'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '© 2024 MaFortune — Tous droits réservés',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
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

  // ─── SECTION WRAPPER ─────────────────────────────────────────────────────────
  Widget _buildSection({
    required String emoji,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ─── PARAGRAPHE ──────────────────────────────────────────────────────────────
  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: Colors.grey[700],
      ),
    );
  }

  // ─── FEATURE ITEM ────────────────────────────────────────────────────────────
  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feature.substring(0, 2), // emoji
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature.substring(2).trim(),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIEN ────────────────────────────────────────────────────────────────────
  Widget _buildLinkItem({
    required String emoji,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[100]),
      ],
    );
  }

  // ─── INFO ROW ────────────────────────────────────────────────────────────────
  Widget _buildInfoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CREDIT ITEM ─────────────────────────────────────────────────────────────
  Widget _buildCreditItem(String name, String emoji, String role) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '— $role',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}