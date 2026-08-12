import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import '../models/utilisateur_model.dart';
import 'local_auth_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthService _localAuth = LocalAuthService();
  
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── CACHE PROFIL ─────────────────────────────────────────────────────────
  UtilisateurModel? _cachedUser;
  String? _cachedUserId;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        invalidateUserCache();
      }
    });
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<bool> isLocalPinSet() async => await _localAuth.hasPin();
  Future<void> clearLocalPin() async => await _localAuth.clearPin();

  void invalidateUserCache() {
    _cachedUser = null;
    _cachedUserId = null;
  }

  // ─── INSCRIPTION AVEC NUMÉRO DE TÉLÉPHONE ──────────────────────────────
  Future<UtilisateurModel?> signUpWithPhone({
    required String telephone,
    required String nom,
    required String prenom,
    required String typeActivite,
    String? adresse,
  }) async {
    try {
      final fakeEmail = '${telephone.replaceAll(' ', '').replaceAll('+', '')}@temp.mafortune.com';
      final tempPassword = 'Temp@${DateTime.now().millisecondsSinceEpoch}';

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: tempPassword,
      );

      final utilisateur = UtilisateurModel(
        id: userCredential.user!.uid,
        nom: nom,
        prenom: prenom,
        email: fakeEmail,
        telephone: telephone,
        typeUtilisateur: TypeUtilisateur.commercant,
        estActif: true,
        dateCreation: DateTime.now(),
        typeActivite: typeActivite,
        adresse: adresse,
        soldeActuel: 0.0,
        emailSecours: '',
        googleLie: false,
      );

      await _firestore
          .collection('utilisateurs')
          .doc(userCredential.user!.uid)
          .set(utilisateur.toFirestore());

      _cachedUser = utilisateur;
      _cachedUserId = utilisateur.id;

      return utilisateur;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de l\'inscription : $e';
    }
  }

  // ─── CONNEXION AVEC NUMÉRO DE TÉLÉPHONE ────────────────────────────────
  Future<UtilisateurModel?> signInWithPhone(String telephone) async {
    try {
      final query = await _firestore
          .collection('utilisateurs')
          .where('telephone', isEqualTo: telephone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw 'Aucun compte trouvé avec ce numéro';
      }

      final userId = query.docs.first.id;
      
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(userId)
          .get();

      if (!doc.exists) {
        throw 'Utilisateur introuvable';
      }

      final utilisateur = UtilisateurModel.fromFirestore(doc);

      if (!utilisateur.estActif) {
        throw 'Votre compte a été désactivé.';
      }

      _cachedUser = utilisateur;
      _cachedUserId = utilisateur.id;

      await _firestore
          .collection('utilisateurs')
          .doc(utilisateur.id)
          .update({
            'derniereConnexion': FieldValue.serverTimestamp(),
          });

      return utilisateur;
    } catch (e) {
      throw 'Erreur lors de la connexion : $e';
    }
  }

  // ─── 1. LIER GOOGLE A UN COMPTE EXISTANT ──────────────────────────────────
  Future<void> lierCompteGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Vous devez être connecté pour lier un compte Google.';
    }

    try {
      // 1. 📱 Connexion avec Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Connexion Google annulée.';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // 2. 📧 Mettre à jour l'email de l'utilisateur Firebase
      try {
        await user.updateEmail(googleUser.email);
        debugPrint('✅ Email mis à jour: ${user.email}');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw 'Pour des raisons de sécurité, reconnecte-toi avant de lier Google.';
        } else if (e.code == 'email-already-in-use') {
          debugPrint('⚠️ Email déjà utilisé, liaison sans changement');
        } else {
          debugPrint('⚠️ Erreur mise à jour email: ${e.code}');
        }
      }

      // 3. 🔗 Lier le compte Google
      try {
        await user.linkWithCredential(credential);
        debugPrint('✅ Compte Google lié avec succès');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
          throw 'Ce compte est déjà lié à un compte Google.';
        } else if (e.code == 'credential-already-in-use') {
          throw 'Ce compte Google est déjà lié à un autre utilisateur.';
        } else {
          rethrow;
        }
      }

      // 4. 💾 Mettre à jour Firestore
      final updates = {
        'googleLie': true,
        'emailSecours': googleUser.email,
        'email': googleUser.email,
        'googleEmail': googleUser.email,
        'googleDisplayName': googleUser.displayName,
        'googlePhotoUrl': googleUser.photoUrl,
        'derniereSynchronisation': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('utilisateurs').doc(user.uid).update(updates);

      // 5. 🔄 Mettre à jour le cache
      _cachedUser = await getCurrentUserData(forceRefresh: true);

      debugPrint('✅ Compte Google lié avec succès ! Email: ${googleUser.email}');

    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException Google: ${e.code} - ${e.message}');
      if (e.code == 'sign_in_failed' || e.code == 'SIGN_IN_FAILED') {
        throw 'Connexion Google échouée.\n'
            'Assure-toi d\'avoir une connexion internet stable.\n'
            'Si le problème persiste, utilise l\'option "Ajouter un email".';
      } else if (e.code == 'NETWORK_ERROR') {
        throw 'Problème de réseau. Vérifie ta connexion internet.';
      } else {
        throw 'Erreur Google: ${e.message ?? 'Inconnue'}';
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'credential-already-in-use') {
        throw 'Ce compte Google est déjà lié à un autre utilisateur.';
      } else if (e.code == 'provider-already-linked') {
        throw 'Ce compte est déjà lié à un compte Google.';
      } else if (e.code == 'requires-recent-login') {
        throw 'Reconnecte-toi avant de lier Google.';
      } else {
        throw 'Erreur: ${e.message}';
      }
    } catch (e) {
      debugPrint('❌ Erreur inattendue: $e');
      rethrow;
    }
  }

  // ─── 2. CONNEXION AVEC GOOGLE ─────────────────────────────────────────────
  Future<UtilisateurModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) return null;

      final docRef = _firestore.collection('utilisateurs').doc(user.uid);
      final doc = await docRef.get();

      UtilisateurModel utilisateur;

      if (doc.exists) {
        await docRef.update({
          'googleLie': true,
          'emailSecours': googleUser.email,
          'email': googleUser.email,
          'googleEmail': googleUser.email,
          'googleDisplayName': googleUser.displayName,
          'googlePhotoUrl': googleUser.photoUrl,
          'derniereConnexion': FieldValue.serverTimestamp(),
          'derniereSynchronisation': FieldValue.serverTimestamp(),
        });
        final updatedDoc = await docRef.get();
        utilisateur = UtilisateurModel.fromFirestore(updatedDoc);
      } else {
        final nomComplet = googleUser.displayName ?? '';
        final parts = nomComplet.split(' ');
        final prenom = parts.isNotEmpty ? parts[0] : 'Utilisateur';
        final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        utilisateur = UtilisateurModel(
          id: user.uid,
          nom: nom,
          prenom: prenom,
          email: googleUser.email,
          telephone: user.phoneNumber ?? '',
          typeUtilisateur: TypeUtilisateur.commercant,
          estActif: true,
          dateCreation: DateTime.now(),
          soldeActuel: 0.0,
          photo: googleUser.photoUrl,
          emailSecours: googleUser.email,
          googleLie: true,
        );

        await docRef.set(utilisateur.toFirestore());
        await docRef.update({
          'googleEmail': googleUser.email,
          'googleDisplayName': googleUser.displayName,
          'googlePhotoUrl': googleUser.photoUrl,
        });
      }

      _cachedUser = utilisateur;
      _cachedUserId = utilisateur.id;

      return utilisateur;
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException: ${e.code}');
      throw 'Connexion Google échouée. Vérifie ta connexion internet.';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de la connexion Google : $e';
    }
  }

  // ─── ENREGISTRER EMAIL DE SECOURS ────────────────────────────────────────
  Future<void> enregistrerEmailSecours(String email) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Vous devez être connecté.';
    }

    if (email.isNotEmpty) {
      final existingUsers = await _firestore
          .collection('utilisateurs')
          .where('emailSecours', isEqualTo: email)
          .get();

      if (existingUsers.docs.isNotEmpty && 
          existingUsers.docs.first.id != user.uid) {
        throw 'Cet email est déjà utilisé par un autre compte.';
      }
      
      try {
        await user.updateEmail(email);
      } catch (e) {
        debugPrint('⚠️ Impossible de mettre à jour l\'email Firebase: $e');
      }
    }

    final updates = <String, dynamic>{
      'emailSecours': email,
      'derniereSynchronisation': FieldValue.serverTimestamp(),
    };

    if (email.isNotEmpty) {
      updates['aEmailSecours'] = true;
      updates['dateEmailSecours'] = FieldValue.serverTimestamp();
      updates['email'] = email;
    } else {
      updates['aEmailSecours'] = false;
      updates['dateEmailSecours'] = null;
    }

    await _firestore
        .collection('utilisateurs')
        .doc(user.uid)
        .update(updates);

    _cachedUser = await getCurrentUserData(forceRefresh: true);
  }

  // ─── RÉCUPÉRATION DE COMPTE VIA EMAIL DE SECOURS ────────────────────────
  Future<void> recupererCompteViaEmail(String email) async {
    try {
      final query = await _firestore
          .collection('utilisateurs')
          .where('emailSecours', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw 'Aucun compte associé à cet email.';
      }

      await _auth.sendPasswordResetEmail(email: email);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'Aucun compte Firebase trouvé pour cet email.';
      } else if (e.code == 'too-many-requests') {
        throw 'Trop de tentatives. Attendez quelques minutes.';
      } else {
        throw 'Erreur: ${e.message}';
      }
    } catch (e) {
      throw 'Erreur lors de la récupération : $e';
    }
  }

  // ─── INSCRIPTION AVEC EMAIL/MOT DE PASSE ─────────────────────────────────
  Future<UtilisateurModel?> signUpCommercant({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String telephone,
    required String typeActivite,
    String? adresse,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final utilisateur = UtilisateurModel(
        id: userCredential.user!.uid,
        nom: nom,
        prenom: prenom,
        email: email,
        telephone: telephone,
        typeUtilisateur: TypeUtilisateur.commercant,
        estActif: true,
        dateCreation: DateTime.now(),
        typeActivite: typeActivite,
        adresse: adresse,
        soldeActuel: 0.0,
        emailSecours: email,
        googleLie: false,
      );

      await _firestore
          .collection('utilisateurs')
          .doc(userCredential.user!.uid)
          .set(utilisateur.toFirestore());

      _cachedUser = utilisateur;
      _cachedUserId = utilisateur.id;

      return utilisateur;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de l\'inscription : $e';
    }
  }

  // ─── CONNEXION AVEC EMAIL/MOT DE PASSE ──────────────────────────────────
  Future<UtilisateurModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(userCredential.user!.uid)
          .get();

      if (!doc.exists) {
        await signOut();
        throw 'Utilisateur introuvable dans la base de données';
      }

      final utilisateur = UtilisateurModel.fromFirestore(doc);

      if (!utilisateur.estActif) {
        await signOut();
        throw 'Votre compte a été désactivé. Contactez l\'administrateur.';
      }

      _cachedUser = utilisateur;
      _cachedUserId = utilisateur.id;

      _firestore
          .collection('utilisateurs')
          .doc(utilisateur.id)
          .update({'derniereSynchronisation': FieldValue.serverTimestamp()})
          .catchError((e) => debugPrint("Erreur de mise à jour de la synchro : $e"));

      return utilisateur;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de la connexion : $e';
    }
  }

  // ─── DÉCONNEXION ──────────────────────────────────────────────────────────
  Future<void> signOut() async {
    invalidateUserCache();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // ─── GET PROFIL ───────────────────────────────────────────────────────────
  Future<UtilisateurModel?> getCurrentUserData({
    bool forceRefresh = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      if (!forceRefresh &&
          _cachedUser != null &&
          _cachedUserId == user.uid) {
        return _cachedUser;
      }

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      final utilisateur = UtilisateurModel.fromFirestore(doc);

      _cachedUser = utilisateur;
      _cachedUserId = user.uid;

      return utilisateur;
    } catch (e) {
      if (_cachedUser != null) return _cachedUser;
      return null;
    }
  }

  // ─── UPDATE PROFIL ────────────────────────────────────────────────────────
  Future<UtilisateurModel> updateUserProfile(UtilisateurModel user) async {
    try {
      final Map<String, dynamic> updates = {
        'nom': user.nom,
        'prenom': user.prenom,
        'telephone': user.telephone,
        'photo': user.photo,
        'derniereSynchronisation': FieldValue.serverTimestamp(),
      };

      if (user.estCommercant) {
        updates['typeActivite'] = user.typeActivite;
        updates['adresse'] = user.adresse;
      }

      if (user.email.isNotEmpty && user.email != _auth.currentUser?.email) {
        try {
          await _auth.currentUser?.updateEmail(user.email);
        } catch (e) {
          debugPrint('⚠️ Impossible de mettre à jour l\'email Firebase: $e');
        }
        updates['email'] = user.email;
      }

      await _firestore
          .collection('utilisateurs')
          .doc(user.id)
          .update(updates);

      return await getCurrentUserData(forceRefresh: true) ?? user;
    } catch (e) {
      throw 'Erreur lors de la mise à jour du profil : $e';
    }
  }

  // ─── RESET MOT DE PASSE ───────────────────────────────────────────────────
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ─── CHANGER MOT DE PASSE ─────────────────────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Utilisateur non connecté';
      if (user.email == null) throw 'Email utilisateur introuvable';

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      if (newPassword.length < 6) {
        throw 'Le nouveau mot de passe doit contenir au moins 6 caractères';
      }

      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ─── GESTION ERREURS ──────────────────────────────────────────────────────
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'invalid-email':
        return 'Email invalide';
      case 'weak-password':
        return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      case 'network-request-failed':
        return 'Problème de connexion internet. Vérifiez votre réseau';
      case 'credential-already-in-use':
        return 'Ce compte Google est déjà lié à un autre utilisateur';
      case 'provider-already-linked':
        return 'Ce compte est déjà lié à un compte Google';
      default:
        return 'Erreur d\'authentification : ${e.message}';
    }
  }
}