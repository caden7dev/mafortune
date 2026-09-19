import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _telephoneController = TextEditingController();
  final _passwordController = TextEditingController(); // Conservé pour la structure, bien que généré automatiquement

  final _telephoneFocus = FocusNode();
  final _telephoneKey = GlobalKey();

  bool _isLoading = false;
  String? _telephoneError;
  String? _globalErrorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
  static const Color emeraldGreen = Color(0xFF0B4F36);
  static const Color terracotta = Color(0xFFD96B43);
  static const Color textDark = Color(0xFF333333);
  static const Color textMedium = Color(0xFF555555);
  static const Color errorRed = Color(0xFF9B2C2C);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _telephoneController.dispose();
    _passwordController.dispose();
    _telephoneFocus.dispose();
    _animController.dispose();
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
      _telephoneError = null;
      _globalErrorMessage = null;
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

  Future<void> _connecter() async {
    _reinitialiserErreurs();
    setState(() => _isLoading = true);

    final telephone = _telephoneController.text.trim();

    if (telephone.isEmpty) {
      setState(() {
        _telephoneError = 'Entrez votre numéro de téléphone';
        _isLoading = false;
      });
      _scrollToKey(_telephoneKey);
      _telephoneFocus.requestFocus();
      return;
    }

    if (telephone.length < 8) {
      setState(() {
        _telephoneError = 'Entrez un numéro valide à 8 chiffres';
        _isLoading = false;
      });
      _scrollToKey(_telephoneKey);
      _telephoneFocus.requestFocus();
      return;
    }

    final email = _genererEmail(telephone);
    final password = _genererPassword(telephone);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(email, password);

      if (!mounted) return;

      if (!success) {
        String msg = authProvider.errorMessage ?? 'Erreur de connexion';

        if (msg.contains('user-not-found') ||
            msg.contains('invalid-credential') ||
            msg.contains('wrong-password')) {
          setState(() {
            _telephoneError = 'Numéro introuvable. Vérifiez ou créez un compte.';
          });
          _scrollToKey(_telephoneKey);
          _telephoneFocus.requestFocus();
        } else if (msg.contains('network')) {
          setState(() {
            _globalErrorMessage = 'Pas de connexion Internet';
          });
        } else {
          setState(() {
            _globalErrorMessage = msg;
          });
        }

        setState(() => _isLoading = false);
        return;
      }

      final userModel = await authProvider.getCurrentUser();

      if (!mounted) return;

      if (userModel == null) {
        setState(() {
          _globalErrorMessage = 'Impossible de charger le profil.';
          _isLoading = false;
        });
        return;
      }

      // ✅ Détection automatique du type d'utilisateur
      if (userModel.estAdministrateur) {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else {
        final authService = AuthService();
        final hasPin = await authService.isLocalPinSet();
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            hasPin ? '/pin_verify' : '/pin_setup',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _globalErrorMessage = 'Une erreur est survenue';
          _isLoading = false;
        });
      }
    }
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
                      // ── 1. BANNIÈRE SUPÉRIEURE : Vert Émeraude Sombre uni ──────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        decoration: const BoxDecoration(
                          color: emeraldGreen,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text('👋', style: TextStyle(fontSize: 36)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Content de te revoir !',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Connecte-toi avec ton numéro de téléphone',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
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
                                  // Erreur globale harmonisée
                                  if (_globalErrorMessage != null) ...[
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
                                              _globalErrorMessage!,
                                              style: const TextStyle(
                                                color: errorRed,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],

                                  // ── 4. TITRE DE CHAMP : Icône discrète Vert Émeraude ──
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_rounded, color: emeraldGreen, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Ton numéro de téléphone',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  Container(
                                    key: _telephoneKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F9FA),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: _telephoneError != null ? errorRed : Colors.grey.shade300,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                                                  border: Border(
                                                    right: BorderSide(color: Colors.grey.shade300),
                                                  ),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Text('🇹🇬', style: TextStyle(fontSize: 20)),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      '+228',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                        color: textDark,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: TextField(
                                                  controller: _telephoneController,
                                                  focusNode: _telephoneFocus,
                                                  keyboardType: TextInputType.phone,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.digitsOnly,
                                                    LengthLimitingTextInputFormatter(8),
                                                  ],
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: textDark,
                                                    letterSpacing: 1.5,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: '90 00 00 00',
                                                    hintStyle: TextStyle(
                                                      color: Colors.grey.shade400,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.normal,
                                                      letterSpacing: 1,
                                                    ),
                                                    border: InputBorder.none,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                                  ),
                                                  onChanged: (_) {
                                                    if (_telephoneError != null) {
                                                      setState(() => _telephoneError = null);
                                                    }
                                                  },
                                                  onSubmitted: (_) => _connecter(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_telephoneError != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            _telephoneError!,
                                            style: const TextStyle(
                                              color: errorRed,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      const Icon(Icons.lock_outline_rounded, size: 14, color: textMedium),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Ton numéro sert à te connecter — personne ne le verra',
                                          style: TextStyle(fontSize: 12, color: textMedium, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Spacer(),
                                  const SizedBox(height: 24),

                                  // ── 2. BOUTON PRINCIPAL : Terre Cuite, icône blanche ──
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
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isLoading
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
                                                Icon(Icons.login_rounded, color: Colors.white, size: 22),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Me connecter',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // ── SÉPARATEUR ─────────────────────────────────────
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Text(
                                          'OU',
                                          style: TextStyle(
                                            color: textMedium,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // ── 3. BOUTON SECONDAIRE : Vert Émeraude, bordure fine ──
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: emeraldGreen,
                                        side: const BorderSide(color: emeraldGreen, width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        'Créer mon compte',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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