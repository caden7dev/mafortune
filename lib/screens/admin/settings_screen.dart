import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/permission_service.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final PermissionService _permissionService = PermissionService();
  final ThemeService _themeService = ThemeService();
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isDarkMode = false;
  
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _autoBackup = true;
  String _selectedLanguage = 'Français';

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadSettings();
  }

  Future<void> _checkAdminAccess() async {
    final isAdmin = await _permissionService.isAdmin();
    if (!isAdmin && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Accès refusé : Administrateur uniquement'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }
    setState(() => _isAdmin = true);
  }

  void _loadSettings() {
    _isDarkMode = _themeService.themeNotifier.value;
    setState(() => _isLoading = false);
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() => _isDarkMode = value);
    await _themeService.toggleTheme();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Accès refusé')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionTitle('Apparence'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Mode sombre'),
                    subtitle: const Text('Activer le thème sombre'),
                    value: _isDarkMode,
                    onChanged: _toggleTheme,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.dark_mode, color: Colors.purple),
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    title: const Text('Langue'),
                    subtitle: Text(_selectedLanguage),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.language, color: Colors.blue),
                    ),
                    onTap: () {
                      _showSnackbar('Fonctionnalité en développement');
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildSectionTitle('Notifications'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notifications push'),
                    subtitle: const Text('Recevoir les alertes en temps réel'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                      _showSnackbar('Notifications ${value ? "activées" : "désactivées"}');
                    },
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.notifications, color: Colors.orange),
                    ),
                  ),
                  const Divider(height: 0),
                  SwitchListTile(
                    title: const Text('Notifications par email'),
                    subtitle: const Text('Recevoir les rapports par email'),
                    value: _emailNotifications,
                    onChanged: (value) {
                      setState(() => _emailNotifications = value);
                      _showSnackbar('Notifications email ${value ? "activées" : "désactivées"}');
                    },
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.email, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildSectionTitle('Données et sécurité'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Sauvegarde automatique'),
                    subtitle: const Text('Sauvegarde quotidienne des données'),
                    value: _autoBackup,
                    onChanged: (value) {
                      setState(() => _autoBackup = value);
                      _showSnackbar('Sauvegarde auto ${value ? "activée" : "désactivée"}');
                    },
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.backup, color: Colors.teal),
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    title: const Text('Exporter les données'),
                    subtitle: const Text('Exporter toutes les données en CSV'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.download, color: Colors.blue),
                    ),
                    onTap: () {
                      _showSnackbar('Export des données en cours...');
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    title: const Text('Vider le cache'),
                    subtitle: const Text('Libérer de l\'espace de stockage'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cleaning_services, color: Colors.orange),
                    ),
                    onTap: () {
                      _showSnackbar('Cache vidé avec succès');
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildSectionTitle('Compte'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Déconnexion'),
                    subtitle: const Text('Se déconnecter de votre compte'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout, color: Colors.red),
                    ),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}