import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  // 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
  static const Color emeraldGreen = Color(0xFF0B4F36);
  static const Color terracotta = Color(0xFFD96B43);
  static const Color textDark = Color(0xFF333333);
  static const Color textMedium = Color(0xFF555555);
  static const Color errorRed = Color(0xFF9B2C2C);

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
      nom: _nomController.text.trim().isEmpty ? prenom : _nomController.text.trim(),
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
          _globalError = 'Pas de connexion Internet. Vérifie ton réseau.';
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
              // Header épuré
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: emeraldGreen, size: 28),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Créer mon compte',
                      style: TextStyle(
                        color: emeraldGreen,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "C'est rapide, gratuit et sécurisé.",
                      style: TextStyle(
                        color: textMedium,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Indicateurs d'étape
                    Row(
                      children: [1, 2, 3].map((i) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: _etape == i ? 32 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _etape == i ? terracotta : Colors.grey.shade300,
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
                  // ✅ 3. ESPACEMENT : Padding ajusté pour un flux de lecture fluide
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Erreur globale
                      if (_globalError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: errorRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: errorRed.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: errorRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _globalError!,
                                  style: const TextStyle(color: errorRed, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ✅ 1 & 2. SIMPLIFICATION : Plus de titres redondants, juste les labels et les icônes internes
                      // ÉTAPE 1 — Nom et prénom
                      Container(
                        key: _prenomKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildChamp(
                              controller: _prenomController,
                              focusNode: _prenomFocus,
                              label: 'Ton prénom *',
                              hint: 'Ex: Ama',
                              icon: Icons.badge_outlined,
                              errorText: _prenomError,
                              onChanged: (_) {
                                if (_prenomError != null) setState(() => _prenomError = null);
                                setState(() => _etape = 1);
                              },
                            ),
                            const SizedBox(height: 16), // Espacement compact et harmonieux
                            _buildChamp(
                              controller: _nomController,
                              label: 'Ton nom (optionnel)',
                              hint: 'Ex: Koffi',
                              icon: Icons.person_outline_rounded,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24), // Séparation fluide entre les blocs

                      // ÉTAPE 2 — Téléphone
                      Container(
                        key: _telephoneKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildChamp(
                              controller: _telephoneController,
                              focusNode: _telephoneFocus,
                              label: 'Numéro *',
                              hint: '90 00 00 00',
                              icon: Icons.phone_outlined,
                              clavier: TextInputType.phone,
                              errorText: _telephoneError,
                              onChanged: (_) {
                                if (_telephoneError != null) setState(() => _telephoneError = null);
                                setState(() => _etape = 2);
                              },
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '🔒 Ton numéro sert à te connecter. Il reste confidentiel.',
                              style: TextStyle(color: textMedium, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32), // Respiration avant la section importante

                      // ÉTAPE 3 — Activité (Titre et icône conservés comme demandé)
                      Container(
                        key: _activiteKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(Icons.storefront_outlined, 'Qu\'est-ce que tu fais ?'),
                            const SizedBox(height: 16),

                            if (_activiteError != null) ...[
                              Text(
                                '⚠️ $_activiteError',
                                style: const TextStyle(
                                  color: errorRed,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                      color: isSelected ? emeraldGreen.withOpacity(0.08) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected 
                                            ? emeraldGreen 
                                            : (_activiteError != null ? errorRed : Colors.grey.shade300),
                                        width: isSelected ? 2 : 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(activite['emoji']!, style: const TextStyle(fontSize: 32)),
                                        const SizedBox(height: 8),
                                        Text(
                                          activite['label']!,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? emeraldGreen : textMedium,
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

                      // Bouton principal
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _creerCompte,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: terracotta,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            shadowColor: terracotta.withOpacity(0.3),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Créer mon compte',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text(
                            "J'ai déjà un compte",
                            style: TextStyle(
                              color: emeraldGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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

  // ✅ Icône de section conservée UNIQUEMENT pour "Qu'est-ce que tu fais ?"
  Widget _buildSectionTitle(IconData icon, String titre) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: emeraldGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: emeraldGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titre,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Champs de saisie épurés : icône discrète en préfixe, pas de titre redondant au-dessus
  Widget _buildChamp({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: clavier,
          inputFormatters: formatters,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, color: textDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: emeraldGreen, size: 20), // Icône discrète à l'intérieur
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            errorText: errorText,
            errorStyle: const TextStyle(
              color: errorRed,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
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
              borderSide: const BorderSide(color: emeraldGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: errorRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: errorRed, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}