import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/utilisateur_model.dart';
import '../../models/transaction_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UtilisateurModel>> getAllCommercants() async {
    final snapshot = await _firestore
        .collection('utilisateurs')
        .where('typeUtilisateur', isEqualTo: 'commercant')
        .get();
    return snapshot.docs.map((doc) => UtilisateurModel.fromFirestore(doc)).toList();
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final snapshot = await _firestore
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
  }

  Future<void> toggleUserStatus(String userId, bool estActif) async {
    await _firestore.collection('utilisateurs').doc(userId).update({'estActif': estActif});
  }

  Future<Map<String, dynamic>> getGlobalStats() async {
    final users = await getAllCommercants();
    final transactions = await getAllTransactions();
    double totalRecettes = 0;
    double totalDepenses = 0;
    for (var t in transactions) {
      if (t.type == TypeTransaction.recette) {
        totalRecettes += t.montant;
      } else {
        totalDepenses += t.montant;
      }
    }
    return {
      'totalUsers': users.length,
      'totalTransactions': transactions.length,
      'totalRecettes': totalRecettes,
      'totalDepenses': totalDepenses,
      'beneficeNet': totalRecettes - totalDepenses,
    };
  }
}