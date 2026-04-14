import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../models/utilisateur_model.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  String? _selectedActivity;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  String? _errorMessage;

  final List<String> _activities = [
    'Vendeur de produits',
    'Restaurateur',
    'Artisan',
    'Coiffeur/Coiffeuse',
    'Couturier/Couturière',
    'Autre',
  ];

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      setState(() => _errorMessage = 'Vous devez accepter les conditions d\'utilisation');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signUpCommercant(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        typeActivite: _selectedActivity!,
      );

      if (user != null && mounted) {
        // Inscription réussie : redirection vers la création du PIN
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Compte créé ! Définissez votre code PIN'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/pin_setup');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String errorMsg = e.toString();
          if (errorMsg.contains('email-already-in-use')) {
            _errorMessage = 'Cet email est déjà utilisé';
          } else if (errorMsg.contains('weak-password')) {
            _errorMessage = 'Mot de passe trop faible (min 8 caractères)';
          } else if (errorMsg.contains('invalid-email')) {
            _errorMessage = 'Email invalide';
          } else if (errorMsg.contains('network')) {
            _errorMessage = 'Problème de connexion Internet';
          } else {
            _errorMessage = errorMsg;
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: Text('💰', style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(height: 15),
                Text(AppStrings.signupTitle, style: AppTextStyles.h2),
                const SizedBox(height: 6),
                Text(AppStrings.signupSubtitle, style: AppTextStyles.subtitle),
                const SizedBox(height: 25),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_errorMessage!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${AppStrings.signupLastName} *', style: AppTextStyles.labelMedium),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nomController,
                            decoration: _inputDecoration('Kouassi'),
                            validator: (v) => v == null || v.isEmpty ? AppStrings.validationRequired : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${AppStrings.signupFirstName} *', style: AppTextStyles.labelMedium),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _prenomController,
                            decoration: _inputDecoration('Jean'),
                            validator: (v) => v == null || v.isEmpty ? AppStrings.validationRequired : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text('${AppStrings.signupEmail} *', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('exemple@email.com'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.validationRequired;
                    if (!v.contains('@')) return AppStrings.validationEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Text('${AppStrings.signupPhone} *', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('+228 90 12 34 56'),
                  validator: (v) => v == null || v.isEmpty ? AppStrings.validationRequired : null,
                ),
                const SizedBox(height: 16),

                Text('${AppStrings.signupActivity} *', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedActivity,
                  decoration: _inputDecoration('Sélectionnez votre activité'),
                  items: _activities.map((activity) => DropdownMenuItem(value: activity, child: Text(activity))).toList(),
                  onChanged: (value) => setState(() => _selectedActivity = value),
                  validator: (v) => v == null ? AppStrings.validationRequired : null,
                ),
                const SizedBox(height: 16),

                Text('${AppStrings.signupPassword} *', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration('••••••••').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.validationRequired;
                    if (v.length < 8) return AppStrings.validationPasswordShort;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Text('${AppStrings.signupConfirmPassword} *', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _inputDecoration('••••••••').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.validationRequired;
                    if (v != _passwordController.text) return AppStrings.validationPasswordMismatch;
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                      activeColor: AppColors.primaryGreen,
                    ),
                    Expanded(child: Text(AppStrings.signupTerms, style: AppTextStyles.caption)),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: AppColors.borderMedium,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Text(AppStrings.signupButton, style: AppTextStyles.button),
                  ),
                ),
                const SizedBox(height: 15),

                Center(
                  child: Column(
                    children: [
                      Text(AppStrings.signupHaveAccount, style: AppTextStyles.bodyMedium),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.signupLogin, style: AppTextStyles.link),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.hint,
      filled: true,
      fillColor: AppColors.backgroundLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 2)),
      contentPadding: const EdgeInsets.all(14),
    );
  }
}