import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/local_auth_service.dart';
import '../../services/auth_service.dart';

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final LocalAuthService _localAuth = LocalAuthService();

  bool _isLoading = false;
  bool _isFetchingUserData = true;
  bool _emailSent = false;
  String? _errorMessage;

  bool _googleLie = false;
  String? _emailSecours;
  String? _telephone;

  String get _userEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _chargerInfosSecurite();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _chargerInfosSecurite() async {
    setState(() => _isFetchingUserData = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _googleLie = data?['googleLie'] as bool? ?? false;
            _emailSecours = data?['emailSecours'] as String?;
            _telephone = data?['telephone'] as String?;
          });
        }
      } catch (e, stackTrace) {
        FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Erreur chargement infos sécurité reset PIN',
          fatal: false,
        );
        debugPrint('❌ Erreur chargement infos: $e');
      }
    }
    if (mounted) {
      setState(() => _isFetchingUserData = false);
    }
  }

  // ─── 1. RÉCUPÉRATION VIA EMAIL DE SECOURS ────────────────────────────────
  Future<void> _resetPinViaEmail() async {
    final emailCible = (_emailSecours != null && _emailSecours!.isNotEmpty)
        ? _emailSecours!
        : _userEmail;

    if (emailCible.isEmpty) {
      setState(() {
        _errorMessage = 'Aucun email disponible. Utilisez une autre méthode.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCible);
      await _localAuth.clearPin();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } on FirebaseAuthException catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Erreur Firebase reset PIN : ${e.code}',
        fatal: false,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      switch (e.code) {
        case 'user-not-found':
          _errorMessage = 'Aucun compte trouvé pour cet email.';
          break;
        case 'too-many-requests':
          _errorMessage = 'Trop de tentatives. Attendez quelques minutes.';
          break;
        default:
          _errorMessage = 'Erreur. Vérifiez votre email et réessaiez.';
      }
      setState(() {});
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Erreur reset PIN standard',
        fatal: false,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Vérifiez votre connexion internet et réessayez.';
      });
    }
  }

  // ─── 2. RÉCUPÉRATION VIA GOOGLE ───────────────────────────────────────────
  Future<void> _resetPinViaGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithGoogle();

      if (user != null) {
        await _localAuth.clearPin();
        if (!mounted) return;
        
        // Rediriger vers la création d'un nouveau PIN
        Navigator.pushReplacementNamed(context, '/pin_setup');
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Connexion Google annulée.';
          });
        }
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Erreur reset PIN via Google',
        fatal: false,
      );
      debugPrint('❌ Erreur connexion Google: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Échec de la connexion Google. Vérifie ta connexion.';
        });
      }
    }
  }

  // ─── 3. RÉCUPÉRATION VIA NUMÉRO (FALLBACK) ──────────────────────────────
  Future<void> _resetPinViaNumero() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Afficher une boîte de dialogue d'information
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Text('📱', style: TextStyle(fontSize: 28)),
              SizedBox(width: 10),
              Text(
                'Réinitialisation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pour réinitialiser ton code PIN :',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              _buildStepNumber(
                '1',
                'Contacte le support MaFortune',
                'support@mafortune.com',
              ),
              const SizedBox(height: 12),
              _buildStepNumber(
                '2',
                'Confirme ton numéro',
                _telephone?.isNotEmpty == true ? _telephone! : 'ton numéro',
              ),
              const SizedBox(height: 12),
              _buildStepNumber(
                '3',
                'Reçois un lien de réinitialisation',
                'par SMS ou email',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Compris'),
            ),
          ],
        ),
      );

      setState(() => _isLoading = false);

      if (confirm == true) {
        // Déconnecter l'utilisateur
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur reset via numéro: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur. Réessaie.';
        });
      }
    }
  }

  // ─── RETOUR À LA CONNEXION ─────────────────────────────────────────────────
  Future<void> _goToLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint('❌ Erreur déconnexion: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors de la déconnexion.';
        });
      }
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────
  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '***@$domain';
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  Widget _buildStepNumber(String number, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.primaryGreen,
            size: 26,
          ),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          '🔑 Code PIN oublié',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: _isFetchingUserData
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _emailSent ? _buildSuccessView() : _buildRequestView(),
              ),
      ),
    );
  }

  // ─── VUE PRINCIPALE ────────────────────────────────────────────────────────
  Widget _buildRequestView() {
    final emailAffiche = (_emailSecours != null && _emailSecours!.isNotEmpty)
        ? _emailSecours!
        : _userEmail;

    final hasEmail = emailAffiche.isNotEmpty;
    final hasGoogle = _googleLie;

    return Column(
      children: [
        const SizedBox(height: 16),

        // Icône
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🔒', style: TextStyle(fontSize: 56)),
          ),
        ),

        const SizedBox(height: 28),

        // Titre
        const Text(
          'Vous avez oublié\nvotre code PIN ?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Text(
          'Choisissez une méthode ci-dessous',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Message d'erreur
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ─── OPTION 1: EMAIL DE SECOURS ──────────────────────────────────
        if (hasEmail) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📧', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text(
                      _emailSecours != null
                          ? 'Email de secours'
                          : 'Ton email',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _maskEmail(emailAffiche),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _resetPinViaEmail,
              icon: const Icon(Icons.email_outlined, size: 24),
              label: const Text(
                'Envoyer le lien par email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primaryGreen.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ─── OPTION 2: GOOGLE ────────────────────────────────────────────
        if (hasGoogle) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _resetPinViaGoogle,
              icon: _buildGoogleIcon(),
              label: const Text(
                'Reconnexion avec Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ─── OPTION 3: NUMÉRO DE TÉLÉPHONE ──────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _resetPinViaNumero,
            icon: const Icon(Icons.phone_android, size: 24),
            label: const Text(
              'Contacter le support',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── RETOUR ──────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: Text(
              'Retour',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── VUE SUCCÈS ────────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    final emailAffiche = (_emailSecours != null && _emailSecours!.isNotEmpty)
        ? _emailSecours!
        : _userEmail;

    return Column(
      children: [
        const SizedBox(height: 20),

        // Icône succès
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('✅', style: TextStyle(fontSize: 60)),
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'Email envoyé !',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 10),

        Text(
          _maskEmail(emailAffiche),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        // Étapes
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Que faire maintenant ?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildStep('📧', '1', 'Ouvrez votre boîte email'),
              _buildStep('🔗', '2', 'Cliquez sur le lien reçu'),
              _buildStep('🔐', '3', 'Créez un nouveau mot de passe'),
              _buildStep('📲', '4', 'Revenez dans l\'application'),
              _buildStep('🔢', '5', 'Créez un nouveau code PIN'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Astuce SPAM
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vous ne trouvez pas l\'email ?\nVérifiez votre dossier SPAM.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // Bouton connexion
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _goToLogin,
            icon: const Icon(Icons.login_outlined, size: 24),
            label: const Text(
              'Aller à la connexion',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.primaryGreen.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  // ─── WIDGETS AIDE ──────────────────────────────────────────────────────────
  Widget _buildStep(String emoji, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}