import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE
const Color emeraldGreen = Color(0xFF0B4F36);
const Color textDark = Color(0xFF222222);
const Color textMedium = Color(0xFF555555);

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  bool _isLoading = false;
  bool _isFetchingUserData = true;
  String? _errorMessage;

  String? _telephone;
  String? _verificationId; // Stocke l'ID de vérification de Firebase

  @override
  void initState() {
    super.initState();
    _chargerInfosSecurite();
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
            _telephone = data?['telephone'] as String?;
          });
        }
      } catch (e, stackTrace) {
        FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Erreur chargement infos');
      }
    }
    if (mounted) setState(() => _isFetchingUserData = false);
  }

  // ─── 1. ENVOYER LE CODE SMS VIA FIREBASE ────────────────────────────────
  Future<void> _sendSmsCode() async {
    if (_telephone == null || _telephone!.isEmpty) {
      setState(() => _errorMessage = 'Aucun numéro de téléphone enregistré.');
      return;
    }

    // Formater le numéro pour Firebase (doit commencer par + et l'indicatif pays, ex: +22890...)
    // Si ton numéro est stocké sans le +228, ajoute-le ici :
    final formattedPhone = _telephone!.startsWith('+') ? _telephone! : '+228$_telephone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Vérification automatique (parfois sur Android)
        await _verifyAndReset(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.code == 'invalid-phone-number' 
              ? 'Numéro de téléphone invalide.' 
              : 'Échec de l\'envoi du SMS. Vérifiez votre connexion.';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _isLoading = false;
          _verificationId = verificationId;
        });
        // Ouvrir la boîte de dialogue pour saisir le code
        _showOtpDialog();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() => _verificationId = verificationId);
      },
    );
  }

  // ─── 2. VÉRIFIER LE CODE ET RÉINITIALISER LE PIN ────────────────────────
  Future<void> _verifyAndReset(PhoneAuthCredential credential) async {
    setState(() => _isLoading = true);
    try {
      // Connecter l'utilisateur avec le code OTP
      await FirebaseAuth.instance.signInWithCredential(credential);
      
      // TODO: Ici, tu appelles ton service pour effacer l'ancien PIN
      // await LocalAuthService().clearPin();
      
      if (!mounted) return;
      
      // Rediriger vers l'écran de création d'un nouveau PIN
      Navigator.pushReplacementNamed(context, '/pin_setup');
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.code == 'invalid-verification-code' 
            ? 'Le code saisi est incorrect.' 
            : 'Erreur de vérification.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Une erreur inattendue est survenue.';
      });
    }
  }

  // ─── 3. BOÎTE DE DIALOGUE POUR SAISIR LE CODE OTP ───────────────────────
  void _showOtpDialog() {
    final otpController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Code de vérification', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Un code à 6 chiffres a été envoyé au\n$_telephone',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMedium, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              maxLength: 6,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '000000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _verificationId = null);
            },
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (otpController.text.length == 6 && _verificationId != null) {
                Navigator.pop(context); // Fermer le dialog
                final credential = PhoneAuthProvider.credential(
                  verificationId: _verificationId!,
                  smsCode: otpController.text,
                );
                _verifyAndReset(credential);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: emeraldGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Vérifier'),
          ),
        ],
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 8) return phone;
    return '${phone.substring(0, 4)}****${phone.substring(phone.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: emeraldGreen, size: 26),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Code PIN oublié',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: _isFetchingUserData
            ? const Center(child: CircularProgressIndicator(color: emeraldGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _buildRequestView(),
              ),
      ),
    );
  }

  Widget _buildRequestView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: emeraldGreen.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Icon(Icons.sms_outlined, size: 56, color: emeraldGreen)),
        ),
        const SizedBox(height: 28),
        const Text(
          'Réinitialiser votre\ncode PIN',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark, height: 1.3),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Nous allons vous envoyer un code de vérification par SMS gratuitement via notre système sécurisé.',
          style: TextStyle(fontSize: 15, color: textMedium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

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
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14))),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (_telephone != null && _telephone!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: emeraldGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: emeraldGreen.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_android, color: emeraldGreen, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Numéro enregistré',
                      style: TextStyle(fontSize: 14, color: textMedium, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _maskPhone(_telephone!),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendSmsCode,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.sms_outlined, size: 24),
              label: Text(
                _isLoading ? 'Envoi en cours...' : 'Recevoir le code par SMS',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: emeraldGreen.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Aucun numéro de téléphone n\'est associé à ce compte. Veuillez contacter le support.',
              style: TextStyle(color: Colors.orange, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(fontSize: 16, color: textMedium, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}