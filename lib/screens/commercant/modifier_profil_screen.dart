import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../models/utilisateur_model.dart';

class ModifierProfilScreen extends StatefulWidget {
  final UtilisateurModel currentUser;

  const ModifierProfilScreen({super.key, required this.currentUser});

  @override
  State<ModifierProfilScreen> createState() => _ModifierProfilScreenState();
}

class _ModifierProfilScreenState extends State<ModifierProfilScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;
  late TextEditingController _typeActiviteController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.currentUser.nom);
    _prenomController = TextEditingController(text: widget.currentUser.prenom);
    _telephoneController = TextEditingController(text: widget.currentUser.telephone);
    _adresseController = TextEditingController(text: widget.currentUser.adresse ?? '');
    _typeActiviteController = TextEditingController(text: widget.currentUser.typeActivite ?? '');
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _typeActiviteController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedUser = widget.currentUser.copyWith(
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
        typeActivite: _typeActiviteController.text.trim().isEmpty ? null : _typeActiviteController.text.trim(),
      );

      await _authService.updateUserProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profil mis à jour avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildTextField(
              controller: _nomController,
              label: 'Nom',
              icon: Icons.person_outline,
              validator: (value) => value == null || value.isEmpty ? 'Nom requis' : null,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _prenomController,
              label: 'Prénom',
              icon: Icons.person,
              validator: (value) => value == null || value.isEmpty ? 'Prénom requis' : null,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _telephoneController,
              label: 'Téléphone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) => value == null || value.isEmpty ? 'Téléphone requis' : null,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _adresseController,
              label: 'Adresse',
              icon: Icons.location_on,
              required: false,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _typeActiviteController,
              label: 'Type d\'activité',
              icon: Icons.work_outline,
              required: false,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _enregistrer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator ??
          (required
              ? (value) => value == null || value.isEmpty ? '$label requis' : null
              : null),
    );
  }
}