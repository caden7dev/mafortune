import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Ajouté pour Firestore
import 'package:firebase_storage/firebase_storage.dart'; // ✅ Ajouté pour le stockage image
import 'package:image_picker/image_picker.dart'; // ✅ Ajouté pour la galerie
import 'dart:io'; // ✅ Ajouté pour manipuler le fichier image

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
import 'mes_produits_screen.dart';
import 'messages_screen.dart';
import 'mon_qr_code_screen.dart';
import 'scanner_qr_screen.dart';
import 'changer_code_pin_screen.dart';
import 'lier_email_screen.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class ProfilScreen extends StatefulWidget {
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
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    if (widget.preloadedUser != null) {
      _currentUser = widget.preloadedUser;
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  @override
  void didUpdateWidget(ProfilScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preloadedUser != null && widget.preloadedUser != oldWidget.preloadedUser) {
      setState(() {
        _currentUser = widget.preloadedUser;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _permissionService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUserData(forceRefresh: forceRefresh);
      setState(() => _currentUser = user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e', style: const TextStyle(fontSize: 16)),
          backgroundColor: brickRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDisplayedEmail() {
    final email = _currentUser?.email;
    final phone = _currentUser?.telephone;
    if (email == null || email.isEmpty || (phone != null && email.contains(phone))) {
      return 'Non lié (Optionnel)';
    }
    return email;
  }

  bool get _hasRealEmail {
    final email = _currentUser?.email;
    final phone = _currentUser?.telephone;
    return email != null && email.isNotEmpty && (phone == null || !email.contains(phone));
  }

  Future<void> _modifierProfil() async {
    if (_currentUser == null) return;
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ModifierProfilScreen(currentUser: _currentUser!)));
    if (result == true) await _loadProfile(forceRefresh: true);
  }

  Future<void> _mesProduits() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MesProduitsScreen(isOnboarding: false)));
  }

  Future<void> _changerMotDePasse() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangerMotDePasseScreen()));
  }

  Future<void> _changerPin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangerCodePinScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code PIN mis à jour avec succès'),
          backgroundColor: emeraldDark,
        ),
      );
    }
  }

  Future<void> _lierEmail() async {
    if (_currentUser == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LierEmailScreen()),
    );
    if (result == true && mounted) {
      await _loadProfile(forceRefresh: true);
    }
  }

  // ✅ NOUVELLE MÉTHODE : Changer la photo de profil
  Future<void> _changerPhotoProfil() async {
    if (_currentUser == null) return;

    // 1. Ouvrir la galerie
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Compresse l'image pour un upload plus rapide
    );

    if (image == null) return; // L'utilisateur a annulé

    // 2. Afficher un indicateur de chargement
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: emeraldDark),
            SizedBox(width: 20),
            Text('Mise à jour de la photo...', style: TextStyle(fontSize: 16, color: textDark)),
          ],
        ),
      ),
    );

    try {
      // 3. Upload vers Firebase Storage
      final String fileName = 'profile_${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('users_photos').child(fileName);
      
      final uploadTask = await ref.putFile(File(image.path));
      final String downloadUrl = await uploadTask.ref.getDownloadURL();

      // 4. Mettre à jour le champ 'photo' dans Firestore
      await FirebaseFirestore.instance.collection('utilisateurs').doc(_currentUser!.id).update({
        'photo': downloadUrl,
      });

      // 5. Fermer le chargement et rafraîchir l'interface
      if (mounted) {
        Navigator.of(context).pop(); // Ferme le dialogue
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Photo de profil mise à jour'), backgroundColor: emeraldDark),
        );
        await _loadProfile(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ferme le dialogue en cas d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour : $e'), backgroundColor: brickRed),
        );
      }
    }
  }

  Future<void> _gestionCategories() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionCategoriesScreen()));
  }

  Future<void> _budgetMensuel() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
  }

  void _showQrOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Code QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              _buildQrOption(
                icon: Icons.qr_code_rounded,
                title: 'Mon code QR',
                subtitle: 'Partagez vos coordonnées',
                color: emeraldDark,
                onTap: () {
                  Navigator.pop(context);
                  if (_currentUser != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MonQrCodeScreen(user: _currentUser!)));
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildQrOption(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scanner un code',
                subtitle: 'Scannez le code de quelqu\'un',
                color: terracotta,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerQrScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrOption({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 22),
          ],
        ),
      ),
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
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: brickRed.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.logout_rounded, size: 48, color: brickRed)),
            const SizedBox(height: 16),
            const Text('Vous déconnecter ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Vos données restent enregistrées.\nVous pouvez revenir à tout moment.', style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: brickRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Oui, me déconnecter', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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

  Future<void> _changerDeCompte() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: terracotta.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.switch_account_rounded, size: 48, color: terracotta),
            ),
            const SizedBox(height: 16),
            const Text('Changer de compte ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Vous allez être déconnecté de ce compte pour vous connecter avec un autre.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: terracotta, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Continuer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: brickRed.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, size: 48, color: brickRed)),
            const SizedBox(height: 16),
            const Text('Supprimer le compte ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: brickRed.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tout sera supprimé définitivement :', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: brickRed)),
                  const SizedBox(height: 8),
                  _buildDeleteItem(Icons.attach_money_rounded, 'Toutes vos transactions'),
                  _buildDeleteItem(Icons.label_rounded, 'Vos catégories'),
                  _buildDeleteItem(Icons.person_rounded, 'Votre profil'),
                  _buildDeleteItem(Icons.image_rounded, 'Votre photo'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: brickRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Continuer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
            const Text('✍️ Confirmation finale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 16),
            const Text('Tapez le mot SUPPRIMER pour confirmer :', style: TextStyle(fontSize: 15, color: textDark)),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              decoration: InputDecoration(
                hintText: 'SUPPRIMER',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brickRed, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (confirmController.text.trim() == 'SUPPRIMER') {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tapez exactement : SUPPRIMER', style: TextStyle(fontSize: 16)), backgroundColor: brickRed));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: brickRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Supprimer définitivement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [CircularProgressIndicator(color: emeraldDark), SizedBox(width: 20), Text('Suppression en cours...', style: TextStyle(fontSize: 16, color: textDark))]),
        ),
      ),
    );

    try {
      await _deleteService.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacementNamed('/welcome');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Compte supprimé avec succès', style: TextStyle(fontSize: 16)), backgroundColor: emeraldDark));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        if (e.toString().contains('requires-recent-login')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reconnectez-vous d\'abord pour supprimer votre compte.', style: const TextStyle(fontSize: 16)), backgroundColor: terracotta, duration: const Duration(seconds: 5)));
          await _authService.signOut();
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString()}', style: const TextStyle(fontSize: 16)), backgroundColor: brickRed));
        }
      }
    }
  }

  String _formatAmount(double amount) => NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');

  String _getInitial() {
    if (_currentUser == null) return '?';
    final name = _currentUser!.nomComplet;
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFFF8F9FA), body: Center(child: CircularProgressIndicator(color: emeraldDark)));
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Impossible de charger\nvotre profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loadProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: emeraldDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 32)),
                  child: const Text('Réessayer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadProfile(forceRefresh: true),
          color: emeraldDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  decoration: const BoxDecoration(color: emeraldDark),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipOval(
                              child: _currentUser!.photo != null && _currentUser!.photo!.isNotEmpty
                                  ? Image.network(
                                      _currentUser!.photo!,
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(_getInitial(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    )
                                  : Center(
                                      child: Text(_getInitial(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                            ),
                          ),
                          // ✅ REMPLACEMENT DE L'ICÔNE QR PAR UNE CAMÉRA
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: _changerPhotoProfil, // ✅ Appelle la nouvelle méthode
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: emeraldDark, // Fond vert pour matcher la charte
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _currentUser!.nomComplet,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0B4F36), Color(0xFF0D5F41)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: emeraldDark.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18)),
                            const SizedBox(width: 8),
                            const Text('Solde total', style: TextStyle(color: Colors.white70, fontSize: 15)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _isBalanceVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: Colors.white70,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isBalanceVisible = !_isBalanceVisible;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: _isBalanceVisible ? 'Masquer le solde' : 'Afficher le solde',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isBalanceVisible 
                                ? '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA' 
                                : '•••••• FCFA',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                _buildSection('Mes informations', [
                  _buildInfoCard(
                    icon: Icons.phone_outlined,
                    label: 'Numéro de téléphone',
                    value: _currentUser!.telephone ?? 'Non renseigné',
                  ),
                  GestureDetector(
                    onTap: !_hasRealEmail ? _lierEmail : null,
                    child: _buildInfoCard(
                      icon: Icons.email_outlined,
                      label: 'Adresse e-mail',
                      value: _getDisplayedEmail(),
                      trailing: !_hasRealEmail
                          ? const Text('Lier', style: TextStyle(color: emeraldDark, fontSize: 13, fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
                  _buildInfoCard(
                    icon: Icons.storefront_outlined,
                    label: 'Activité',
                    value: _currentUser!.typeActivite ?? 'Non renseignée',
                  ),
                ]),

                const SizedBox(height: 24),

                _buildSection('Mon compte', [
                  _buildMenuItem(icon: Icons.edit_outlined, title: 'Modifier mon profil', onTap: _modifierProfil),
                  _buildMenuItem(icon: Icons.inventory_2_outlined, title: 'Mes produits & services', onTap: _mesProduits),
                  _buildMenuItem(icon: Icons.lock_outline, title: 'Changer le mot de passe', onTap: _changerMotDePasse),
                  _buildMenuItem(icon: Icons.pin_outlined, title: 'Changer le code PIN', onTap: _changerPin),
                  _buildMenuItem(icon: Icons.switch_account_rounded, title: 'Changer de compte', onTap: _changerDeCompte),
                  _buildMenuItem(
                    icon: Icons.qr_code_rounded, 
                    title: 'Mon QR Code', 
                    subtitle: 'Partagez vos coordonnées',
                    onTap: () {
                      if (_currentUser != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => MonQrCodeScreen(user: _currentUser!)));
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.qr_code_scanner_rounded, 
                    title: 'Scanner un code', 
                    subtitle: 'Scannez le code de quelqu\'un',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerQrScreen()));
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                _buildSection('Gestion financière', [
                  _buildMenuItem(icon: Icons.label_outline, title: 'Mes catégories', onTap: _gestionCategories),
                  _buildMenuItem(icon: Icons.flag_outlined, title: 'Budget mensuel', onTap: _budgetMensuel),
                ]),

                const SizedBox(height: 24),

                _buildSection('Paramètres', [
                  _buildMenuItem(icon: Icons.notifications_none_outlined, title: 'Notifications', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                  _buildMenuItem(icon: Icons.privacy_tip_outlined, title: 'Confidentialité', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfidentialiteScreen()))),
                  _buildMenuItem(icon: Icons.palette_outlined, title: 'Thème', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeScreen()))),
                ]),

                const SizedBox(height: 24),

                _buildSection('Aide & Contact', [
                  _buildMenuItem(icon: Icons.chat_bubble_outline, title: 'Messagerie Admin', subtitle: 'Discutez directement avec le support', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()))),
                  _buildMenuItem(icon: Icons.help_outline, title: 'Aide & Support', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AideScreen()))),
                  _buildMenuItem(icon: Icons.info_outline, title: 'À propos de MaFortune', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AProposScreen()))),
                ]),

                if (_isAdmin) ...[
                  const SizedBox(height: 24),
                  _buildSection('Administration', [
                    _buildMenuItem(icon: Icons.admin_panel_settings_outlined, title: 'Tableau de bord Admin', onTap: () => Navigator.pushNamed(context, '/admin/dashboard')),
                  ]),
                ],

                const SizedBox(height: 28),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity, height: 60,
                        child: OutlinedButton(
                          onPressed: _deconnexion,
                          style: OutlinedButton.styleFrom(foregroundColor: brickRed, side: const BorderSide(color: brickRed, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout_rounded, size: 22, color: brickRed), SizedBox(width: 10), Text('Me déconnecter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brickRed))]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _supprimerCompte,
                        child: Text('Supprimer mon compte', style: TextStyle(color: Colors.grey[500], fontSize: 14, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)), const SizedBox(height: 14), ...children],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, String? subtitle, required VoidCallback onTap, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: subtitle != null ? 14 : 17),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: emeraldDark, size: 20)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark)),
                      if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600]))],
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [Icon(icon, size: 18, color: brickRed), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 14, color: textDark, height: 1.4))]),
    );
  }
}