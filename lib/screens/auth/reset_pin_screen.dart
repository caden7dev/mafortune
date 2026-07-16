import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../core/constants/app_colors.dart';
import '../../services/local_auth_service.dart';

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final LocalAuthService _localAuth = LocalAuthService();
  bool _isLoading = false;
  bool _emailSent = false;

  String get _userEmail =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  Future<void> _sendResetEmail() async {
    if (_userEmail.isEmpty) {
      _showError('Aucun compte connecté. Revenez et reconnectez-vous.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _userEmail);
      await _localAuth.clearPin();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      FirebaseCrashlytics.instance.recordError(
        e, StackTrace.current,
        reason: 'Erreur Firebase reset PIN : ${e.code}',
        fatal: false,
      );
      switch (e.code) {
        case 'user-not-found':
          _showError('Aucun compte trouvé pour cet email.');
          break;
        case 'too-many-requests':
          _showError('Trop de tentatives. Attendez quelques minutes.');
          break;
        default:
          _showError('Problème de connexion. Réessayez.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      FirebaseCrashlytics.instance.recordError(
        e, StackTrace.current,
        reason: 'Erreur reset PIN',
        fatal: false,
      );
      _showError('Vérifiez votre connexion internet et réessayez.');
    }
  }

  Future<void> _goToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryGreen, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '🔑 Code PIN oublié',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _emailSent ? _buildSuccessView() : _buildRequestView(),
        ),
      ),
    );
  }

  // ─── VUE 1 : Demande d'envoi ────────────────────────────────────────────────
  Widget _buildRequestView() {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Icône principale
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🔒', style: TextStyle(fontSize: 56)),
          ),
        ),

        const SizedBox(height: 28),

        // Titre
        const Text(
          'Vous avez oublié\nvotre code PIN ?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Explication simple
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡', style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nous allons envoyer un message à votre adresse email pour vous aider à créer un nouveau code.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Email masqué
        if (_userEmail.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📧 Votre email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _maskEmail(_userEmail),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 40),

        // Bouton principal — grand
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📨', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 12),
                      Text(
                        'Envoyer le lien',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // Bouton retour — secondaire
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Retour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── VUE 2 : Email envoyé avec succès ────────────────────────────────────────
  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: 20),

        // Icône succès
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('✅', style: TextStyle(fontSize: 60)),
          ),
        ),

        const SizedBox(height: 28),

        // Titre succès
        const Text(
          'Email envoyé !',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 10),

        Text(
          _maskEmail(_userEmail),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        // Étapes à suivre — style accessible
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Que faire maintenant ?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildStep('📧', '1', 'Ouvrez votre boîte email'),
              _buildStep('🔗', '2', 'Cliquez sur le lien reçu'),
              _buildStep('🔐', '3', 'Créez un nouveau mot de passe'),
              _buildStep('📲', '4', 'Revenez dans l\'application'),
              _buildStep('🔢', '5', 'Créez un nouveau code PIN'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Note spam
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vous ne trouvez pas l\'email ?\nVérifiez votre dossier SPAM.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // Bouton aller à la connexion
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _goToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔓', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Text(
                  'Aller à la connexion',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '***@$domain';
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  Widget _buildStep(String emoji, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Numéro
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}