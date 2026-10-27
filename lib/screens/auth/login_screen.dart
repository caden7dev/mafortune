import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../screens/commercant/compte_en_suppression_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // ✅ Contrôleurs séparés pour plus de clarté
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _telephoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  
  final _formKey = GlobalKey();

  bool _isLoading = false;
  String? _errorMessage;
  
  // ✅ État pour basculer entre connexion Téléphone et Email
  bool _isPhoneLogin = true; 

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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
    _emailController.dispose();
    _passwordController.dispose();
    _telephoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _reinitialiserErreurs() {
    setState(() => _errorMessage = null);
  }

  Future<void> _connecter() async {
    _reinitialiserErreurs();
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      bool success = false;

      // ✅ LOGIQUE SÉPARÉE ET CLAIRE
      if (_isPhoneLogin) {
        // --- CONNEXION PAR NUMÉRO (SANS MOT DE PASSE) ---
        final telephone = _telephoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
        
        if (telephone.length != 8) {
          setState(() {
            _errorMessage = 'Le numéro doit contenir exactement 8 chiffres';
            _isLoading = false;
          });
          return;
        }

        success = await authProvider.loginWithPhone(telephone);
        
        if (!success) {
          setState(() {
            // Message d'erreur spécifique et utile
            _errorMessage = 'Numéro introuvable. Avez-vous créé votre compte avec Google ?';
            _isLoading = false;
          });
          return;
        }
      } else {
        // --- CONNEXION PAR EMAIL + MOT DE PASSE ---
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        if (!email.contains('@')) {
          setState(() {
            _errorMessage = 'Veuillez entrer une adresse email valide';
            _isLoading = false;
          });
          return;
        }

        if (password.isEmpty) {
          setState(() {
            _errorMessage = 'Veuillez entrer votre mot de passe';
            _isLoading = false;
          });
          return;
        }

        success = await authProvider.login(email, password);
        
        if (!success) {
          setState(() {
            _errorMessage = 'Email ou mot de passe incorrect';
            _isLoading = false;
          });
          return;
        }
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

      // ✅ Vérifier si une suppression douce est en cours
      if (userModel.suppressionDemandee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => CompteEnSuppressionScreen(user: userModel)),
          (route) => false,
        );
        return;
      }

      // ✅ Redirection selon le type d'utilisateur
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

  // ✅ Widget pour le bouton bascule (Toggle)
  Widget _buildToggleOption(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        _reinitialiserErreurs();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isSelected ? emeraldGreen : textMedium,
            ),
          ),
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
                                onTap: () => Navigator.pop(context),
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
                            Text(
                              _isPhoneLogin ? 'Connecte-toi avec ton numéro' : 'Connecte-toi avec ton email',
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.w500),
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

                                  // ✅ 2. BOUTON BASCULE (TOGGLE) TÉLÉPHONE / EMAIL
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildToggleOption('📱 Numéro', _isPhoneLogin, () => setState(() => _isPhoneLogin = true))),
                                        Expanded(child: _buildToggleOption('✉️ Email', !_isPhoneLogin, () => setState(() => _isPhoneLogin = false))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ✅ 3. CHAMPS DE SAISIE CONDITIONNELS
                                  if (_isPhoneLogin) ...[
                                    // --- CHAMP NUMÉRO SEUL (Structure robuste sans débordement) ---
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
                                  ] else ...[
                                    // --- CHAMPS EMAIL + MOT DE PASSE ---
                                    const Text('Adresse email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _emailController,
                                      focusNode: _emailFocus,
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
                                      decoration: InputDecoration(
                                        hintText: 'nom@exemple.com',
                                        filled: true,
                                        fillColor: const Color(0xFFF8F9FA),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: emeraldGreen, width: 2)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      ),
                                      onChanged: (_) => _reinitialiserErreurs(),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text('Mot de passe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      obscureText: true,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
                                      decoration: InputDecoration(
                                        hintText: 'Ton mot de passe',
                                        filled: true,
                                        fillColor: const Color(0xFFF8F9FA),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: emeraldGreen, width: 2)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                        suffixIcon: const Icon(Icons.visibility_off_outlined, color: textMedium, size: 20),
                                      ),
                                      onSubmitted: (_) => _connecter(),
                                    ),
                                  ],

                                  const Spacer(),
                                  const SizedBox(height: 24),

                                  // ── BOUTON PRINCIPAL ──
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

                                  // ── SÉPARATEUR ──
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('OU', style: TextStyle(color: textMedium, fontWeight: FontWeight.w600, fontSize: 12))),
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // ── BOUTON SECONDAIRE ──
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