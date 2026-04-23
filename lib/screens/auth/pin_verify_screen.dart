import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/local_auth_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../auth/reset_pin_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  final TextEditingController _pinController = TextEditingController();
  final LocalAuthService _localAuth = LocalAuthService();
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();

  bool _isLoading = false;
  int _attempts = 0;
  final int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final isAvailable = await _localAuth.isBiometricAvailable();
    if (isAvailable && mounted) {
      _showBiometricOption();
    }
  }

  void _showBiometricOption() {}

  Future<void> _verify() async {
    if (_pinController.text.length != 4) {
      _showError('Veuillez saisir un code PIN à 4 chiffres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await _localAuth.verifyPin(_pinController.text);
      
      if (isValid) {
        await _localAuth.updateLastActivity();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Accès autorisé'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 1),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            final isAdmin = await _permissionService.isAdmin();
            if (isAdmin) {
              Navigator.pushReplacementNamed(context, '/admin/dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          }
        }
      } else {
        _attempts++;
        if (_attempts >= _maxAttempts) {
          await _authService.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Trop de tentatives. Vous avez été déconnecté.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.pushReplacementNamed(context, '/welcome');
          }
        } else {
          final remaining = _maxAttempts - _attempts;
          _showError('Code PIN incorrect. Il vous reste $remaining tentative${remaining > 1 ? 's' : ''}.');
          _pinController.clear();
        }
      }
    } catch (e) {
      // ✅ AJOUTÉ
      FirebaseCrashlytics.instance.recordError(
        e, StackTrace.current,
        reason: 'Erreur vérification PIN',
        fatal: false,
      );
      _showError('Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
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
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 50,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Vérification d\'identité',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                'Entrez votre code PIN à 4 chiffres pour accéder à votre compte',
                style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 20,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onChanged: (value) {
                  if (value.length == 4) _verify();
                },
              ),
              const SizedBox(height: 20),
              if (_attempts > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Tentative ${_attempts}/$_maxAttempts',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
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
                          'Déverrouiller',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/reset_pin'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                child: const Text(
                  'PIN oublié ?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
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