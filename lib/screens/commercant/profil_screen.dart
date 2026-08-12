import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/delete_account_service.dart';
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
import '../auth/securiser_compte_screen.dart';

class ProfilScreen extends StatefulWidget {
  // ✅ Reçoit le user déjà chargé par le dashboard — zéro appel Firestore supplémentaire
  final UtilisateurModel? preloadedUser;
  const ProfilScreen({super.key, this.preloadedUser});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  final DeleteAccountService _deleteService = DeleteAccountService();
  UtilisateurModel? _currentUser;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();

    // ✅ Si le dashboard a déjà chargé l'utilisateur, on l'utilise directement
    if (widget.preloadedUser != null) {
      _currentUser = widget.preloadedUser;
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _permissionService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUserData(
        forceRefresh: forceRefresh,
      );
      setState(() => _currentUser = user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
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
    // ✅ Après modification, force le rechargement depuis Firestore
    if (result == true) await _loadProfile(forceRefresh: true);
  }

  Future<void> _securiserCompte() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecuriserCompteScreen(),
      ),
    );
    // Recharger les données pour vérifier le statut de sécurité mis à jour
    await _loadProfile(forceRefresh: true);
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
        content: Text('🔧 Bientôt disponible', style: TextStyle(fontSize: 16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚪', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Vous déconnecter ?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Vos données restent enregistrées.\nVous pouvez revenir à tout moment.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Oui, me déconnecter',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _supprimerCompte() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Supprimer le compte ?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tout sera supprimé définitivement :',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                  const SizedBox(height: 8),
                  _buildDeleteItem('💸 Toutes vos transactions'),
                  _buildDeleteItem('🏷️ Vos catégories'),
                  _buildDeleteItem('👤 Votre profil'),
                  _buildDeleteItem('🖼️ Votre photo'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Continuer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final TextEditingController confirmController = TextEditingController();
    final doubleConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✍️ Confirmation finale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Tapez le mot SUPPRIMER pour confirmer :',
                style: TextStyle(fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'SUPPRIMER',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (confirmController.text.trim() == 'SUPPRIMER') {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tapez exactement : SUPPRIMER',
                            style: TextStyle(fontSize: 16)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Supprimer définitivement',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );

    confirmController.dispose();
    if (doubleConfirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircularProgressIndicator(color: AppColors.primaryGreen),
              SizedBox(width: 20),
              Text('Suppression en cours...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );

    try {
      await _deleteService.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacementNamed('/welcome');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Compte supprimé avec succès',
                style: TextStyle(fontSize: 16)),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        if (e.toString().contains('requires-recent-login')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Reconnectez-vous d\'abord pour supprimer votre compte.',
                  style: TextStyle(fontSize: 16)),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          await _authService.signOut();
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur : ${e.toString()}',
                  style: const TextStyle(fontSize: 16)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatAmount(double amount) =>
      NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');

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
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❌', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                'Impossible de charger\nvotre profil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loadProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                  child: const Text('Réessayer',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool estSecurise = _currentUser!.googleLie == true || 
        (_currentUser!.emailSecours != null && _currentUser!.emailSecours!.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header gradient ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Column(
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: _currentUser!.photo != null && _currentUser!.photo!.isNotEmpty
                            ? Image.network(
                                _currentUser!.photo!,
                                width: 100, height: 100, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(_getInitial(),
                                      style: const TextStyle(fontSize: 42,
                                          fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              )
                            : Center(
                                child: Text(_getInitial(),
                                    style: const TextStyle(fontSize: 42,
                                        fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(_currentUser!.nomComplet,
                        style: const TextStyle(color: Colors.white, fontSize: 24,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text('📱 ${_currentUser!.telephone}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        '🏪 ${_currentUser!.typeActivite ?? 'Commerçante'}',
                        style: const TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Solde ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 6))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💰 Solde actuel',
                          style: TextStyle(color: Colors.white70, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA',
                        style: const TextStyle(color: Colors.white, fontSize: 32,
                            fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Banner Avertissement Si non sécurisé ─────────────────────────
              if (!estSecurise) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Text('🛡️', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Compte non sécurisé',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lie Google ou un email pour pouvoir récupérer ton compte.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _securiserCompte,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Sécuriser',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Informations ─────────────────────────────────────────────────
              _buildSection('Mes informations', [
                _buildInfoCard('📧', 'Email', _currentUser!.email),
                _buildInfoCard('📍', 'Adresse', _currentUser!.adresse ?? 'Non renseignée'),
                _buildInfoCard('🏪', 'Activité', _currentUser!.typeActivite ?? 'Non renseignée'),
              ]),

              const SizedBox(height: 24),

              // ── Mon compte ───────────────────────────────────────────────────
              _buildSection('Mon compte', [
                _buildMenuItem(emoji: '✏️', title: 'Modifier mon profil', onTap: _modifierProfil),
                _buildMenuItem(
                  emoji: '🛡️',
                  title: 'Sécuriser mon compte',
                  badge: estSecurise ? 'Sécurisé ✅' : 'À faire ⚠️',
                  badgeColor: estSecurise ? AppColors.primaryGreen : Colors.orange,
                  onTap: _securiserCompte,
                ),
                _buildMenuItem(emoji: '🔐', title: 'Changer le mot de passe', onTap: _changerMotDePasse),
                _buildMenuItem(emoji: '🔢', title: 'Changer le code PIN', onTap: _changerPin),
              ]),

              const SizedBox(height: 24),

              // ── Gestion financière ───────────────────────────────────────────
              _buildSection('Gestion financière', [
                _buildMenuItem(emoji: '🏷️', title: 'Mes catégories', onTap: _gestionCategories),
                _buildMenuItem(emoji: '🎯', title: 'Budget mensuel', onTap: _budgetMensuel),
              ]),

              const SizedBox(height: 24),

              // ── Paramètres ───────────────────────────────────────────────────
              _buildSection('Paramètres', [
                _buildMenuItem(
                  emoji: '🔔', title: 'Notifications',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
                _buildMenuItem(
                  emoji: '🔒', title: 'Confidentialité',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ConfidentialiteScreen())),
                ),
                _buildMenuItem(
                  emoji: '🎨', title: 'Thème',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ThemeScreen())),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Aide ─────────────────────────────────────────────────────────
              _buildSection('Aide', [
                _buildMenuItem(
                  emoji: '❓', title: 'Aide & Support',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AideScreen())),
                ),
                _buildMenuItem(
                  emoji: 'ℹ️', title: 'À propos de MaFortune',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AProposScreen())),
                ),
              ]),

              // ── Admin ────────────────────────────────────────────────────────
              if (_isAdmin) ...[
                const SizedBox(height: 24),
                _buildSection('Administration', [
                  _buildMenuItem(
                    emoji: '🛡️', title: 'Tableau de bord Admin',
                    onTap: () => Navigator.pushNamed(context, '/admin/dashboard'),
                  ),
                ]),
              ],

              const SizedBox(height: 28),

              // ── Actions ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity, height: 60,
                      child: OutlinedButton(
                        onPressed: _deconnexion,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🚪', style: TextStyle(fontSize: 22)),
                            SizedBox(width: 10),
                            Text('Me déconnecter',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _supprimerCompte,
                      child: Text(
                        'Supprimer mon compte',
                        style: TextStyle(
                          color: Colors.grey[500], fontSize: 14,
                          decoration: TextDecoration.underline,
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
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoCard(String emoji, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String emoji,
    required String title,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? AppColors.primaryGreen).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeColor ?? AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
    );
  }
}