import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/delete_account_service.dart'; // ← NOUVEAU
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
  final DeleteAccountService _deleteService = DeleteAccountService(); // ← NOUVEAU
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
    if (result == true) await _loadProfile();
  }

  Future<void> _changerMotDePasse() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangerMotDePasseScreen()),
    );
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
      if (mounted) Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }

  // ✅ NOUVEAU — Suppression de compte
  Future<void> _supprimerCompte() async {
    // Dialog étape 1 — Avertissement
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Supprimer le compte', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Cette action est irréversible.\n\n'
          'Toutes vos données seront supprimées définitivement :\n'
          '• Vos transactions\n'
          '• Vos catégories\n'
          '• Votre profil\n'
          '• Votre photo\n\n'
          'Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Dialog étape 2 — Confirmation finale avec le mot "SUPPRIMER"
    final TextEditingController confirmController = TextEditingController();
    final doubleConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation finale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tapez SUPPRIMER pour confirmer :'),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                hintText: 'SUPPRIMER',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (confirmController.text.trim() == 'SUPPRIMER') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tapez exactement : SUPPRIMER'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    confirmController.dispose();
    if (doubleConfirm != true) return;

    // Suppression en cours
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(width: 20),
            Text('Suppression en cours...'),
          ],
        ),
      ),
    );

    try {
      await _deleteService.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop(); // ferme le dialog loading
        Navigator.of(context).pushReplacementNamed('/welcome');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Compte supprimé avec succès'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // ferme le dialog loading
        // Si Firebase demande une ré-authentification récente
        if (e.toString().contains('requires-recent-login')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pour supprimer votre compte, veuillez vous reconnecter d\'abord.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          await _authService.signOut();
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur : ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
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
              ElevatedButton(onPressed: _loadProfile, child: const Text('Réessayer')),
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
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Column(
                  children: [
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
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(_getInitial(),
                                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(_getInitial(),
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _currentUser!.nomComplet,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _currentUser!.email,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentUser!.typeActivite ?? 'Commerçant',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Informations
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _buildInfoCard('📱 Téléphone', _currentUser!.telephone),
                    _buildInfoCard('📍 Adresse', _currentUser!.adresse ?? 'Non renseignée'),
                    _buildInfoCard('🏪 Activité', _currentUser!.typeActivite ?? 'Non renseignée'),
                    _buildInfoCard('💰 Solde actuel', '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA'),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Paramètres
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _buildMenuOption(icon: Icons.edit, title: 'Modifier le profil', onTap: _modifierProfil),
                    _buildMenuOption(icon: Icons.lock, title: 'Changer le mot de passe', onTap: _changerMotDePasse),
                    _buildMenuOption(icon: Icons.pin, title: 'Changer le code PIN', onTap: _changerPin),
                    _buildMenuOption(icon: Icons.category, title: 'Gérer les catégories', onTap: _gestionCategories),
                    _buildMenuOption(icon: Icons.flag, title: 'Budget mensuel', onTap: _budgetMensuel),
                    _buildMenuOption(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    ),
                    _buildMenuOption(
                      icon: Icons.security,
                      title: 'Confidentialité',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfidentialiteScreen())),
                    ),
                    _buildMenuOption(
                      icon: Icons.palette,
                      title: 'Thème',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeScreen())),
                    ),
                    _buildMenuOption(
                      icon: Icons.help,
                      title: 'Aide & Support',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AideScreen())),
                    ),
                    _buildMenuOption(
                      icon: Icons.info,
                      title: 'À propos',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AProposScreen())),
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

                    const SizedBox(height: 10),

                    // ✅ NOUVEAU — Bouton suppression compte
                    _buildMenuOption(
                      icon: Icons.delete_forever,
                      title: 'Supprimer mon compte',
                      onTap: _supprimerCompte,
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 5),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
                  child: Icon(icon, color: isDestructive ? Colors.red : AppColors.primaryGreen, size: 20),
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
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}