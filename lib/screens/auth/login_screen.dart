import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ AJOUTÉ pour le consentement implicite
import '../../providers/auth_provider.dart';
import '../../models/utilisateur_model.dart';
import '../../services/auth_service.dart';
import '../../screens/commercant/compte_en_suppression_screen.dart';
import 'signup_screen.dart';
import 'cgu_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _telephoneController = TextEditingController();
  final _telephoneFocus = FocusNode();
  
  final _formKey = GlobalKey();

  bool _isLoading = false;
  String? _errorMessage;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ✅ Liste des activités pour le dialogue de finalisation
  final List<Map<String, String>> _activites = [
    {'emoji': '🛒', 'label': 'Vente de produits'},
    {'emoji': '🍲', 'label': 'Restauration'},
    {'emoji': '✂️', 'label': 'Coiffure'},
    {'emoji': '🧵', 'label': 'Couture'},
    {'emoji': '🔧', 'label': 'Artisan'},
    {'emoji': '📦', 'label': 'Commerce divers'},
  ];
  String? _dialogSelectedActivity;

  // 🎨 CHARTE GRAPHIQUE MA FORTUNE
  static const Color emeraldGreen = Color(0xFF0B4F36);
  static const Color terracotta = Color(0xFFD96B43);
  static const Color textDark = Color(0xFF333333);
  static const Color textMedium = Color(0xFF555555);
  static const Color errorRed = Color(0xFF9B2C2C);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _telephoneController.dispose();
    _telephoneFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _reinitialiserErreurs() {
    setState(() => _errorMessage = null);
  }

  // ✅ NOUVELLE MÉTHODE : Gérer l'ouverture des liens (CGU en local, Politique en WebView)
  void _handleLinkTap(String type) {
    if (type == 'terms') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CguScreen()),
      );
    } else if (type == 'privacy') {
      _openPrivacyPolicy();
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final String url = 'https://garnet-stone-55f.notion.site/Politique-de-Confidentialit-MaFortune-3e9256a556ad80409f3ad78e0a6c6e70?source=copy_link';
    final Uri uri = Uri.parse(url);
    
    if (!await launchUrl(
      uri,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien.')),
        );
      }
    }
  }

  Future<void> _connecter() async {
    _reinitialiserErreurs();
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final telephone = _telephoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      
      if (telephone.length != 8) {
        setState(() {
          _errorMessage = 'Le numéro doit contenir exactement 8 chiffres';
          _isLoading = false;
        });
        return;
      }

      final success = await authProvider.loginWithPhone(telephone);
      
      if (!success) {
        setState(() {
          _errorMessage = 'Numéro introuvable. Avez-vous créé votre compte avec Google ?';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      final userModel = await authProvider.getCurrentUser();
      if (userModel == null) {
        setState(() {
          _errorMessage = 'Impossible de charger le profil.';
          _isLoading = false;
        });
        return;
      }

      if (userModel.suppressionDemandee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => CompteEnSuppressionScreen(user: userModel)),
          (route) => false,
        );
        return;
      }

      // ✅ CONSENTEMENT IMPLICITE DES CONDITIONS LORS DE LA CONNEXION
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terms_accepted', true);

      if (userModel.estAdministrateur) {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else {
        final authService = AuthService();
        final hasPin = await authService.isLocalPinSet();
        if (mounted) {
          Navigator.pushReplacementNamed(context, hasPin ? '/pin_verify' : '/pin_setup');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue: ${e.toString().replaceAll('Exception: ', '')}';
          _isLoading = false;
        });
      }
    }
  }

  // ✅ NOUVELLE MÉTHODE : Connexion avec Google
  Future<void> _loginWithGoogle() async {
    _reinitialiserErreurs();
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signInWithGoogle();

      if (success && mounted) {
        final user = await authProvider.getCurrentUser();
        
        // Si l'utilisateur n'a pas de numéro, on lui demande le numéro ET l'activité
        if (user != null && (user.telephone == null || user.telephone!.isEmpty || user.telephone == '00000000')) {
          _showPhoneCompletionDialog(user, authProvider);
        } else {
          // ✅ CORRECTION : On vérifie si un PIN existe déjà avant de rediriger
          final authService = AuthService();
          final hasPin = await authService.isLocalPinSet();
          
          // ✅ CONSENTEMENT IMPLICITE DES CONDITIONS LORS DE LA CONNEXION GOOGLE
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('terms_accepted', true);
          
          if (mounted) {
            Navigator.pushReplacementNamed(
              context, 
              hasPin ? '/pin_verify' : '/pin_setup'
            );
          }
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Échec de la connexion Google';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ✅ Fenêtre de complétion du numéro ET de l'activité
  void _showPhoneCompletionDialog(UtilisateurModel user, AuthProvider authProvider) {
    final phoneController = TextEditingController();
    String? phoneError;
    String? activityError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Finalisez votre compte', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 40, color: emeraldGreen),
                const SizedBox(height: 12),
                const Text(
                  'Votre compte Google est connecté. Pour terminer, ajoutez votre numéro et votre activité.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: textMedium),
                ),
                const SizedBox(height: 20),

                // 1. Champ Numéro
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Numéro de téléphone *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: phoneError != null ? errorRed : Colors.grey.shade300, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🇹🇬', style: TextStyle(fontSize: 20)),
                                SizedBox(width: 6),
                                Text('+228', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                                SizedBox(width: 8),
                                Text('|', style: TextStyle(color: Colors.grey, fontSize: 18)),
                                SizedBox(width: 8),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              textAlign: TextAlign.left,
                              maxLength: 8,
                              enabled: !isSubmitting,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                counterText: '',
                                hintText: '90 00 00 00',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (phoneError != null) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(phoneError!, style: const TextStyle(color: errorRed, fontSize: 12, fontWeight: FontWeight.w500))),
                  ],
                ),

                const SizedBox(height: 20),

                // 2. Sélection Activité
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Votre activité *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
                    const SizedBox(height: 8),
                    if (activityError != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('⚠️ $activityError', style: const TextStyle(color: errorRed, fontSize: 12, fontWeight: FontWeight.w600))),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: _activites.map((activite) {
                        final isSelected = _dialogSelectedActivity == activite['label'];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setDialogState(() {
                              _dialogSelectedActivity = activite['label'];
                              activityError = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected ? emeraldGreen.withOpacity(0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? emeraldGreen : (activityError != null ? errorRed : Colors.grey.shade300),
                                width: isSelected ? 2 : 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(activite['emoji']!, style: const TextStyle(fontSize: 24)),
                                const SizedBox(height: 4),
                                Text(
                                  activite['label']!,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? emeraldGreen : textMedium),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await authProvider.logout(); 
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/welcome');
                      }
                    },
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final phone = phoneController.text.trim();
                      
                      if (phone.length != 8) {
                        setDialogState(() { phoneError = 'Le numéro doit faire 8 chiffres'; });
                        HapticFeedback.heavyImpact();
                        return;
                      }
                      if (_dialogSelectedActivity == null) {
                        setDialogState(() { activityError = 'Choisissez votre activité'; });
                        HapticFeedback.heavyImpact();
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final telephoneComplet = '+228$phone';

                      final successPhone = await authProvider.lierTelephone(telephoneComplet);
                      if (!successPhone) {
                        setDialogState(() {
                          isSubmitting = false;
                          phoneError = authProvider.errorMessage ?? 'Erreur de liaison';
                        });
                        return;
                      }

                      final updatedUser = user.copyWith(
                        telephone: telephoneComplet,
                        typeActivite: _dialogSelectedActivity,
                      );
                      await authProvider.updateProfile(updatedUser);

                      // ✅ CONSENTEMENT IMPLICITE DES CONDITIONS LORS DE LA FINALISATION
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('terms_accepted', true);

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        Navigator.pushReplacementNamed(context, '/pin_setup');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Terminer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                      // ── 1. BANNIÈRE SUPÉRIEURE ──────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        decoration: const BoxDecoration(
                          color: emeraldGreen,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                                  );
                                },
                                child: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 76, height: 76,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15), shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                              ),
                              child: const Center(child: Text('👋', style: TextStyle(fontSize: 36))),
                            ),
                            const SizedBox(height: 12),
                            const Text('Content de te revoir !', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            const SizedBox(height: 6),
                            const Text(
                              'Connecte-toi avec ton numéro',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      // ── CONTENU ──────────────────────────────────────────────────
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(color: errorRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: errorRed.withOpacity(0.2))),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: errorRed, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: errorRed, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],

                                  const Text('Ton numéro de téléphone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('🇹🇬', style: TextStyle(fontSize: 20)),
                                              SizedBox(width: 6),
                                              Text('+228', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                                              SizedBox(width: 8),
                                              Text('|', style: TextStyle(color: Colors.grey, fontSize: 18)),
                                              SizedBox(width: 8),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _telephoneController,
                                            focusNode: _telephoneFocus,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark, letterSpacing: 1.5),
                                            decoration: const InputDecoration(
                                              hintText: '90 00 00 00',
                                              hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                                            ),
                                            onChanged: (_) => _reinitialiserErreurs(),
                                            onSubmitted: (_) => _connecter(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: const [
                                      Icon(Icons.lock_outline_rounded, size: 14, color: textMedium),
                                      SizedBox(width: 6),
                                      Expanded(child: Text('Aucun mot de passe requis pour ton numéro', style: TextStyle(fontSize: 12, color: textMedium, fontWeight: FontWeight.w500))),
                                    ],
                                  ),

                                  const Spacer(),
                                  const SizedBox(height: 24),

                                  // ✅ TEXTE INFORMATIF (Consentement implicite)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 12, color: textMedium, height: 1.4),
                                        children: [
                                          const TextSpan(text: 'En vous connectant, vous acceptez les '),
                                          TextSpan(
                                            text: 'Conditions générales',
                                            style: const TextStyle(color: emeraldGreen, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                            recognizer: TapGestureRecognizer()..onTap = () => _handleLinkTap('terms'),
                                          ),
                                          const TextSpan(text: ' et la '),
                                          TextSpan(
                                            text: 'Politique de confidentialité',
                                            style: const TextStyle(color: emeraldGreen, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                            recognizer: TapGestureRecognizer()..onTap = () => _handleLinkTap('privacy'),
                                          ),
                                          const TextSpan(text: '.'),
                                        ],
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 60,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _connecter,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: terracotta,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: Colors.grey.shade300,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.login_rounded, color: Colors.white, size: 22),
                                                SizedBox(width: 8),
                                                Text('Me connecter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('OU', style: TextStyle(color: textMedium, fontWeight: FontWeight.w600, fontSize: 12))),
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _loginWithGoogle,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: textDark,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/image/googlelogo.png',
                                            width: 30,
                                            height: 30,
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Continuer avec Google',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: emeraldGreen,
                                        side: const BorderSide(color: emeraldGreen, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Text('Créer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
}