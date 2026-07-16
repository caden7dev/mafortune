import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_bottom_nav.dart';

class ConfidentialiteScreen extends StatefulWidget {
  const ConfidentialiteScreen({super.key});

  @override
  State<ConfidentialiteScreen> createState() => _ConfidentialiteScreenState();
}

class _ConfidentialiteScreenState extends State<ConfidentialiteScreen> {
  final AuthService _authService = AuthService();

  bool _partagerStats = false;
  bool _collecterDonnees = true;
  bool _notificationsSecrets = true;

  int _currentIndex = 4;

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
          '🔒 Confidentialité',
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
                  const Text('🛡️', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 14),
                  const Text(
                    'Vos données sont protégées',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gérez comment vos informations sont utilisées.',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey[600], height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Options vie privée ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('⚙️', 'Mes préférences'),
                  const SizedBox(height: 14),
                  Container(
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
                        _buildToggleOption(
                          emoji: '📊',
                          title: 'Partager des statistiques anonymes',
                          description:
                              'Aidez-nous à améliorer MaFortune en partageant des données d\'utilisation sans nom.',
                          value: _partagerStats,
                          onChanged: (v) =>
                              setState(() => _partagerStats = v),
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey[100],
                            indent: 20,
                            endIndent: 20),
                        _buildToggleOption(
                          emoji: '📈',
                          title: 'Collecte des données d\'utilisation',
                          description:
                              'Nous utilisons ces données pour améliorer vos recommandations.',
                          value: _collecterDonnees,
                          onChanged: (v) =>
                              setState(() => _collecterDonnees = v),
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey[100],
                            indent: 20,
                            endIndent: 20),
                        _buildToggleOption(
                          emoji: '🔔',
                          title: 'Notifications sur écran verrouillé',
                          description:
                              'Afficher le contenu de vos notifications quand le téléphone est verrouillé.',
                          value: _notificationsSecrets,
                          onChanged: (v) =>
                              setState(() => _notificationsSecrets = v),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Protection des données ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('🛡️', 'Protection des données'),
                  const SizedBox(height: 14),
                  Container(
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
                        _buildProtectionItem(
                          emoji: '🔐',
                          title: 'Chiffrement des données',
                          description:
                              'Vos données sont chiffrées de bout en bout.',
                        ),
                        const SizedBox(height: 14),
                        _buildProtectionItem(
                          emoji: '👆',
                          title: 'Authentification biométrique',
                          description:
                              'Utilisez votre empreinte digitale pour vous connecter.',
                        ),
                        const SizedBox(height: 14),
                        _buildProtectionItem(
                          emoji: '☁️',
                          title: 'Sauvegarde automatique',
                          description:
                              'Vos données sont sauvegardées chaque jour.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Gestion des données ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('🗂️', 'Gestion de mes données'),
                  const SizedBox(height: 14),
                  Container(
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
                        // Exporter
                        _buildActionItem(
                          emoji: '📥',
                          title: 'Exporter mes données',
                          subtitle: 'Télécharger toutes mes transactions en JSON',
                          color: AppColors.primaryGreen,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '📥 Export en cours...',
                                  style: TextStyle(fontSize: 16),
                                ),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                          },
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey[100],
                            indent: 20,
                            endIndent: 20),
                        // Supprimer
                        _buildActionItem(
                          emoji: '🗑️',
                          title: 'Supprimer toutes mes données',
                          subtitle: 'Cette action est irréversible',
                          color: Colors.red,
                          onTap: _showDeleteConfirmation,
                          isDestructive: true,
                        ),
                      ],
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

  // ─── TITRE SECTION ───────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // ─── OPTION TOGGLE ────────────────────────────────────────────────────────────
  Widget _buildToggleOption({
    required String emoji,
    required String title,
    required String description,
    required bool value,
    required Function(bool) onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji dans cercle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),

          const SizedBox(width: 14),

          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Switch
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  // ─── ITEM PROTECTION ─────────────────────────────────────────────────────────
  Widget _buildProtectionItem({
    required String emoji,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        // Badge vert "Actif"
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '✅ Actif',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  // ─── ITEM ACTION ─────────────────────────────────────────────────────────────
  Widget _buildActionItem({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDestructive
                          ? Colors.red.withOpacity(0.7)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16,
                color: isDestructive ? Colors.red[200] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ─── DIALOG SUPPRESSION ──────────────────────────────────────────────────────
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text(
              'Supprimer toutes\nles données ?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Toutes vos transactions et données personnelles seront supprimées définitivement. Cette action est irréversible.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[800],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '🗑️ Suppression en cours...',
                        style: TextStyle(fontSize: 16),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Supprimer définitivement',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}