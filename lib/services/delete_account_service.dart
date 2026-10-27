import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class DeleteAccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Demande de suppression douce (Utilisée par le commerçant)
  Future<void> demanderSuppressionCompte() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Aucun utilisateur connecté');

    try {
      await _firestore.collection('utilisateurs').doc(user.uid).update({
        'suppressionDemandee': true,
        'dateSuppressionDemandee': FieldValue.serverTimestamp(),
        'estActif': false,
      });
    } catch (e) {
      _logError(e, 'Erreur demande de suppression');
      rethrow;
    }
  }

  // 2. Restaurer un compte (Utilisée par l'Admin ou le commerçant)
  Future<void> restaurerCompte(String userId) async {
    try {
      await _firestore.collection('utilisateurs').doc(userId).update({
        'suppressionDemandee': false,
        'dateSuppressionDemandee': null,
        'estActif': true,
      });
    } catch (e) {
      _logError(e, 'Erreur restauration du compte');
      rethrow;
    }
  }

  // 3. Suppression définitive complète (Admin ou Cloud Function)
  Future<void> supprimerDefinitivementCompte(String userId) async {
    try {
      final batch = _firestore.batch();

      // A. Supprimer les transactions
      final transactions = await _firestore
          .collection('transactions')
          .where('commercantId', isEqualTo: userId)
          .get();
      for (final doc in transactions.docs) {
        batch.delete(doc.reference);
      }

      // B. Supprimer les budgets
      final budgets = await _firestore
          .collection('budgets')
          .where('commercantId', isEqualTo: userId)
          .get();
      for (final doc in budgets.docs) {
        batch.delete(doc.reference);
      }

      // C. Supprimer les messages
      final messages = await _firestore
          .collection('messages')
          .where('commercantId', isEqualTo: userId)
          .get();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // D. Supprimer les notifications
      final notifications = await _firestore
          .collection('notifications')
          .where('commercantId', isEqualTo: userId)
          .get();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      // E. Supprimer les produits
      final produits = await _firestore
          .collection('produits')
          .where('commercantId', isEqualTo: userId)
          .get();
      for (final doc in produits.docs) {
        batch.delete(doc.reference);
      }

      // Exécuter toutes les suppressions en une seule opération
      await batch.commit();

      // F. Supprimer le document utilisateur (en dernier)
      await _firestore.collection('utilisateurs').doc(userId).delete();

      // NOTE : La suppression du compte Firebase Auth nécessite une Cloud Function
      // car on ne peut pas supprimer un compte Auth d'un autre utilisateur depuis le client.

    } catch (e) {
      _logError(e, 'Erreur suppression définitive');
      rethrow;
    }
  }

  void _logError(dynamic e, String reason) {
    FirebaseCrashlytics.instance.recordError(
      e, StackTrace.current,
      reason: reason,
      fatal: false,
    );
  }
}