import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_bottom_nav.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux (Erreurs)
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

class AProposScreen extends StatefulWidget {
  const AProposScreen({super.key});

  @override
  State<AProposScreen> createState() => _AProposScreenState();
}

class _AProposScreenState extends State<AProposScreen> {
  int _currentIndex = 4;

  // ✅ Remplacement des émojis par des icônes Material Design
  final List<Map<String, dynamic>> _features = [
    {'icon': Icons.analytics_outlined, 'text': 'Suivi de vos recettes et dépenses'},
    {'icon': Icons.bar_chart_rounded, 'text': 'Tableau de bord avec vos statistiques'},
    {'icon': Icons.picture_as_pdf_outlined, 'text': 'Génération de rapports PDF'},
    {'icon': Icons.notifications_active_outlined, 'text': 'Alertes et notifications'},
    {'icon': Icons.flag_outlined, 'text': 'Budget mensuel'},
    {'icon': Icons.person_outline, 'text': 'Gestion du profil commerçant'},
  ];

  Future<void> _openUrl(String url, String title) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir la page : $title', style: const TextStyle(fontSize: 16)),
            backgroundColor: brickRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // ✅ Fond gris très clair
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
            Icon(Icons.info_outline, size: 22, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'À propos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
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
                color: emeraldDark.withOpacity(0.08),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: emeraldDark,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: emeraldDark.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 52),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'MaFortune',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: emeraldDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: emeraldDark.withOpacity(0.1), // ✅ Règle des 10%
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: emeraldDark,
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
              icon: Icons.info_outline,
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
              icon: Icons.star_outline,
              title: 'Fonctionnalités',
              child: Column(
                children: _features.map((f) => _buildFeatureItem(
                  icon: f['icon'] as IconData,
                  text: f['text'] as String,
                )).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Liens utiles ─────────────────────────────────────────────────
            _buildSection(
              icon: Icons.link,
              title: 'Liens utiles',
              child: Column(
                children: [
                  _buildLinkItem(
                    icon: Icons.language_outlined,
                    title: 'Site web',
                    onTap: () => _openUrl('https://www.mafortune.tg', 'Site web'),
                  ),
                  _buildLinkItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Politique de confidentialité',
                    // ✅ VRAI LIEN NOTION MIS À JOUR (sans le ?source=copy_link pour faire plus propre)
                    onTap: () => _openUrl(
                      'https://garnet-stone-55f.notion.site/Politique-de-Confidentialit-MaFortune-3e9256a556ad80409f3ad78e0a6c6e70', 
                      'Politique de confidentialité'
                    ),
                  ),
                  _buildLinkItem(
                    icon: Icons.description_outlined,
                    title: 'Conditions d\'utilisation',
                    // ✅ Utilise le même lien pour l'instant pour éviter les erreurs
                    onTap: () => _openUrl(
                      'https://garnet-stone-55f.notion.site/Politique-de-Confidentialit-MaFortune-3e9256a556ad80409f3ad78e0a6c6e70', 
                      'Conditions d\'utilisation'
                    ),
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Informations légales ─────────────────────────────────────────
            _buildSection(
              icon: Icons.gavel_outlined,
              title: 'Informations légales',
              child: Column(
                children: [
                  _buildInfoRow(icon: Icons.code_rounded, label: 'Développeur', value: 'MaFortune Team'),
                  // ✅ EMAIL PERSONNEL MIS À JOUR
                  _buildInfoRow(icon: Icons.email_outlined, label: 'Email', value: 'ahadzicaden7@gmail.com'),
                  // ✅ LIGNE TÉLÉPHONE SUPPRIMÉE POUR PROTÉGER TA VIE PRIVÉE
                  _buildInfoRow(icon: Icons.calendar_today_outlined, label: 'Année', value: '2024', isLast: true),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Crédits ──────────────────────────────────────────────────────
            _buildSection(
              icon: Icons.volunteer_activism_outlined,
              title: 'Crédits',
              child: Column(
                children: [
                  _buildCreditItem(name: 'Flutter', icon: Icons.smartphone_rounded, role: 'Framework de développement'),
                  _buildCreditItem(name: 'Firebase', icon: Icons.local_fire_department_outlined, role: 'Base de données et auth'),
                  _buildCreditItem(name: 'fl_chart', icon: Icons.pie_chart_outline, role: 'Graphiques', isLast: true),
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

  // ─── SECTION WRAPPER ─────────────────────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ Icône de section avec règle des 10%
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: emeraldDark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: emeraldDark, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
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
  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Icône avec règle des 10%
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: emeraldDark.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: emeraldDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: textDark,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIEN ────────────────────────────────────────────────────────────────────
  Widget _buildLinkItem({
    required IconData icon,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: terracotta.withOpacity(0.1), // ✅ Règle des 10% (Terre Cuite pour les liens)
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: terracotta, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[100]),
      ],
    );
  }

  // ─── INFO ROW ────────────────────────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon, 
    required String label, 
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
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
                  color: textDark,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[100]),
      ],
    );
  }

  // ─── CREDIT ITEM ─────────────────────────────────────────────────────────────
  Widget _buildCreditItem({
    required String name, 
    required IconData icon, 
    required String role,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: emeraldDark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: emeraldDark, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textDark,
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
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[100]),
      ],
    );
  }
}