import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

class ChangerMotDePasseScreen extends StatefulWidget {
  const ChangerMotDePasseScreen({super.key});

  @override
  State<ChangerMotDePasseScreen> createState() =>
      _ChangerMotDePasseScreenState();
}

class _ChangerMotDePasseScreenState extends State<ChangerMotDePasseScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changerMotDePasse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Mot de passe changé avec succès',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '🔐 Changer le mot de passe',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
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
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🔑', style: TextStyle(fontSize: 50)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Créez un nouveau\nmot de passe',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Minimum 6 caractères.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // ── Champ 1 — Mot de passe actuel ────────────────────────────────
            _buildSectionLabel('🔒', 'Mot de passe actuel'),
            const SizedBox(height: 10),
            _buildPasswordField(
              controller: _currentPasswordController,
              hint: 'Entrez votre mot de passe actuel',
              showPassword: _showCurrent,
              onToggle: () =>
                  setState(() => _showCurrent = !_showCurrent),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
            ),

            const SizedBox(height: 24),

            // ── Champ 2 — Nouveau mot de passe ───────────────────────────────
            _buildSectionLabel('🆕', 'Nouveau mot de passe'),
            const SizedBox(height: 10),
            _buildPasswordField(
              controller: _newPasswordController,
              hint: 'Entrez votre nouveau mot de passe',
              showPassword: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nouveau mot de passe requis';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // ── Champ 3 — Confirmer ───────────────────────────────────────────
            _buildSectionLabel('✅', 'Confirmer le nouveau mot de passe'),
            const SizedBox(height: 10),
            _buildPasswordField(
              controller: _confirmPasswordController,
              hint: 'Répétez le nouveau mot de passe',
              showPassword: _showConfirm,
              onToggle: () =>
                  setState(() => _showConfirm = !_showConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmation requise';
                if (v != _newPasswordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Conseil sécurité ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Utilisez au moins 6 caractères. Mélangez lettres et chiffres pour plus de sécurité.',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── Bouton Enregistrer ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changerMotDePasse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primaryGreen.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('💾', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text(
                            'Enregistrer',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Bouton Annuler ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed:
                    _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LABEL SECTION ───────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String emoji, String label) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
      ],
    );
  }

  // ─── CHAMP MOT DE PASSE ──────────────────────────────────────────────────────
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      enabled: !_isLoading,
      style: const TextStyle(fontSize: 17, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        // Bouton afficher/masquer — grand
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Text(
              showPassword ? '🙈' : '👁️',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
      validator: validator,
    );
  }
}