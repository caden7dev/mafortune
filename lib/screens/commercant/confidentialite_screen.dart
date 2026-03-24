import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_bottom_nav.dart'; // ✅ Import

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
  
  // ✅ Index de la barre de navigation (4 = Profil)
  int _currentIndex = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Confidentialité'),
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
                  const Icon(Icons.security, size: 60, color: AppColors.primaryGreen),
                  const SizedBox(height: 10),
                  Text(
                    'Confidentialité des données',
                    style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Gérez comment vos données sont utilisées et protégées',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Options de confidentialité
            Container(
              margin: const EdgeInsets.all(20),
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
                  _buildPrivacyOption(
                    icon: Icons.analytics,
                    title: 'Partager les statistiques anonymes',
                    description: 'Aidez à améliorer l\'application en partageant des données d\'utilisation anonymes',
                    value: _partagerStats,
                    onChanged: (val) => setState(() => _partagerStats = val),
                  ),
                  const Divider(height: 1),
                  _buildPrivacyOption(
                    icon: Icons.data_usage,
                    title: 'Collecte des données d\'utilisation',
                    description: 'Nous collectons des données pour améliorer vos recommandations',
                    value: _collecterDonnees,
                    onChanged: (val) => setState(() => _collecterDonnees = val),
                  ),
                  const Divider(height: 1),
                  _buildPrivacyOption(
                    icon: Icons.notifications,
                    title: 'Notifications sensibles',
                    description: 'Afficher le contenu des notifications sur l\'écran verrouillé',
                    value: _notificationsSecrets,
                    onChanged: (val) => setState(() => _notificationsSecrets = val),
                  ),
                ],
              ),
            ),
            
            // Protection des données
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
                      const Icon(Icons.lock, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Text(
                        'Protection des données',
                        style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildDataProtectionItem(
                    title: 'Chiffrement des données',
                    description: 'Vos données sont chiffrées de bout en bout',
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 10),
                  _buildDataProtectionItem(
                    title: 'Authentification biométrique',
                    description: 'Utilisez votre empreinte digitale pour vous connecter',
                    icon: Icons.fingerprint,
                  ),
                  const SizedBox(height: 10),
                  _buildDataProtectionItem(
                    title: 'Sauvegarde automatique',
                    description: 'Vos données sont sauvegardées quotidiennement',
                    icon: Icons.backup,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Export des données
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
                  const Text(
                    'Gestion des données',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.download, color: AppColors.primaryGreen),
                    ),
                    title: const Text('Exporter mes données'),
                    subtitle: const Text('Téléchargez toutes vos données au format JSON'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📥 Export des données en cours...')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever, color: Colors.red),
                    ),
                    title: const Text('Supprimer toutes mes données', style: TextStyle(color: Colors.red)),
                    subtitle: const Text('Cette action est irréversible'),
                    onTap: () {
                      _showDeleteConfirmation(context);
                    },
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
              // Déjà sur Profil/Confidentialité
              break;
          }
        },
      ),
    );
  }
  
  Widget _buildPrivacyOption({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDataProtectionItem({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
  
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer toutes les données'),
        content: const Text(
          'Cette action supprimera définitivement toutes vos transactions et données personnelles. '
          'Cette action est irréversible. Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🗑️ Suppression en cours...')),
              );
              // TODO: Implémenter la suppression des données
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}