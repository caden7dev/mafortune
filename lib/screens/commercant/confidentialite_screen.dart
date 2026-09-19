import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_bottom_nav.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux (Actions destructives)
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // ✅ Fond gris très clair et doux
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
            Icon(Icons.shield_outlined, size: 22, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Confidentialité',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: BoxDecoration(
                color: emeraldDark.withOpacity(0.08), // ✅ Règle des 10%
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: emeraldDark.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_rounded, size: 48, color: emeraldDark),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Vos données sont protégées',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gérez comment vos informations sont utilisées.',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── OPTIONS VIE PRIVÉE ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.tune_rounded, 'Mes préférences'),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        _buildToggleOption(
                          icon: Icons.analytics_outlined,
                          title: 'Partager des statistiques anonymes',
                          description: 'Aidez-nous à améliorer MaFortune en partageant des données d\'utilisation sans nom.',
                          value: _partagerStats,
                          onChanged: (v) => setState(() => _partagerStats = v),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 20, endIndent: 20),
                        _buildToggleOption(
                          icon: Icons.data_usage_outlined,
                          title: 'Collecte des données d\'utilisation',
                          description: 'Nous utilisons ces données pour améliorer vos recommandations.',
                          value: _collecterDonnees,
                          onChanged: (v) => setState(() => _collecterDonnees = v),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 20, endIndent: 20),
                        _buildToggleOption(
                          icon: Icons.lock_rounded,
                          title: 'Notifications sur écran verrouillé',
                          description: 'Afficher le contenu de vos notifications quand le téléphone est verrouillé.',
                          value: _notificationsSecrets,
                          onChanged: (v) => setState(() => _notificationsSecrets = v),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── PROTECTION DES DONNÉES ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.shield_outlined, 'Protection des données'),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        _buildProtectionItem(
                          icon: Icons.vpn_key_outlined,
                          title: 'Chiffrement des données',
                          description: 'Vos données sont chiffrées de bout en bout.',
                        ),
                        const SizedBox(height: 14),
                        _buildProtectionItem(
                          icon: Icons.fingerprint_rounded,
                          title: 'Authentification biométrique',
                          description: 'Utilisez votre empreinte digitale pour vous connecter.',
                        ),
                        const SizedBox(height: 14),
                        _buildProtectionItem(
                          icon: Icons.cloud_done_outlined,
                          title: 'Sauvegarde automatique',
                          description: 'Vos données sont sauvegardées chaque jour.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── GESTION DES DONNÉES ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.folder_open_outlined, 'Gestion de mes données'),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        // Exporter
                        _buildActionItem(
                          icon: Icons.download_rounded,
                          title: 'Exporter mes données',
                          subtitle: 'Télécharger toutes mes transactions en JSON',
                          color: emeraldDark,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📥 Export en cours...', style: TextStyle(fontSize: 16)),
                                backgroundColor: emeraldDark,
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 20, endIndent: 20),
                        // Supprimer
                        _buildActionItem(
                          icon: Icons.delete_outline_rounded,
                          title: 'Supprimer toutes mes données',
                          subtitle: 'Cette action est irréversible',
                          color: brickRed, // ✅ Rouge Brique pour les actions destructives
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

  // ─── TITRE SECTION ───────────────────────────────────────────────────────────
  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
        ),
      ],
    );
  }

  // ─── OPTION TOGGLE ────────────────────────────────────────────────────────────
  Widget _buildToggleOption({
    required IconData icon,
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
          // ✅ Icône dans cercle à 10% d'opacité
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: emeraldDark.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: Icon(icon, color: emeraldDark, size: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ✅ Switch harmonisé avec la charte
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: emeraldDark,
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  // ─── ITEM PROTECTION ─────────────────────────────────────────────────────────
  Widget _buildProtectionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: emeraldDark.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: emeraldDark, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
              ),
            ],
          ),
        ),
        // ✅ Badge "Actif" harmonisé
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: emeraldDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: emeraldDark),
              const SizedBox(width: 4),
              const Text(
                'Actif',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: emeraldDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── ITEM ACTION ─────────────────────────────────────────────────────────────
  Widget _buildActionItem({
    required IconData icon,
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
                color: color.withOpacity(0.1), // ✅ Règle des 10%
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icon, color: color, size: 22)),
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
                      color: isDestructive ? brickRed : textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDestructive ? brickRed.withOpacity(0.7) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDestructive ? brickRed.withOpacity(0.4) : Colors.grey[400]),
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
            // ✅ Icône d'avertissement dans un cercle à 10% d'opacité
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brickRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 48, color: brickRed),
            ),
            const SizedBox(height: 16),
            const Text(
              'Supprimer toutes\nles données ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: brickRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Toutes vos transactions et données personnelles seront supprimées définitivement. Cette action est irréversible.',
                style: TextStyle(fontSize: 14, color: brickRed.withOpacity(0.9), height: 1.5),
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
                      content: Text('🗑️ Suppression en cours...', style: TextStyle(fontSize: 16)),
                      backgroundColor: brickRed,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brickRed, // ✅ Rouge Brique
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Supprimer définitivement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textDark,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}