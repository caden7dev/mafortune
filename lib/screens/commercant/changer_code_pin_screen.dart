import 'package:flutter/material.dart';
import '../../services/local_auth_service.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class ChangerCodePinScreen extends StatefulWidget {
  const ChangerCodePinScreen({super.key});

  @override
  State<ChangerCodePinScreen> createState() => _ChangerCodePinScreenState();
}

class _ChangerCodePinScreenState extends State<ChangerCodePinScreen> {
  final LocalAuthService _localAuthService = LocalAuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changerPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ 1. Vérifie que l'ancien PIN est correct
      final ancienPinValide = await _localAuthService.verifyPin(_currentPinController.text);

      if (!ancienPinValide) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Le code PIN actuel est incorrect', style: TextStyle(fontSize: 16)),
              backgroundColor: brickRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              margin: EdgeInsets.all(16),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // ✅ 2. Sauvegarde le nouveau PIN (haché) dans Firestore
      await _localAuthService.savePin(_newPinController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Code PIN modifié avec succès', style: TextStyle(fontSize: 16)),
            backgroundColor: emeraldDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            margin: EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : ${e.toString()}', style: const TextStyle(fontSize: 16)),
            backgroundColor: brickRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, size: 22, color: Colors.white),
            SizedBox(width: 8),
            Text('Changer le code PIN', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          children: [
            // ── Icône principale ─────────────────────────────────────────────
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: emeraldDark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security_rounded,
                  size: 50,
                  color: emeraldDark,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Sécurisez votre compte',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Le code PIN doit contenir exactement 4 chiffres.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // ── Champ 1 : Code PIN actuel ────────────────────────────────────
            _buildPinField(
              controller: _currentPinController,
              icon: Icons.lock_outline,
              label: 'Code PIN actuel',
              obscureText: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Veuillez entrer votre code PIN actuel';
                if (v.length != 4) return 'Le code PIN doit contenir 4 chiffres';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Champ 2 : Nouveau Code PIN ───────────────────────────────────
            _buildPinField(
              controller: _newPinController,
              icon: Icons.key_rounded,
              label: 'Nouveau code PIN',
              obscureText: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Veuillez entrer un nouveau code PIN';
                if (v.length != 4) return 'Le code PIN doit contenir 4 chiffres';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Champ 3 : Confirmer le Code PIN ──────────────────────────────
            _buildPinField(
              controller: _confirmPinController,
              icon: Icons.check_circle_outline,
              label: 'Confirmer le nouveau code PIN',
              obscureText: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Veuillez confirmer le code PIN';
                if (v != _newPinController.text) return 'Les codes PIN ne correspondent pas';
                return null;
              },
            ),

            const SizedBox(height: 36),

            // ── Bouton Enregistrer ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changerPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: emeraldDark.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 22),
                          SizedBox(width: 10),
                          Text('Enregistrer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget personnalisé pour les champs PIN ──────────────────────────────
  Widget _buildPinField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: obscureText,
      enabled: !_isLoading,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark, letterSpacing: 4),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        counterText: "",
        labelText: label,
        labelStyle: TextStyle(fontSize: 15, color: Colors.grey[600]),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: emeraldDark.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: emeraldDark, size: 18),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey[500],
            size: 22,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emeraldDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brickRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brickRed, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}