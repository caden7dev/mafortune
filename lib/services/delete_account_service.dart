import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class DeleteAccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Aucun utilisateur connecté');

    try {
      // ÉTAPE 1 — Supprimer toutes les transactions Firestore
      final transactions = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('transactions')
          .get();
      for (final doc in transactions.docs) {
        await doc.reference.delete();
      }

      // ÉTAPE 2 — Supprimer toutes les catégories Firestore
      final categories = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('categories')
          .get();
      for (final doc in categories.docs) {
        await doc.reference.delete();
      }

      // ÉTAPE 3 — Supprimer le document principal de l'utilisateur
      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .delete();

      // ÉTAPE 4 — Supprimer la photo de profil dans Storage
      try {
        final photoRef = _storage.ref().child('photos/${user.uid}');
        await photoRef.delete();
      } catch (_) {
        // Pas de photo → on ignore silencieusement
      }

      // ÉTAPE 5 — Supprimer le compte Firebase Auth (en dernier)
      await user.delete();

    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e, StackTrace.current,
        reason: 'Erreur suppression de compte',
        fatal: false,
      );
      rethrow;
    }
  }
}