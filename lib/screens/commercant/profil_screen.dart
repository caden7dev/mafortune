import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../models/utilisateur_model.dart';
import 'notifications_screen.dart';
import 'confidentialite_screen.dart';
import 'aide_screen.dart';
import 'a_propos_screen.dart';
import 'theme_screen.dart';
import 'modifier_profil_screen.dart';
import 'changer_mot_de_passe_screen.dart';
import 'gestion_categories_screen.dart';
import 'budget_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  UtilisateurModel? _currentUser;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _permissionService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUserData();
      setState(() => _currentUser = user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _modifierProfil() async {
    if (_currentUser == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModifierProfilScreen(currentUser: _currentUser!),
      ),
    );
    
    if (result == true) {
      await _loadProfile();
    }
  }

  Future<void> _changerMotDePasse() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangerMotDePasseScreen()),
    );
    
    if (result == true) {
      // Mot de passe changé avec succès
    }
  }

  Future<void> _changerPin() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité en cours de développement'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _gestionCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GestionCategoriesScreen()),
    );
  }

  Future<void> _budgetMensuel() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BudgetScreen()),
    );
  }

  Future<void> _deconnexion() async {
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
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  String _getInitial() {
    if (_currentUser == null) return '?';
    final name = _currentUser!.nomComplet;
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❌ Erreur de chargement'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header avec profil
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Column(
                  children: [
                    // ✅ AVATAR AVEC PHOTO DE PROFIL
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: _currentUser!.photo != null && _currentUser!.photo!.isNotEmpty
                            ? Image.network(
                                _currentUser!.photo!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      _getInitial(),
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  _getInitial(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _currentUser!.nomComplet,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _currentUser!.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentUser!.typeActivite ?? 'Commerçant',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Informations du profil
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInfoCard(
                      '📱 Téléphone',
                      _currentUser!.telephone,
                    ),
                    _buildInfoCard(
                      '📍 Adresse',
                      _currentUser!.adresse ?? 'Non renseignée',
                    ),
                    _buildInfoCard(
                      '🏪 Activité',
                      _currentUser!.typeActivite ?? 'Non renseignée',
                    ),
                    _buildInfoCard(
                      '💰 Solde actuel',
                      '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Options du menu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paramètres',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildMenuOption(
                      icon: Icons.edit,
                      title: 'Modifier le profil',
                      onTap: _modifierProfil,
                    ),
                    _buildMenuOption(
                      icon: Icons.lock,
                      title: 'Changer le mot de passe',
                      onTap: _changerMotDePasse,
                    ),
                    _buildMenuOption(
                      icon: Icons.pin,
                      title: 'Changer le code PIN',
                      onTap: _changerPin,
                    ),
                    _buildMenuOption(
                      icon: Icons.category,
                      title: 'Gérer les catégories',
                      onTap: _gestionCategories,
                    ),
                    _buildMenuOption(
                      icon: Icons.flag,
                      title: 'Budget mensuel',
                      onTap: _budgetMensuel,
                    ),
                    _buildMenuOption(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuOption(
                      icon: Icons.security,
                      title: 'Confidentialité',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ConfidentialiteScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuOption(
                      icon: Icons.palette,
                      title: 'Thème',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ThemeScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuOption(
                      icon: Icons.help,
                      title: 'Aide & Support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AideScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuOption(
                      icon: Icons.info,
                      title: 'À propos',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AProposScreen(),
                          ),
                        );
                      },
                    ),
                    if (_isAdmin)
                      _buildMenuOption(
                        icon: Icons.admin_panel_settings,
                        title: 'Tableau de bord Admin',
                        onTap: () => Navigator.pushNamed(context, '/admin/dashboard'),
                      ),
                    const SizedBox(height: 20),
                    _buildMenuOption(
                      icon: Icons.logout,
                      title: 'Déconnexion',
                      onTap: _deconnexion,
                      isDestructive: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? Colors.red : AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}