import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/utilisateur_model.dart';
import 'local_auth_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthService _localAuth = LocalAuthService();

  // ─── CACHE PROFIL ─────────────────────────────────────────────────────────
  // Évite de rappeler Firestore à chaque écran pour le même utilisateur
  UtilisateurModel? _cachedUser;
  String? _cachedUserId;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<bool> isLocalPinSet() async => await _localAuth.hasPin();
  Future<void> clearLocalPin() async => await _localAuth.clearPin();

  /// Invalide le cache — à appeler après updateUserProfile
  void invalidateUserCache() {
    _cachedUser = null;
    _cachedUserId = null;
  }

  // ─── INSCRIPTION ──────────────────────────────────────────────────────────
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
      );

      await _firestore
          .collection('utilisateurs')
          .doc(userCredential.user!.uid)
          .set(utilisateur.toFirestore());

      // Met en cache dès l'inscription
      _cachedUser = utilisateur;
      _cachedUserId = utilisateur.id;

      return utilisateur;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de l\'inscription: $e';
    }
  }

  // ─── CONNEXION ────────────────────────────────────────────────────────────
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

      // Met en cache le profil dès la connexion
      _cachedUser = utilisateur;
      _cachedUserId = utilisateur.id;

      // Mise à jour dernière sync — fire and forget (pas d'await)
      _firestore
          .collection('utilisateurs')
          .doc(utilisateur.id)
          .update({'derniereSynchronisation': FieldValue.serverTimestamp()});

      return utilisateur;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de la connexion: $e';
    }
  }

  // ─── DÉCONNEXION ──────────────────────────────────────────────────────────
  Future<void> signOut() async {
    invalidateUserCache(); // Vide le cache au logout
    await _auth.signOut();
  }

  // ─── GET PROFIL — avec cache ──────────────────────────────────────────────
  // ✅ OPTIMISATION : retourne le cache si le même utilisateur est déjà chargé
  // Au lieu de faire un appel Firestore à chaque écran (profil, dashboard, etc.)
  Future<UtilisateurModel?> getCurrentUserData({
    bool forceRefresh = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Retourne le cache si valide et pas de forceRefresh
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

      // Met à jour le cache
      _cachedUser = utilisateur;
      _cachedUserId = user.uid;

      return utilisateur;
    } catch (e) {
      // Si Firestore échoue, retourne le cache même expiré
      if (_cachedUser != null) return _cachedUser;
      return null;
    }
  }

  // ─── UPDATE PROFIL ────────────────────────────────────────────────────────
  Future<UtilisateurModel> updateUserProfile(UtilisateurModel user) async {
    try {
      await _firestore
          .collection('utilisateurs')
          .doc(user.id)
          .update(user.toFirestore());

      // Met à jour le cache avec les nouvelles données
      _cachedUser = user;
      _cachedUserId = user.id;

      return user;
    } catch (e) {
      throw 'Erreur lors de la mise à jour du profil: $e';
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
      default:
        return 'Erreur d\'authentification: ${e.message}';
    }
  }
}