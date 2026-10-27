import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../services/local_auth_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldGreen = Color(0xFF0B4F36);
const Color textDark = Color(0xFF222222);
const Color textMedium = Color(0xFF555555);
const Color errorRed = Color(0xFF9B2C2C);

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
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                        decoration: const BoxDecoration(
                          color: emeraldGreen,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                              ),
                              child: const Center(
                                child: Icon(Icons.lock_outline_rounded, size: 36, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Code de sécurité',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Entrez votre code secret à 4 chiffres',
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 16),

                      if (_erreurVisible)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: errorRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: errorRed.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: errorRed, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    restantes > 0
                                        ? 'Code incorrect. Il vous reste $restantes essai${restantes > 1 ? 's' : ''}.'
                                        : 'Trop de tentatives échouées.',
                                    style: const TextStyle(color: errorRed, fontSize: 13.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final rempli = i < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: rempli ? 22 : 18,
                            height: rempli ? 22 : 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _erreurVisible ? errorRed : (rempli ? emeraldGreen : const Color(0xFFE5E7EB)),
                              border: Border.all(
                                color: _erreurVisible ? errorRed : (rempli ? emeraldGreen : const Color(0xFFD1D5DB)),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),

                      const Spacer(),
                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          children: [
                            _buildRangee(['1', '2', '3']),
                            const SizedBox(height: 14),
                            _buildRangee(['4', '5', '6']),
                            const SizedBox(height: 14),
                            _buildRangee(['7', '8', '9']),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // ✅ MODIFIÉ : Texte clair "Code oublié ?" au lieu d'un point d'interrogation
                                GestureDetector(
                                  onTap: _isLoading ? null : () => Navigator.pushNamed(context, '/reset_pin'),
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Code\noublié ?',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: emeraldGreen,
                                          fontSize: 12,
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

                      SizedBox(
                        height: 32,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: emeraldGreen, strokeWidth: 2.5)
                            : const SizedBox.shrink(),
                      ),

                      TextButton(
                        onPressed: _isLoading ? null : _deconnecter,
                        child: const Text(
                          'Ce n\'est pas vous ? Se déconnecter',
                          style: TextStyle(color: textMedium, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
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
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text(
            chiffre,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: textDark),
          ),
        ),
      ),
    );
  }

  Widget _buildToucheEffacer() {
    return GestureDetector(
      onTap: _effacer,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, color: textDark, size: 26),
        ),
      ),
    );
  }
}