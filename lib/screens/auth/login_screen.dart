import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../models/utilisateur_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _telephoneController = TextEditingController();

  // ✅ Contrôleurs pour la connexion admin
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _showAdminLogin = false;
  bool _showAdminPassword = false;

  // Compteur de taps sur le logo — 5 taps pour afficher le mode admin
  int _logoTapCount = 0;

  String? _localErrorMessage;

  @override
  void dispose() {
    _telephoneController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  String _genererEmail(String telephone) {
    final tel = telephone.replaceAll(RegExp(r'[^\d]'), '');
    return '$tel@mafortune.tg';
  }

  String _genererPassword(String telephone) {
    final tel = telephone.replaceAll(RegExp(r'[^\d]'), '');
    return 'MF_${tel}_Fortune2024!';
  }

  Future<void> _connecter() async {
    final telephone = _telephoneController.text.trim();

    if (telephone.length < 8) {
      setState(() => _localErrorMessage = 'Entre ton numéro de téléphone complet');
      return;
    }

    setState(() => _localErrorMessage = null);

    final email = _genererEmail(telephone);
    final password = _genererPassword(telephone);
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.login(email, password);

    if (success && mounted) {
      final hasPin = await _authService.isLocalPinSet();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          hasPin ? '/pin_verify' : '/pin_setup',
        );
      }
    } else if (mounted) {
      String msg = authProvider.errorMessage ?? 'Une erreur est survenue';
      if (msg.contains('user-not-found') ||
          msg.contains('invalid-credential') ||
          msg.contains('wrong-password')) {
        msg = 'Numéro introuvable. Vérifie ou crée un compte.';
      } else if (msg.contains('network')) {
        msg = 'Pas de connexion Internet';
      }
      setState(() => _localErrorMessage = msg);
    }
  }

  // ✅ Connexion admin — bypass PIN, vérification typeUtilisateur
  Future<void> _connecterAdmin() async {
    final email = _adminEmailController.text.trim();
    final password = _adminPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _localErrorMessage = 'Email et mot de passe requis');
      return;
    }

    setState(() => _localErrorMessage = null);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(email, password);

    if (success && mounted) {
      // ✅ Force le rechargement depuis Firestore pour avoir typeUtilisateur à jour
      await authProvider.refreshCurrentUser(forceRefresh: true);
      
      if (!mounted) return;
      
      final userModel = authProvider.userModel;
      final typeStr = userModel?.typeUtilisateur.toString() ?? '';
      
      // Vérifie si admin (supporte les deux formats)
      final isAdmin = typeStr.contains('administrateur') || 
                      userModel?.typeUtilisateur == TypeUtilisateur.administrateur;
      
      if (isAdmin) {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else {
        await authProvider.logout();
        setState(() =>
            _localErrorMessage = "Accès refusé. Compte non administrateur.");
      }
    } else if (mounted) {
      String msg = authProvider.errorMessage ?? 'Connexion admin échouée';
      setState(() => _localErrorMessage = msg);
    }
  }

  // ✅ 5 taps sur l'emoji 👋 pour afficher le mode admin
  void _onLogoTap() {
    _logoTapCount++;
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      setState(() => _showAdminLogin = !_showAdminLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ✅ 5 taps sur l'emoji pour débloquer le mode admin
                  GestureDetector(
                    onTap: _onLogoTap,
                    child: const Text('👋', style: TextStyle(fontSize: 52)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Content de te revoir !',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showAdminLogin
                        ? 'Mode administrateur'
                        : 'Entre ton numéro pour te connecter',
                    style: TextStyle(
                      color: _showAdminLogin
                          ? Colors.amber
                          : Colors.white70,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Message d'erreur
                    if (_localErrorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _localErrorMessage!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── MODE ADMIN ───────────────────────────────────────────
                    if (_showAdminLogin) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text('🛡️', style: TextStyle(fontSize: 22)),
                                SizedBox(width: 8),
                                Text(
                                  'Connexion Administrateur',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Email admin
                            TextField(
                              controller: _adminEmailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: '📧 Email admin',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.primaryGreen, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Mot de passe admin
                            TextField(
                              controller: _adminPasswordController,
                              obscureText: !_showAdminPassword,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: '🔐 Mot de passe',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.primaryGreen, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: IconButton(
                                  icon: Icon(_showAdminPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(() =>
                                      _showAdminPassword = !_showAdminPassword),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _connecterAdmin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        '🛡️ Connexion Admin',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Masquer le mode admin
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() {
                                  _showAdminLogin = false;
                                  _logoTapCount = 0;
                                }),
                                child: Text(
                                  'Retour connexion normale',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]

                    // ── MODE COMMERÇANT (normal) ──────────────────────────────
                    else ...[
                      const Text(
                        '📱   Ton numéro de téléphone',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _telephoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ]')),
                        ],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '+228 90 00 00 00',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 20,
                            fontWeight: FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.primaryGreen, width: 2.5),
                          ),
                        ),
                        onSubmitted: (_) => _connecter(),
                      ),

                      const SizedBox(height: 10),
                      const Text(
                        "🔒 C'est le numéro que tu as utilisé à l'inscription",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 40),

                      // Bouton connexion
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _connecter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '🔑   Me connecter',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OU',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Center(
                        child: Column(
                          children: [
                            const Text(
                              "Tu n'as pas encore de compte ?",
                              style:
                                  TextStyle(color: Colors.black54, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pushReplacementNamed(
                                    context, '/signup'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  side: const BorderSide(
                                      color: AppColors.primaryGreen, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Créer mon compte',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}