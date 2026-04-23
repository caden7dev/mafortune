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
      _showError('Aucun compte connecté. Veuillez vous reconnecter.');
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
      // ✅ AJOUTÉ
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
          _showError('Trop de tentatives. Réessayez dans quelques minutes.');
          break;
        default:
          _showError('Erreur : ${e.message}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // ✅ AJOUTÉ
      FirebaseCrashlytics.instance.recordError(
        e, StackTrace.current,
        reason: 'Erreur reset PIN',
        fatal: false,
      );
      _showError('Une erreur est survenue. Vérifiez votre connexion.');
    }
  }

  Future<void> _goToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'PIN oublié',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: _emailSent ? _buildSuccessView() : _buildRequestView(),
        ),
      ),
    );
  }

  Widget _buildRequestView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset, size: 50, color: Colors.orange),
        ),
        const SizedBox(height: 30),
        const Text(
          'Réinitialiser votre PIN',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Text(
          'Nous allons envoyer un lien de réinitialisation à votre adresse email.',
          style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        if (_userEmail.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: AppColors.primaryGreen, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email du compte', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text(
                        _maskEmail(_userEmail),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Envoyer le lien de réinitialisation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Retour', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, size: 55, color: AppColors.primaryGreen),
        ),
        const SizedBox(height: 30),
        const Text(
          'Email envoyé !',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Text(
          'Un lien de réinitialisation a été envoyé à\n${_maskEmail(_userEmail)}',
          style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        _buildStep('1', 'Ouvrez votre boîte email'),
        _buildStep('2', 'Cliquez sur le lien reçu de Firebase'),
        _buildStep('3', 'Créez un nouveau mot de passe'),
        _buildStep('4', 'Revenez ici et connectez-vous'),
        _buildStep('5', 'Créez un nouveau code PIN'),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _goToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: const Text(
              'Aller à la connexion',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Vérifiez aussi vos spams si vous ne trouvez pas l\'email.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '***@$domain';
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87))),
        ],
      ),
    );
  }
}