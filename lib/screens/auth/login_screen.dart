import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../models/utilisateur_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _telephoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final _telephoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final _telephoneKey = GlobalKey();
  final _passwordKey = GlobalKey();

  bool _showPassword = false;
  bool _isLoading = false;

  String? _telephoneError;
  String? _passwordError;
  String? _globalErrorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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
    _passwordFocus.dispose();
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
      _passwordError = null;
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
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                      // ── Header ───────────────────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(28)),
                        ),
                        child: Column(
                          children: [
                            // Bouton retour
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Icône
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2),
                              ),
                              child: const Center(
                                child:
                                    Text('👋', style: TextStyle(fontSize: 36)),
                              ),
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              'Content de te revoir !',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Connecte-toi avec ton numéro de téléphone',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Contenu ──────────────────────────────────────────────────────
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 24, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Erreur globale
                                  if (_globalErrorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.red.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text('⚠️',
                                              style: TextStyle(fontSize: 18)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _globalErrorMessage!,
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 14,
                                                  height: 1.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // ── TÉLÉPHONE ────────────────────────────────────────
                                  const Text(
                                    '📱  Ton numéro de téléphone',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 30),

                                  Container(
                                    key: _telephoneKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: _telephoneError != null
                                                  ? Colors.red
                                                  : const Color(0xFFE5E7EB),
                                              width: _telephoneError != null
                                                  ? 2.0
                                                  : 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.04),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 18),
                                                decoration:
                                                    const BoxDecoration(
                                                  color: Color(0xFFF8F9FA),
                                                  borderRadius:
                                                      BorderRadius.horizontal(
                                                          left: Radius.circular(
                                                              16)),
                                                  border: Border(
                                                    right: BorderSide(
                                                        color: Color(
                                                            0xFFE5E7EB)),
                                                  ),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Text('🇹🇬',
                                                        style: TextStyle(
                                                            fontSize: 20)),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      '+228',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      _telephoneController,
                                                  focusNode: _telephoneFocus,
                                                  keyboardType:
                                                      TextInputType.phone,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                        8),
                                                  ],
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    letterSpacing: 2,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: '90 00 00 00',
                                                    hintStyle: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      letterSpacing: 1,
                                                    ),
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 16,
                                                            vertical: 18),
                                                  ),
                                                  onChanged: (_) {
                                                    if (_telephoneError !=
                                                        null) {
                                                      setState(() =>
                                                          _telephoneError =
                                                              null);
                                                    }
                                                  },
                                                  onSubmitted: (_) =>
                                                      _connecter(),
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
                                              color: Colors.red,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Ton numéro sert à te connecter — personne ne le verra',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500]),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Spacer(),
                                  const SizedBox(height: 24),

                                  // ── BOUTON CONNEXION ──────────────────────────────────
                                  SizedBox(
                                    width: double.infinity,
                                    height: 60,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _connecter,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            Colors.grey[300],
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
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
                                          : const Text(
                                              '🔑  Me connecter',
                                              style: TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // ── INSCRIPTION ────────────────────────────────────────
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Divider(
                                              color: Colors.grey[300])),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        child: Text(
                                          'OU',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                          child: Divider(
                                              color: Colors.grey[300])),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pushReplacementNamed(
                                              context, '/signup'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppColors.primaryGreen,
                                        side: const BorderSide(
                                            color: AppColors.primaryGreen,
                                            width: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        'Créer mon compte',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
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