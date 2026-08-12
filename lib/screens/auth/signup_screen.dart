import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
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

  final _prenomFocus = FocusNode();
  final _telephoneFocus = FocusNode();

  final _prenomKey = GlobalKey();
  final _telephoneKey = GlobalKey();
  final _activiteKey = GlobalKey();

  String? _selectedActivity;

  // Messages d'erreur ciblés par champ
  String? _prenomError;
  String? _telephoneError;
  String? _activiteError;
  String? _globalError;

  int _etape = 1;

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
    _prenomFocus.dispose();
    _telephoneFocus.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final contextKey = key.currentContext;
    if (contextKey != null) {
      Scrollable.ensureVisible(
        contextKey,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _reinitialiserErreurs() {
    setState(() {
      _prenomError = null;
      _telephoneError = null;
      _activiteError = null;
      _globalError = null;
    });
  }

  String _genererEmail(String telephone) {
    final tel = telephone.replaceAll(RegExp(r'[^\d]'), '');
    return '$tel@mafortune.tg';
  }

  String _genererPassword(String telephone) {
    final tel = telephone.replaceAll(RegExp(r'[^\d]'), '');
    return 'MF_${tel}_Fortune2024!';
  }

  Future<void> _creerCompte() async {
    _reinitialiserErreurs();

    final prenom = _prenomController.text.trim();
    final telephoneBrut = _telephoneController.text.trim();
    final telephone = telephoneBrut.replaceAll(RegExp(r'[^\d]'), '');

    // 1. Validation du Prénom
    if (prenom.isEmpty) {
      setState(() {
        _prenomError = 'Entre ton prénom';
        _etape = 1;
      });
      _scrollToKey(_prenomKey);
      _prenomFocus.requestFocus();
      return;
    }

    // 2. Validation du Téléphone
    if (telephone.isEmpty) {
      setState(() {
        _telephoneError = 'Entre ton numéro de téléphone';
        _etape = 2;
      });
      _scrollToKey(_telephoneKey);
      _telephoneFocus.requestFocus();
      return;
    }

    if (telephone.length != 8) {
      setState(() {
        _telephoneError = 'Le numéro doit contenir exactement 8 chiffres';
        _etape = 2;
      });
      _scrollToKey(_telephoneKey);
      _telephoneFocus.requestFocus();
      return;
    }

    // 3. Validation de l'Activité
    if (_selectedActivity == null) {
      setState(() {
        _activiteError = 'Choisis ton activité';
        _etape = 3;
      });
      _scrollToKey(_activiteKey);
      return;
    }

    final email = _genererEmail(telephone);
    final password = _genererPassword(telephone);
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.registerCommercant(
      email: email,
      password: password,
      nom: _nomController.text.trim().isEmpty
          ? prenom
          : _nomController.text.trim(),
      prenom: prenom,
      telephone: telephone,
      typeActivite: _selectedActivity!,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/pin_setup');
    } else if (mounted) {
      String msg = authProvider.errorMessage ?? 'Une erreur est survenue';
      if (msg.contains('email-already-in-use')) {
        setState(() {
          _telephoneError = 'Ce numéro est déjà utilisé. Connecte-toi.';
        });
        _scrollToKey(_telephoneKey);
        _telephoneFocus.requestFocus();
      } else if (msg.contains('network')) {
        setState(() {
          _globalError = 'Pas de connexion Internet';
        });
      } else {
        setState(() {
          _globalError = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      // Erreur globale (ex: Pas de connexion)
                      if (_globalError != null) ...[
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
                                  _globalError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ÉTAPE 1 — Nom et prénom
                      Container(
                        key: _prenomKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('👤', 'Comment tu t\'appelles ?'),
                            const SizedBox(height: 16),
                            _buildChamp(
                              controller: _prenomController,
                              focusNode: _prenomFocus,
                              label: 'Ton prénom *',
                              hint: 'Ex: Ama',
                              errorText: _prenomError,
                              onChanged: (_) {
                                if (_prenomError != null) {
                                  setState(() => _prenomError = null);
                                }
                                setState(() => _etape = 1);
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildChamp(
                              controller: _nomController,
                              label: 'Ton nom (optionnel)',
                              hint: 'Ex: Koffi',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ÉTAPE 2 — Téléphone
                      Container(
                        key: _telephoneKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('📱', 'Ton numéro de téléphone'),
                            const SizedBox(height: 16),
                            _buildChamp(
                              controller: _telephoneController,
                              focusNode: _telephoneFocus,
                              label: 'Numéro *',
                              hint: '90000000',
                              clavier: TextInputType.phone,
                              errorText: _telephoneError,
                              onChanged: (_) {
                                if (_telephoneError != null) {
                                  setState(() => _telephoneError = null);
                                }
                                setState(() => _etape = 2);
                              },
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '🔒 Ton numéro sert à te connecter — personne ne le verra',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ÉTAPE 3 — Activité
                      Container(
                        key: _activiteKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('🏪', 'Qu\'est-ce que tu fais comme travail ?'),
                            const SizedBox(height: 16),

                            // Erreur spécifique pour la sélection d'activité
                            if (_activiteError != null) ...[
                              Text(
                                '⚠️ ${_activiteError!}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

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
                                      _activiteError = null;
                                      _etape = 3;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primaryGreen : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryGreen
                                            : _activiteError != null
                                                ? Colors.red.shade300
                                                : Colors.grey.shade300,
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
                          ],
                        ),
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
    FocusNode? focusNode,
    String? errorText,
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
          focusNode: focusNode,
          keyboardType: clavier,
          inputFormatters: formatters,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            errorText: errorText, // Affiche le message d'erreur directement SOUS le champ
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}