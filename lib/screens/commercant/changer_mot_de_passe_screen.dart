import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux (Erreurs)
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

class ChangerMotDePasseScreen extends StatefulWidget {
  const ChangerMotDePasseScreen({super.key});

  @override
  State<ChangerMotDePasseScreen> createState() => _ChangerMotDePasseScreenState();
}

class _ChangerMotDePasseScreenState extends State<ChangerMotDePasseScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

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
            content: Text('✅ Mot de passe changé avec succès', style: TextStyle(fontSize: 16)),
            backgroundColor: emeraldDark, // ✅ Couleur harmonisée
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: brickRed, // ✅ Couleur harmonisée pour les erreurs
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
      backgroundColor: const Color(0xFFF8F9FA), // ✅ Fond gris très clair et doux
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
            Icon(Icons.lock_outline, size: 22, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Changer le mot de passe',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          children: [
            // ── ICÔNE PRINCIPALE ─────────────────────────────────────────────
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: emeraldDark.withOpacity(0.1), // ✅ Règle des 10%
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded, // ✅ Icône système épurée
                  size: 50,
                  color: emeraldDark,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Créez un nouveau\nmot de passe',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textDark, // ✅ Remplacement de Colors.black87
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

            // ── CHAMP 1 : MOT DE PASSE ACTUEL ────────────────────────────────
            _buildSectionLabel(Icons.lock_outline, 'Mot de passe actuel'),
            const SizedBox(height: 10),
            _buildPasswordField(
              controller: _currentPasswordController,
              hint: 'Entrez votre mot de passe actuel',
              showPassword: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
            ),

            const SizedBox(height: 24),

            // ── CHAMP 2 : NOUVEAU MOT DE PASSE ───────────────────────────────
            _buildSectionLabel(Icons.password_outlined, 'Nouveau mot de passe'),
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

            // ── CHAMP 3 : CONFIRMER ───────────────────────────────────────────
            _buildSectionLabel(Icons.check_circle_outline, 'Confirmer le nouveau mot de passe'),
            const SizedBox(height: 10),
            _buildPasswordField(
              controller: _confirmPasswordController,
              hint: 'Répétez le nouveau mot de passe',
              showPassword: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmation requise';
                if (v != _newPasswordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── CONSEIL SÉCURITÉ ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: emeraldDark.withOpacity(0.08), // ✅ Fond harmonisé
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: emeraldDark.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20, color: emeraldDark), // ✅ Icône système
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Utilisez au moins 6 caractères. Mélangez lettres et chiffres pour plus de sécurité.',
                      style: TextStyle(fontSize: 14, color: textDark, height: 1.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── BOUTON ENREGISTRER ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changerMotDePasse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: emeraldDark.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 22), // ✅ Icône système épurée
                          SizedBox(width: 10),
                          Text(
                            'Enregistrer',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // ── BOUTON ANNULER ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textDark,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LABEL SECTION ───────────────────────────────────────────────────────────
  Widget _buildSectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: emeraldDark.withOpacity(0.1), // ✅ Règle des 10%
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: emeraldDark),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark),
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
      style: const TextStyle(fontSize: 17, color: textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emeraldDark, width: 2), // ✅ Bordure harmonisée
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brickRed, width: 1.5), // ✅ Erreur en Rouge Brique
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brickRed, width: 2),
        ),
        // ✅ Bouton afficher/masquer avec icônes système propres
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey[500],
            size: 22,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}