import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Import indispensable pour utiliser AuthProvider
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart'; // Import de ton nouveau provider
import '../../services/auth_service.dart';
import '../../widgets/screenshot_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // On conserve temporairement l'instance pour isLocalPinSet() s'il n'est pas exposé dans ton AuthProvider
  final AuthService _authService = AuthService();
  final _telephoneController = TextEditingController();

  String? _localErrorMessage;

  @override
  void dispose() {
    _telephoneController.dispose();
    super.dispose();
  }

  // Même logique que signup — cohérence obligatoire
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

    setState(() {
      _localErrorMessage = null;
    });

    final email = _genererEmail(telephone);
    final password = _genererPassword(telephone);
    final authProvider = context.read<AuthProvider>();

    // Authentification via notre Provider global
    final success = await authProvider.login(email, password);

    if (success && mounted) {
      // Vérification sécurisée du PIN local avant de rediriger
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
      setState(() {
        _localErrorMessage = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute de l'état de chargement global de notre AuthProvider
    final isLoading = context.watch<AuthProvider>().isLoading;

    return ScreenshotWrapper(
      child: Scaffold(
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
                    const Text(
                      '👋',
                      style: TextStyle(fontSize: 52),
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
                    const Text(
                      'Entre ton numéro pour te connecter',
                      style: TextStyle(
                        color: Colors.white70,
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
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _localErrorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Label
                      const Text(
                        '📱   Ton numéro de téléphone',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Champ téléphone — grand et lisible
                      TextField(
                        controller: _telephoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2.5),
                          ),
                        ),
                        onSubmitted: (_) => _connecter(),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "🔒 C'est le numéro que tu as utilisé à l'inscription",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Bouton connexion — gros
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

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                              style: TextStyle(color: Colors.black54, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  side: const BorderSide(color: AppColors.primaryGreen, width: 2),
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}