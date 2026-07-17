import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/local_auth_service.dart';
import '../../services/permission_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final LocalAuthService _localAuth = LocalAuthService();
  final PermissionService _permissionService = PermissionService();

  String _pin = '';
  String _pinConfirm = '';
  bool _etapeConfirmation = false;
  bool _isLoading = false;
  String? _erreur;

  void _appuyerChiffre(String chiffre) {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    
    setState(() {
      _erreur = null;
      if (!_etapeConfirmation) {
        if (_pin.length < 4) _pin += chiffre;
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _etapeConfirmation = true);
          });
        }
      } else {
        if (_pinConfirm.length < 4) _pinConfirm += chiffre;
        if (_pinConfirm.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _valider();
          });
        }
      }
    });
  }

  void _effacer() {
    if (_isLoading) return;
    HapticFeedback.selectionClick(); // Retour tactile plus discret pour la suppression
    setState(() {
      _erreur = null;
      if (!_etapeConfirmation) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_pinConfirm.isNotEmpty) {
          _pinConfirm = _pinConfirm.substring(0, _pinConfirm.length - 1);
        }
      }
    });
  }

  Future<void> _valider() async {
    if (!mounted) return;

    if (_pin != _pinConfirm) {
      HapticFeedback.heavyImpact();
      setState(() {
        _erreur = 'Les codes ne correspondent pas.\nRecommence.';
        _pin = '';
        _pinConfirm = '';
        _etapeConfirmation = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _localAuth.savePin(_pin);
      if (!mounted) return;

      final isAdmin = await _permissionService.isAdmin();
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        isAdmin ? '/admin/dashboard' : '/dashboard',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Une erreur est survenue. Réessaie.';
        _pin = '';
        _pinConfirm = '';
        _etapeConfirmation = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinActuel = _etapeConfirmation ? _pinConfirm : _pin;

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
                  const Text('🔐', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 16),
                  Text(
                    _etapeConfirmation ? 'Répète ton code' : 'Choisis ton code secret',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _etapeConfirmation
                        ? 'Entre le même code une deuxième fois'
                        : 'Un code à 4 chiffres — tu en auras besoin chaque jour',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Section Erreur avec animation de fondu basique
            if (_erreur != null)
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
                          _erreur!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Indicateurs PIN (Avec AnimatedContainer pour harmoniser avec l'écran de vérification)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final rempli = i < pinActuel.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: rempli ? 22 : 18,
                  height: rempli ? 22 : 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rempli ? AppColors.primaryGreen : Colors.grey.shade300,
                    border: Border.all(
                      color: rempli ? AppColors.primaryGreen : Colors.grey.shade400,
                      width: 2,
                    ),
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
                      const SizedBox(width: 80), // Espace vide
                      _buildTouche('0'),
                      _buildToucheEffacer(),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Loader persistant
            SizedBox(
              height: 40,
              child: _isLoading
                  ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),
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