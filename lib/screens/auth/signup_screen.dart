import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Import indispensable pour utiliser AuthProvider
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart'; // Import de ton nouveau provider
import '../../widgets/screenshot_wrapper.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();

  String? _selectedActivity;
  String? _localErrorMessage;
  int _etape = 1; // 1 = nom, 2 = téléphone, 3 = activité

  // Activités avec emoji — reconnaissables sans lire
  final List<Map<String, String>> _activites = [
    {'emoji': '🛒', 'label': 'Vente de produits'},
    {'emoji': '🍲', 'label': 'Restauration'},
    {'emoji': '✂️', 'label': 'Coiffure'},
    {'emoji': '🧵', 'label': 'Couture'},
    {'emoji': '🔧', 'label': 'Artisan'},
    {'emoji': '📦', 'label': 'Commerce divers'},
  ];

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  // Génère un email automatiquement à partir du téléphone
  String _genererEmail(String telephone) {
    final tel = telephone.replaceAll(RegExp(r'[^\d]'), '');
    return '$tel@mafortune.tg';
  }

  // Génère un mot de passe fort automatiquement
  String _genererPassword(String telephone) {
    final tel = telephone.replaceAll(RegExp(r'[^\d]'), '');
    return 'MF_${tel}_Fortune2024!';
  }

  Future<void> _creerCompte() async {
    if (_prenomController.text.trim().isEmpty) {
      setState(() => _localErrorMessage = 'Entre ton prénom');
      return;
    }
    if (_telephoneController.text.trim().length < 8) {
      setState(() => _localErrorMessage = 'Numéro de téléphone invalide');
      return;
    }
    if (_selectedActivity == null) {
      setState(() => _localErrorMessage = 'Choisis ton activité');
      return;
    }

    setState(() {
      _localErrorMessage = null;
    });

    final telephone = _telephoneController.text.trim();
    final email = _genererEmail(telephone);
    final password = _genererPassword(telephone);
    final authProvider = context.read<AuthProvider>();

    // Appel à l'action d'inscription via notre AuthProvider
    final success = await authProvider.registerCommercant(
      email: email,
      password: password,
      nom: _nomController.text.trim().isEmpty
          ? _prenomController.text.trim()
          : _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      telephone: telephone,
      typeActivite: _selectedActivity!,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/pin_setup');
    } else if (mounted) {
      String msg = authProvider.errorMessage ?? 'Une erreur est survenue';
      if (msg.contains('email-already-in-use')) {
        msg = 'Ce numéro est déjà utilisé. Connecte-toi.';
      } else if (msg.contains('network')) {
        msg = 'Pas de connexion Internet';
      }
      setState(() {
        _localErrorMessage = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute de l'état de chargement global de notre AuthProvider
    final isLoading = context.watch<AuthProvider>().isLoading;

    return ScreenshotWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header vert
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Créer mon compte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "C'est rapide et gratuit",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Indicateur d'étapes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [1, 2, 3].map((i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: _etape == i ? 32 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _etape == i ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message d'erreur
                      if (_localErrorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _localErrorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ÉTAPE 1 — Nom et prénom
                      _buildSectionTitle('👤', 'Comment tu t\'appelles ?'),
                      const SizedBox(height: 16),
                      _buildChamp(
                        controller: _prenomController,
                        label: 'Ton prénom *',
                        hint: 'Ex: Ama',
                        onChanged: (_) => setState(() => _etape = 1),
                      ),
                      const SizedBox(height: 14),
                      _buildChamp(
                        controller: _nomController,
                        label: 'Ton nom (optionnel)',
                        hint: 'Ex: Koffi',
                      ),
                      const SizedBox(height: 28),

                      // ÉTAPE 2 — Téléphone
                      _buildSectionTitle('📱', 'Ton numéro de téléphone'),
                      const SizedBox(height: 16),
                      _buildChamp(
                        controller: _telephoneController,
                        label: 'Numéro *',
                        hint: '+228 90 00 00 00',
                        clavier: TextInputType.phone,
                        onChanged: (_) => setState(() => _etape = 2),
                        formatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '🔒 Ton numéro sert à te connecter — personne ne le verra',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 28),

                      // ÉTAPE 3 — Activité
                      _buildSectionTitle('🏪', 'Qu\'est-ce que tu fais comme travail ?'),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: _activites.map((activite) {
                          final isSelected = _selectedActivity == activite['label'];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedActivity = activite['label'];
                                _etape = 3;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryGreen : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    activite['emoji']!,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    activite['label']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 36),

                      // Bouton créer
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _creerCompte,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '✅   Créer mon compte',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text(
                            "J'ai déjà un compte →",
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String emoji, String titre) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titre,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChamp({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType clavier = TextInputType.text,
    List<TextInputFormatter>? formatters,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: clavier,
          inputFormatters: formatters,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}