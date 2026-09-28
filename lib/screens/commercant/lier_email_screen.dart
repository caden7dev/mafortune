import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class LierEmailScreen extends StatefulWidget {
  const LierEmailScreen({super.key});

  @override
  State<LierEmailScreen> createState() => _LierEmailScreenState();
}

class _LierEmailScreenState extends State<LierEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email requis';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Format d\'email invalide';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Mot de passe requis';
    if (value.length < 6) return 'Minimum 6 caractères';
    return null;
  }

  Future<void> _syncFirestore(User user, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({
      ...data,
      'derniereSynchronisation': FieldValue.serverTimestamp(),
    });
  }

  // ✅ LIAISON EMAIL + MOT DE PASSE
  Future<void> _lierEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final emailSaisi = _emailController.text.trim();

      // Vérifie si un provider "password" est déjà lié (cas où Auth a réussi
      // mais la synchro Firestore avait échoué avant la correction des règles)
      final alreadyLinked = user.providerData.any((p) => p.providerId == 'password');

      if (!alreadyLinked) {
        final credential = EmailAuthProvider.credential(
          email: emailSaisi,
          password: _passwordController.text,
        );
        await user.linkWithCredential(credential);
      }

      await _syncFirestore(user, {
        'email': emailSaisi,
        'emailSecours': emailSaisi,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Email lié avec succès'), backgroundColor: emeraldDark),
        );
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('❌ Code erreur Firebase (liaison Email): ${e.code} - ${e.message}');

      // ✅ Déjà lié côté Auth : on synchronise quand même Firestore au lieu d'échouer
      if (e.code == 'provider-already-linked') {
        try {
          final user = FirebaseAuth.instance.currentUser!;
          await _syncFirestore(user, {
            'email': _emailController.text.trim(),
            'emailSecours': _emailController.text.trim(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Email synchronisé avec succès'), backgroundColor: emeraldDark),
            );
            Navigator.pop(context, true);
          }
          return;
        } catch (_) {
          // tombe dans le message d'erreur générique ci-dessous
        }
      }

      String message = 'Erreur inconnue (${e.code})';
      if (e.code == 'email-already-in-use') message = 'Cet email est déjà utilisé par un autre compte';
      else if (e.code == 'invalid-email') message = 'Format d\'email invalide';
      else if (e.code == 'weak-password') message = 'Mot de passe trop faible (min. 6 caractères)';
      else if (e.code == 'credential-already-in-use') message = 'Cet email est déjà lié à ce compte';
      else if (e.code == 'requires-recent-login') message = 'Veuillez vous déconnecter et vous reconnecter pour effectuer cette action';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: brickRed));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: brickRed));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ LIAISON AVEC GOOGLE
  Future<void> _lierGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // ✅ Vérifie si Google est déjà lié côté Auth (cas d'un essai précédent
      // où la synchro Firestore avait échoué à cause des règles de sécurité)
      final googleProviderExistant = user.providerData
          .where((p) => p.providerId == 'google.com')
          .cast<UserInfo?>()
          .firstWhere((_) => true, orElse: () => null);

      String? googleEmail;
      String? googleDisplayName;
      String? googlePhotoUrl;

      if (googleProviderExistant != null) {
        // Déjà lié : pas besoin de repasser par Google Sign-In, on récupère
        // les infos directement depuis Firebase Auth et on synchronise Firestore
        googleEmail = googleProviderExistant.email ?? user.email;
        googleDisplayName = googleProviderExistant.displayName;
        googlePhotoUrl = googleProviderExistant.photoURL;
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut(); // force le sélecteur de compte

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _isGoogleLoading = false);
          return; // annulé par l'utilisateur
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.linkWithCredential(credential);

        googleEmail = googleUser.email;
        googleDisplayName = googleUser.displayName;
        googlePhotoUrl = googleUser.photoUrl;
      }

      // ✅ Synchronise Firestore dans tous les cas (nouvelle liaison ou déjà liée)
      await _syncFirestore(user, {
        'email': googleEmail,
        'googleLie': true,
        'googleEmail': googleEmail,
        'googleDisplayName': googleDisplayName,
        'googlePhotoUrl': googlePhotoUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Compte Google lié avec succès'), backgroundColor: emeraldDark),
        );
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('❌ Code erreur Firebase (liaison Google): ${e.code} - ${e.message}');
      String message = 'Erreur de liaison Firebase : ${e.code}';
      if (e.code == 'credential-already-in-use') message = 'Ce compte Google est déjà lié à un autre compte';
      else if (e.code == 'email-already-in-use') message = 'Cet email Google est déjà utilisé par un autre compte MaFortune. Utilisez un autre compte Google.';
      else if (e.code == 'requires-recent-login') message = 'Veuillez vous reconnecter pour effectuer cette action';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: brickRed));
    } catch (e) {
      if (!mounted) return;
      String message = 'Erreur de connexion Google : $e';
      if (e.toString().contains('sign_in_failed') || e.toString().contains('10')) {
        message = 'Erreur Google : Vérifiez que l\'empreinte SHA-1 est bien configurée dans Firebase Console.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: brickRed));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lier un compte', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.security_rounded, size: 48, color: emeraldDark),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Sécurisez votre compte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'En liant un email ou un compte Google, vous pourrez vous connecter avec ces méthodes et récupérer votre compte.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ✅ BOUTON GOOGLE AVEC LE VRAI LOGO
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isGoogleLoading ? null : _lierGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: textDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey[300]!),
                    elevation: 0,
                  ),
                  icon: _isGoogleLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: emeraldDark))
                      : Image.asset(
                          'assets/image/googleLogo.jpeg',
                          height: 24,
                          width: 24,
                          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 28, color: Color(0xFF4285F4)),
                        ),
                  label: const Text('Continuer avec Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OU', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500]))),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Adresse e-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: emeraldDark, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: emeraldDark, width: 2)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _lierEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: emeraldDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Lier mon email', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: emeraldDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: emeraldDark.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: emeraldDark, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vous pourrez vous connecter avec votre email OU votre compte Google après la liaison.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}