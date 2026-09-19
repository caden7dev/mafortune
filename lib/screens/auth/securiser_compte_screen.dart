import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldGreen = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color textDark = Color(0xFF333333);
const Color textMedium = Color(0xFF555555);
const Color errorRed = Color(0xFF9B2C2C);

class SecuriserCompteScreen extends StatefulWidget {
  final bool isOnboarding;
  const SecuriserCompteScreen({super.key, this.isOnboarding = true});

  @override
  State<SecuriserCompteScreen> createState() => _SecuriserCompteScreenState();
}

class _SecuriserCompteScreenState extends State<SecuriserCompteScreen>
    with TickerProviderStateMixin {
  bool _isLoadingGoogle = false;
  bool _isLoadingEmail = false;
  bool _showEmailForm = false;
  bool _isLoadingStatus = true;

  final _emailController = TextEditingController();
  String? _errorMessage;
  String? _emailSecours;
  bool _googleLie = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _loadSecurityStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final email = data['emailSecours'] as String?;
        final googleLie = data['googleLie'] as bool? ?? false;

        final vraiEmail =
            (email != null && !email.endsWith('@mafortune.tg')) ? email : null;

        setState(() {
          _emailSecours = vraiEmail;
          _googleLie = googleLie;
          _isLoadingStatus = false;
        });
      } else {
        setState(() => _isLoadingStatus = false);
      }
    } catch (e) {
      setState(() => _isLoadingStatus = false);
    }
  }

  bool get _estSecurise => _googleLie || _emailSecours != null;

  void _naviguerSuite() {
    if (widget.isOnboarding) {
      Navigator.pushReplacementNamed(context, '/mes_produits');
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _lierGoogle() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoadingGoogle = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = FirebaseAuth.instance.currentUser;
      await user?.linkWithCredential(credential);

      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user?.uid)
          .update({
        'googleLie': true,
        'emailSecours': googleUser.email,
      });

      setState(() {
        _googleLie = true;
        _emailSecours = googleUser.email;
        _isLoadingGoogle = false;
      });

      _showSuccessAndNavigate('Compte Google lié avec succès !');
    } on FirebaseAuthException catch (e) {
      String msg;
      if (e.code == 'credential-already-in-use') {
        msg = 'Ce compte Google est déjà utilisé par un autre compte.';
      } else if (e.code == 'provider-already-linked') {
        msg = 'Un compte Google est déjà lié.';
      } else {
        msg = 'Connexion Google échouée. Essaie l\'option email.';
      }
      setState(() {
        _isLoadingGoogle = false;
        _errorMessage = msg;
      });
    } catch (e) {
      setState(() {
        _isLoadingGoogle = false;
        _errorMessage = 'Connexion Google échouée. Vérifie ta connexion ou utilise l\'email.';
      });
    }
  }

  Future<void> _lierEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Entre un email valide');
      return;
    }

    if (email.endsWith('@mafortune.tg')) {
      setState(() => _errorMessage = 'Entre ton vrai email (Gmail, Yahoo, etc.)');
      return;
    }

    setState(() {
      _isLoadingEmail = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user?.uid)
          .update({
        'emailSecours': email,
        'googleLie': false,
      });

      setState(() {
        _emailSecours = email;
        _isLoadingEmail = false;
        _showEmailForm = false;
      });

      _emailController.clear();
      _showSuccessAndNavigate('Email de secours enregistré !');
    } catch (e) {
      setState(() {
        _isLoadingEmail = false;
        _errorMessage = 'Impossible d\'enregistrer l\'email. Réessaie.';
      });
    }
  }

  Future<void> _supprimerEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user?.uid)
          .update({
        'emailSecours': FieldValue.delete(),
        'googleLie': false,
      });
      setState(() {
        _emailSecours = null;
        _googleLie = false;
      });
    } catch (e) {
      debugPrint('Erreur suppression email: $e');
    }
  }

  void _showSuccessAndNavigate(String message) {
    _showSuccess(message);
    Future.delayed(const Duration(milliseconds: 1000), _naviguerSuite);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontSize: 15, color: Colors.white)),
          ],
        ),
        backgroundColor: emeraldGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: !widget.isOnboarding
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: textDark, size: 18),
                ),
              ),
              title: const Text('Sécuriser mon compte',
                  style: TextStyle(
                      color: textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: _isLoadingStatus
            ? const Center(child: CircularProgressIndicator(color: emeraldGreen))
            : FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Column(
                      children: [
                        // ── 1. ILLUSTRATION : Icône épurée Vert Émeraude sur fond 10% ──
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: emeraldGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: emeraldGreen.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _estSecurise ? Icons.security_rounded : Icons.lock_open_rounded,
                              color: emeraldGreen,
                              size: 48,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Titres ──────────────────────────────────────
                        Text(
                          _estSecurise ? 'Compte sécurisé !' : 'Sécurise ton compte',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        Text(
                          _estSecurise
                              ? 'Tu pourras récupérer ton compte\nen cas d\'oubli du PIN.'
                              : 'Relie ton compte Google ou ajoute un email\npour ne jamais perdre l\'accès.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: textMedium,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Erreur harmonisée
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: errorRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: errorRed.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: errorRed, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: errorRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _errorMessage = null),
                                  child: const Icon(Icons.close, color: errorRed, size: 18),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── 2. OPTION GOOGLE ─────────────────────────────
                        _buildOptionCard(
                          leading: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: _googleLie
                                  ? const Icon(Icons.check_circle, color: emeraldGreen, size: 28)
                                  : const Text('G',
                                      style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4285F4),
                                          fontFamily: 'serif')),
                            ),
                          ),
                          title: _googleLie ? 'Google lié' : 'Lier avec Google',
                          // ✅ Étoile "Recommandé" en Terre Cuite
                          subtitleWidget: _googleLie
                              ? Text(_emailSecours ?? 'Compte Google connecté',
                                  style: const TextStyle(fontSize: 13, color: textMedium))
                              : Row(
                                  children: [
                                    const Icon(Icons.star, color: terracotta, size: 16),
                                    const SizedBox(width: 4),
                                    const Text('Recommandé',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: terracotta)),
                                  ],
                                ),
                          isLoading: _isLoadingGoogle,
                          isDone: _googleLie,
                          onTap: _googleLie ? null : _lierGoogle,
                        ),

                        const SizedBox(height: 12),

                        // ── 2. OPTION EMAIL ──────────────────────────────
                        if (!_showEmailForm)
                          _buildOptionCard(
                            // ✅ Icône enveloppe minimaliste Vert Émeraude
                            leading: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: (_emailSecours != null && !_googleLie)
                                    ? emeraldGreen.withOpacity(0.1)
                                    : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: (_emailSecours != null && !_googleLie)
                                        ? emeraldGreen.withOpacity(0.3)
                                        : Colors.grey.shade200),
                              ),
                              child: Center(
                                child: _emailSecours != null && !_googleLie
                                    ? const Icon(Icons.check_circle, color: emeraldGreen, size: 28)
                                    : const Icon(Icons.email_outlined, color: emeraldGreen, size: 24),
                              ),
                            ),
                            title: (_emailSecours != null && !_googleLie) ? 'Email enregistré' : 'Email de secours',
                            subtitleWidget: (_emailSecours != null && !_googleLie)
                                ? Text(_emailSecours!, style: const TextStyle(fontSize: 13, color: textMedium))
                                : const Text('Pour récupérer ton compte par email',
                                    style: TextStyle(fontSize: 13, color: textMedium)),
                            isLoading: false,
                            isDone: _emailSecours != null && !_googleLie,
                            trailing: (_emailSecours != null && !_googleLie)
                                ? GestureDetector(
                                    onTap: _supprimerEmail,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: errorRed.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('Supprimer',
                                          style: TextStyle(
                                              color: errorRed,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  )
                                : null,
                            onTap: (_emailSecours != null && !_googleLie) ? null : () => setState(() => _showEmailForm = true),
                          )
                        else
                          _buildEmailForm(),

                        const SizedBox(height: 32),

                        // ── 3. BOUTON "PLUS TARD" ÉPURÉ ──────────────────
                        if (!_estSecurise)
                          TextButton(
                            onPressed: _naviguerSuite,
                            child: const Text(
                              'Plus tard',
                              style: TextStyle(
                                color: textMedium, // Gris neutre élégant
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _naviguerSuite,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: emeraldGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                widget.isOnboarding ? 'Continuer' : 'Terminé',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),

                        // ── 4. TEXTE D'EXPLICATION BAS DE PAGE ───────────
                        if (!_estSecurise) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Tu pourras le faire à tout moment depuis ton profil',
                            style: TextStyle(
                                fontSize: 13,
                                color: textMedium, // ✅ Gris foncé lisible (#555555)
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOptionCard({
    required Widget leading,
    required String title,
    required Widget subtitleWidget, // Changé en Widget pour plus de flexibilité (ex: Row avec étoile)
    required bool isLoading,
    required bool isDone,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: isLoading || isDone ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone ? emeraldGreen.withOpacity(0.4) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDone ? emeraldGreen : textDark,
                      )),
                  const SizedBox(height: 4),
                  subtitleWidget,
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: emeraldGreen),
              )
            else if (trailing != null)
              trailing
            else if (!isDone)
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emeraldGreen.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Titre du formulaire avec icône épurée
          Row(
            children: [
              const Icon(Icons.email_outlined, color: emeraldGreen, size: 20),
              const SizedBox(width: 10),
              const Text('Ton adresse email',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textDark)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Entre ton Gmail, Yahoo ou autre email',
              style: TextStyle(fontSize: 13, color: textMedium)),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 16, color: textDark),
            decoration: InputDecoration(
              hintText: 'exemple@gmail.com',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
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
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _showEmailForm = false);
                    _emailController.clear();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textMedium,
                    side: BorderSide(color: Colors.grey.shade300!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingEmail ? null : _lierEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: emeraldGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoadingEmail
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}