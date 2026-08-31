import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_colors.dart';

class SecuriserCompteScreen extends StatefulWidget {
  // ✅ isOnboarding: true → vient de l'inscription → redirige vers /mes_produits
  // ✅ isOnboarding: false → vient du profil → Navigator.pop()
  final bool isOnboarding;
  const SecuriserCompteScreen({super.key, this.isOnboarding = true});

  @override
  State<SecuriserCompteScreen> createState() =>
      _SecuriserCompteScreenState();
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

  // ─── Vérifie l'état de sécurité actuel ──────────────────────────────────
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

        // ✅ Filtre l'email auto-généré @mafortune.tg
        final vraiEmail =
            (email != null && !email.endsWith('@mafortune.tg'))
                ? email
                : null;

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

  // ─── Navigation ──────────────────────────────────────────────────────────
  void _naviguerSuite() {
    if (widget.isOnboarding) {
      // Après inscription → aller configurer les produits
      Navigator.pushReplacementNamed(context, '/mes_produits');
    } else {
      // Depuis le profil → retour arrière
      Navigator.pop(context);
    }
  }

  // ─── Lier Google ─────────────────────────────────────────────────────────
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
        _errorMessage =
            'Connexion Google échouée.\nVérifie ta connexion internet\nou utilise l\'option email.';
      });
    }
  }

  // ─── Lier Email ──────────────────────────────────────────────────────────
  Future<void> _lierEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Entre un email valide');
      return;
    }

    if (email.endsWith('@mafortune.tg')) {
      setState(() =>
          _errorMessage = 'Entre ton vrai email (Gmail, Yahoo, etc.)');
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

  // ─── Supprimer email ─────────────────────────────────────────────────────
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
    Future.delayed(
        const Duration(milliseconds: 1000), _naviguerSuite);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontSize: 15)),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                      color: Colors.black87, size: 18),
                ),
              ),
              title: const Text('Sécuriser mon compte',
                  style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: _isLoadingStatus
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primaryGreen))
            : FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Column(
                      children: [
                        // ── Icône ──────────────────────────────────────
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: _estSecurise
                                ? AppColors.primaryGreen
                                    .withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _estSecurise
                                  ? AppColors.primaryGreen
                                      .withOpacity(0.3)
                                  : Colors.orange.withOpacity(0.3),
                              width: 2.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _estSecurise ? '🛡️' : '🔓',
                              style: const TextStyle(fontSize: 52),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Titre ──────────────────────────────────────
                        Text(
                          _estSecurise
                              ? 'Compte sécurisé !'
                              : 'Sécurise ton compte',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 10),

                        Text(
                          _estSecurise
                              ? 'Tu pourras récupérer ton compte\nen cas d\'oubli du PIN.'
                              : 'Relie ton compte Google ou ajoute un email\npour ne jamais perdre l\'accès.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 28),

                        // Erreur
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text('⚠️',
                                    style:
                                        TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        height: 1.5),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _errorMessage = null),
                                  child: const Icon(Icons.close,
                                      color: Colors.red, size: 18),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Option Google ─────────────────────────────
                        _buildOptionCard(
                          leading: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0FE),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _googleLie
                                  ? const Icon(
                                      Icons.check_circle,
                                      color:
                                          AppColors.primaryGreen,
                                      size: 28)
                                  : const Text('G',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight:
                                              FontWeight.bold,
                                          color:
                                              Color(0xFF4285F4),
                                          fontFamily: 'serif')),
                            ),
                          ),
                          title: _googleLie
                              ? 'Google lié ✅'
                              : 'Lier avec Google',
                          subtitle: _googleLie
                              ? _emailSecours ??
                                  'Compte Google connecté'
                              : 'Recommandé ⭐ — rapide et sécurisé',
                          isLoading: _isLoadingGoogle,
                          isDone: _googleLie,
                          onTap: _googleLie ? null : _lierGoogle,
                        ),

                        const SizedBox(height: 12),

                        // ── Option Email ──────────────────────────────
                        if (!_showEmailForm)
                          _buildOptionCard(
                            leading: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _emailSecours != null &&
                                        !_googleLie
                                    ? AppColors.primaryGreen
                                        .withOpacity(0.1)
                                    : Colors.grey[100],
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: _emailSecours != null &&
                                        !_googleLie
                                    ? const Icon(
                                        Icons.check_circle,
                                        color:
                                            AppColors.primaryGreen,
                                        size: 28)
                                    : const Text('📧',
                                        style: TextStyle(
                                            fontSize: 24)),
                              ),
                            ),
                            title: _emailSecours != null &&
                                    !_googleLie
                                ? 'Email enregistré ✅'
                                : 'Email de secours',
                            subtitle: _emailSecours != null &&
                                    !_googleLie
                                ? _emailSecours!
                                : 'Pour récupérer ton compte par email',
                            isLoading: false,
                            isDone: _emailSecours != null &&
                                !_googleLie,
                            trailing: _emailSecours != null &&
                                    !_googleLie
                                ? GestureDetector(
                                    onTap: _supprimerEmail,
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                      ),
                                      child: const Text('Supprimer',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ),
                                  )
                                : null,
                            onTap: _emailSecours != null && !_googleLie
                                ? null
                                : () => setState(
                                    () => _showEmailForm = true),
                          )
                        else
                          _buildEmailForm(),

                        const SizedBox(height: 28),

                        // Séparateur
                        Row(
                          children: [
                            Expanded(
                                child:
                                    Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              child: Text('OU',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                                child:
                                    Divider(color: Colors.grey[300])),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Bouton principal ──────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _naviguerSuite,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _estSecurise
                                  ? AppColors.primaryGreen
                                  : Colors.grey[600],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            child: Text(
                              _estSecurise
                                  ? (widget.isOnboarding
                                      ? '🚀  Continuer'
                                      : '✅  Terminé')
                                  : 'Plus tard',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        if (!_estSecurise) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.isOnboarding
                                ? 'Tu pourras le faire plus tard dans\nProfil → Sécuriser mon compte'
                                : 'Tu pourras le faire à tout moment depuis ton profil',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500]),
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
    required String subtitle,
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
            color: isDone
                ? AppColors.primaryGreen.withOpacity(0.4)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                        fontWeight: FontWeight.bold,
                        color: isDone
                            ? AppColors.primaryGreen
                            : const Color(0xFF1A1A2E),
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen),
              )
            else if (trailing != null)
              trailing
            else if (!isDone)
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey[400]),
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
        border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.3),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📧', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text('Ton adresse email',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 6),
          Text('Entre ton Gmail, Yahoo ou autre email',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'exemple@gmail.com',
              hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 15),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE5E7EB), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE5E7EB), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primaryGreen, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _showEmailForm = false);
                    _emailController.clear();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingEmail ? null : _lierEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoadingEmail
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('Enregistrer',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}