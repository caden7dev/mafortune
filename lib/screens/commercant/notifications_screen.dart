import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/custom_bottom_nav.dart'; // ✅ Import du widget de navigation

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Paramètres de notifications
  bool _alertesDepenses = true;
  bool _rappelsPaiement = true;
  bool _objectifsAtteints = true;
  bool _promotions = false;
  bool _notificationsEmail = true;
  bool _notificationsPush = true;
  
  // ✅ Index de la barre de navigation (3 = Alertes)
  int _currentIndex = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications'),
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
                  const Icon(Icons.notifications_active, size: 60, color: AppColors.primaryGreen),
                  const SizedBox(height: 10),
                  Text(
                    'Préférences de notifications',
                    style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Personnalisez les alertes que vous souhaitez recevoir',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Alertes financières
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Alertes financières',
                      style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                    ),
                  ),
                  _buildNotificationOption(
                    icon: Icons.warning,
                    title: 'Alertes de dépenses élevées',
                    description: 'Recevez une alerte quand vos dépenses dépassent 30%',
                    value: _alertesDepenses,
                    onChanged: (val) => setState(() => _alertesDepenses = val),
                  ),
                  const Divider(height: 1),
                  _buildNotificationOption(
                    icon: Icons.calendar_today,
                    title: 'Rappels de paiement',
                    description: 'Soyez notifié avant les échéances importantes',
                    value: _rappelsPaiement,
                    onChanged: (val) => setState(() => _rappelsPaiement = val),
                  ),
                  const Divider(height: 1),
                  _buildNotificationOption(
                    icon: Icons.emoji_events,
                    title: 'Objectifs atteints',
                    description: 'Félicitations quand vous atteignez vos objectifs',
                    value: _objectifsAtteints,
                    onChanged: (val) => setState(() => _objectifsAtteints = val),
                  ),
                  const Divider(height: 1),
                  _buildNotificationOption(
                    icon: Icons.discount,
                    title: 'Promotions et offres',
                    description: 'Recevez des offres spéciales de nos partenaires',
                    value: _promotions,
                    onChanged: (val) => setState(() => _promotions = val),
                  ),
                ],
              ),
            ),
            
            // Canaux de notification
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'Canaux de notification',
                    style: AppTextStyles.h6.copyWith(color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 10),
                  _buildNotificationChannel(
                    icon: Icons.email,
                    title: 'Notifications par email',
                    value: _notificationsEmail,
                    onChanged: (val) => setState(() => _notificationsEmail = val),
                  ),
                  const SizedBox(height: 10),
                  _buildNotificationChannel(
                    icon: Icons.notifications,
                    title: 'Notifications push',
                    value: _notificationsPush,
                    onChanged: (val) => setState(() => _notificationsPush = val),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Bouton sauvegarder
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Préférences sauvegardées'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sauvegarder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
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
              // Déjà sur Alertes/Notifications
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profil');
              break;
          }
        },
      ),
    );
  }
  
  Widget _buildNotificationOption({
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
            child: Icon(icon, color: AppColors.primaryGreen, size: 20),
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
  
  Widget _buildNotificationChannel({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 15)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryGreen,
        ),
      ],
    );
  }
}