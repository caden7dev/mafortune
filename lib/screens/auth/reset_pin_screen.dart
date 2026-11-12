import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../services/notification_service.dart';

const Color emeraldGreen = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
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
  bool _showOtpField = false;
  String? _errorMessage;
  String? _telephone;
  String? _generatedCode;

  // ✅ NOUVEAU : Gestion réaliste (expiration + tentatives)
  int _remainingSeconds = 300; // 5 minutes
  Timer? _expiryTimer;
  int _attempts = 0;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    _chargerInfosSecurite();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _remainingSeconds = 300;
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _errorMessage = 'Le code a expiré. Veuillez en demander un nouveau.';
            _showOtpField = false;
            _generatedCode = null;
          });
        }
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
          setState(() => _telephone = data?['telephone'] as String?);
        }
      } catch (e, stackTrace) {
        FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Erreur chargement infos');
      }
    }
    if (mounted) setState(() => _isFetchingUserData = false);
  }

  // ✅ ENVOI DU CODE : avec vibration de type notification SMS
  Future<void> _sendCode({bool isResend = false}) async {
    if (_telephone == null || _telephone!.isEmpty) {
      setState(() => _errorMessage = 'Aucun numéro de téléphone enregistré.');
      return;
    }

    if (_attempts >= _maxAttempts && !isResend) {
      setState(() => _errorMessage = 'Trop de tentatives échouées. Attendez quelques minutes.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Génère un NOUVEAU code à chaque appel (utile pour "Renvoyer")
    _generatedCode = (100000 + Random().nextInt(900000)).toString();

    // Simule le délai réseau d'un vrai SMS (1.5 à 2.5 secondes)
    final delayMs = isResend ? 1000 : Random().nextInt(1000) + 1500;
    await Future.delayed(Duration(milliseconds: delayMs));

    if (!mounted) return;

    // Déclenche la vraie notification système avec le logo MaFortune
    await NotificationService.showSmsNotification(_generatedCode!);

    // ✅ Vibration typique d'une notification reçue (plus réaliste)
    HapticFeedback.vibrate();

    // Petit message de confirmation en haut
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isResend
                    ? 'Nouveau code envoyé au ${_maskPhone(_telephone!)}'
                    : 'Code envoyé au ${_maskPhone(_telephone!)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: emeraldGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    setState(() {
      _isLoading = false;
      _showOtpField = true;
    });

    _startExpiryTimer();
  }

  // ✅ VÉRIFICATION DU CODE avec compteur de tentatives
  Future<void> _verifyAndReset(String enteredCode) async {
    if (_generatedCode == null) return;
    if (_attempts >= _maxAttempts) {
      setState(() {
        _errorMessage = 'Vous avez atteint le nombre maximum de tentatives.';
        _showOtpField = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    if (enteredCode == _generatedCode) {
      _expiryTimer?.cancel();

      // ✅ Réinitialise le PIN dans Firestore AVANT de rediriger
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(user.uid)
              .update({'codePin': FieldValue.delete()});
        }
      } catch (e) {
        debugPrint('Erreur suppression PIN: $e');
      }

      Navigator.pushReplacementNamed(context, '/pin_setup');
    } else {
      setState(() {
        _isLoading = false;
        _attempts++;
        final remaining = _maxAttempts - _attempts;
        _errorMessage = remaining > 0
            ? 'Code incorrect. $remaining tentative${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''}.'
            : 'Vous avez atteint le nombre maximum de tentatives.';
      });
      HapticFeedback.heavyImpact();
      if (_attempts >= _maxAttempts) {
        setState(() => _showOtpField = false);
        _expiryTimer?.cancel();
      }
    }
  }

  String _maskPhone(String phone) {
    if (phone.isEmpty) return phone;
    final cleanPhone = phone.replaceAll('+228', '').replaceAll(RegExp(r'[^\d]'), '').trim();
    if (cleanPhone.length >= 8) {
      return '+228 ${cleanPhone.substring(0, 2)} **** ${cleanPhone.substring(6)}';
    }
    return phone;
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
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        // Icône principale avec petite animation de "cloche" si notification envoyée
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 1, end: 1.1),
          duration: _showOtpField ? const Duration(milliseconds: 400) : Duration.zero,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: emeraldGreen.withOpacity(0.12),
              shape: BoxShape.circle,
              boxShadow: _showOtpField
                  ? [BoxShadow(color: emeraldGreen.withOpacity(0.2), blurRadius: 20, spreadRadius: 4)]
                  : [],
            ),
            child: const Center(child: Icon(Icons.sms_outlined, size: 56, color: emeraldGreen)),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Réinitialiser votre\ncode PIN',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark, height: 1.3),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Nous allons vous envoyer un code de vérification par SMS pour sécuriser votre compte.',
          style: TextStyle(fontSize: 15, color: textMedium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        if (_errorMessage != null) ...[
          Container(
            width: double.infinity,
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
                    Text('Numéro enregistré', style: TextStyle(fontSize: 14, color: textMedium, fontWeight: FontWeight.w500)),
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

          // Bouton principal d'envoi
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _showOtpField || _attempts >= _maxAttempts ? null : () => _sendCode(),
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

          // ✅ Zone OTP : timer + champ + renvoi fonctionnel
          if (_showOtpField) ...[
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Affichage du timer d'expiration
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saisissez le code reçu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _remainingSeconds < 60 ? brickRed.withOpacity(0.1) : terracotta.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_rounded, size: 14, color: _remainingSeconds < 60 ? brickRed : terracotta),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimer(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _remainingSeconds < 60 ? brickRed : terracotta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              enabled: !_isLoading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4, color: emeraldGreen),
              maxLength: 6,
              onChanged: (value) {
                if (value.length == 6 && !_isLoading) {
                  _verifyAndReset(value);
                }
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 24, letterSpacing: 4),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: emeraldGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ VRAI bouton "Renvoyer" qui génère un nouveau code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Vous n\'avez pas reçu le code ?',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _isLoading ? null : () => _sendCode(isResend: true),
                  child: const Text(
                    'Renvoyer',
                    style: TextStyle(color: emeraldGreen, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Aucun numéro de téléphone n\'est associé à ce compte. Veuillez contacter le support.',
              style: TextStyle(color: Colors.orange, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(fontSize: 16, color: textMedium, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}