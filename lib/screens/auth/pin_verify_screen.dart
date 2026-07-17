import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../core/constants/app_colors.dart';
import '../../services/local_auth_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';

class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  final LocalAuthService _localAuth = LocalAuthService();
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();

  String _pin = '';
  bool _isLoading = false;
  int _tentatives = 0;
  final int _maxTentatives = 3;
  bool _erreurVisible = false;

  void _appuyerChiffre(String chiffre) {
    if (_pin.length >= 4 || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _erreurVisible = false;
      _pin += chiffre;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _verifier();
      });
    }
  }

  void _effacer() {
    if (_pin.isEmpty || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifier() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final valide = await _localAuth.verifyPin(_pin);
      if (!mounted) return;

      if (valide) {
        await _localAuth.updateLastActivity();
        if (!mounted) return;

        final isAdmin = await _permissionService.isAdmin();
        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          isAdmin ? '/admin/dashboard' : '/dashboard',
        );
      } else {
        _tentatives++;
        HapticFeedback.heavyImpact();

        if (_tentatives >= _maxTentatives) {
          await _authService.signOut();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/welcome');
        } else {
          setState(() {
            _pin = '';
            _erreurVisible = true;
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Erreur vérification PIN',
        fatal: false,
      );
      if (!mounted) return;
      setState(() {
        _pin = '';
        _erreurVisible = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _deconnecter() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome');
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restantes = _maxTentatives - _tentatives;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const Text('👆', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 16),
                  const Text(
                    'Entre ton code secret',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ton code à 4 chiffres',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Erreur
            if (_erreurVisible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('❌', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          restantes > 0
                              ? 'Code incorrect. Il te reste $restantes essai${restantes > 1 ? 's' : ''}.'
                              : 'Trop d\'erreurs.',
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Indicateurs avec AnimatedContainer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final rempli = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: rempli ? 24 : 20,
                  height: rempli ? 24 : 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _erreurVisible
                        ? Colors.red.shade300
                        : rempli
                            ? AppColors.primaryGreen
                            : Colors.grey.shade300,
                  ),
                );
              }),
            ),

            const Spacer(),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRangee(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildRangee(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildRangee(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // PIN oublié
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.pushNamed(context, '/reset_pin'),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '?',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildTouche('0'),
                      _buildToucheEffacer(),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Zone Loader
            SizedBox(
              height: 40,
              child: _isLoading
                  ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Déconnexion
            TextButton(
              onPressed: _isLoading ? null : _deconnecter,
              child: const Text(
                'Ce n\'est pas moi →',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRangee(List<String> chiffres) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: chiffres.map(_buildTouche).toList(),
    );
  }

  Widget _buildTouche(String chiffre) {
    return GestureDetector(
      onTap: () => _appuyerChiffre(chiffre),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            chiffre,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToucheEffacer() {
    return GestureDetector(
      onTap: _effacer,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, color: Colors.red, size: 28),
        ),
      ),
    );
  }
}