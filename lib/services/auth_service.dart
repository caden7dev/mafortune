import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/utilisateur_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

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

      try {
        await userCredential.user!.sendEmailVerification();
      } catch (e) {
        // Ignorer l'erreur d'envoi d'email
      }

      return utilisateur;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de l\'inscription: $e';
    }
  }

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

      try {
        await _firestore
            .collection('utilisateurs')
            .doc(utilisateur.id)
            .update({
          'derniereSynchronisation': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Ignorer l'erreur de mise à jour
      }

      return utilisateur;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue lors de la connexion: $e';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Erreur lors de l\'envoi de l\'email de réinitialisation';
    }
  }

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
    } catch (e) {
      throw 'Erreur lors du changement de mot de passe';
    }
  }

  Future<UtilisateurModel> updateUserProfile(UtilisateurModel user) async {
    try {
      await _firestore
          .collection('utilisateurs')
          .doc(user.id)
          .update(user.toFirestore());

      final authUser = _auth.currentUser;
      if (authUser != null && authUser.displayName != user.nomComplet) {
        await authUser.updateDisplayName(user.nomComplet);
      }

      return user;
    } catch (e) {
      throw 'Erreur lors de la mise à jour du profil: $e';
    }
  }

  Future<UtilisateurModel?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      return UtilisateurModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateCommercantSolde(String userId, double nouveauSolde) async {
    try {
      await _firestore
          .collection('utilisateurs')
          .doc(userId)
          .update({
        'soldeActuel': nouveauSolde,
        'dateModification': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Erreur lors de la mise à jour du solde';
    }
  }

  Future<bool> isEmailUsed(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

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
      case 'operation-not-allowed':
        return 'Opération non autorisée';
      case 'requires-recent-login':
        return 'Veuillez vous reconnecter pour effectuer cette action';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      case 'network-request-failed':
        return 'Problème de connexion internet. Vérifiez votre réseau';
      default:
        return 'Erreur d\'authentification: ${e.message}';
    }
  }
}