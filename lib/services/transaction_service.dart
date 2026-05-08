import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'package:flutter/foundation.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      final docRef = _db.collection('transactions').doc();
      await docRef.set(transaction.toFirestore());
      _updateCommercantSolde(transaction.commercantId, transaction.impactSolde);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TransactionModel>> getTransactionsByCommercant(
    String commercantId, {
    int? limit,
  }) async {
    try {
      final snapshot = await _db
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .get();

      var list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      list.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      if (limit != null && limit < list.length) {
        list = list.sublist(0, limit);
      }

      return list;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TransactionModel>> getTransactionsByPeriode(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    try {
      final snapshot = await _db
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateDebut))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dateFin))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Fallback si l'index n'existe pas encore
      final all = await getTransactionsByCommercant(commercantId);
      return all.where((t) {
        return t.date.isAfter(dateDebut) &&
            t.date.isBefore(dateFin.add(const Duration(days: 1)));
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
  }

  Future<Map<String, dynamic>> getQuickStats(String commercantId) async {
    try {
      final all = await getTransactionsByCommercant(commercantId);
      final today = DateTime.now();

      double todayIncome = 0;
      double todayExpense = 0;
      int todayCount = 0;

      for (var t in all) {
        final sameDay = t.date.year == today.year &&
            t.date.month == today.month &&
            t.date.day == today.day;

        if (sameDay) {
          todayCount++;
          if (t.estRecette) {
            todayIncome += t.montant;
          } else {
            todayExpense += t.montant;
          }
        }
      }

      return {
        'todayIncome': todayIncome,
        'todayExpense': todayExpense,
        'todayTransactionsCount': todayCount,
      };
    } catch (e) {
      return {
        'todayIncome': 0.0,
        'todayExpense': 0.0,
        'todayTransactionsCount': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getDetailedStats(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    try {
      final transactions =
          await getTransactionsByPeriode(commercantId, dateDebut, dateFin);

      double totalRecettes = 0;
      double totalDepenses = 0;
      int nombreRecettes = 0;
      int nombreDepenses = 0;
      final recettesParCategorie = <String, double>{};
      final depensesParCategorie = <String, double>{};

      for (var t in transactions) {
        if (t.estRecette) {
          totalRecettes += t.montant;
          nombreRecettes++;
          recettesParCategorie[t.categorie] =
              (recettesParCategorie[t.categorie] ?? 0) + t.montant;
        } else {
          totalDepenses += t.montant;
          nombreDepenses++;
          depensesParCategorie[t.categorie] =
              (depensesParCategorie[t.categorie] ?? 0) + t.montant;
        }
      }

      return {
        'totalRecettes': totalRecettes,
        'totalDepenses': totalDepenses,
        'beneficeNet': totalRecettes - totalDepenses,
        'nombreRecettes': nombreRecettes,
        'nombreDepenses': nombreDepenses,
        'nombreTransactions': transactions.length,
        'recettesParCategorie': recettesParCategorie,
        'depensesParCategorie': depensesParCategorie,
        'periode': {'debut': dateDebut, 'fin': dateFin},
      };
    } catch (e) {
      return {
        'totalRecettes': 0.0,
        'totalDepenses': 0.0,
        'beneficeNet': 0.0,
        'nombreRecettes': 0,
        'nombreDepenses': 0,
        'nombreTransactions': 0,
        'recettesParCategorie': <String, double>{},
        'depensesParCategorie': <String, double>{},
        'periode': {'debut': dateDebut, 'fin': dateFin},
      };
    }
  }

  Future<Map<String, Map<String, double>>> getMonthlyStats(
    String commercantId,
    int year,
  ) async {
    final stats = <String, Map<String, double>>{};

    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);

      final monthStats =
          await getDetailedStats(commercantId, start, end);

      stats['${month.toString().padLeft(2, '0')}/$year'] = {
        'recettes': monthStats['totalRecettes'] ?? 0,
        'depenses': monthStats['totalDepenses'] ?? 0,
        'benefice': monthStats['beneficeNet'] ?? 0,
      };
    }

    return stats;
  }

  Future<double> getTotalByPeriod(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin, {
    bool recettes = true,
  }) async {
    try {
      final stats =
          await getDetailedStats(commercantId, dateDebut, dateFin);
      return recettes
          ? stats['totalRecettes'] ?? 0
          : stats['totalDepenses'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, double>> getTopCategories(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin, {
    bool recettes = true,
  }) async {
    try {
      final stats =
          await getDetailedStats(commercantId, dateDebut, dateFin);
      final categories = recettes
          ? stats['recettesParCategorie'] as Map<String, double>
          : stats['depensesParCategorie'] as Map<String, double>;

      final sorted = categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {for (var e in sorted.take(5)) e.key: e.value};
    } catch (e) {
      return {};
    }
  }

  Future<List<TransactionModel>> getTransactionsByType(
    String commercantId,
    TypeTransaction type,
  ) async {
    try {
      final snapshot = await _db
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('type', isEqualTo: type.name)
          .orderBy('dateCreation', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TransactionModel>> getTransactionsByCategorie(
    String commercantId,
    String categorie,
  ) async {
    try {
      final snapshot = await _db
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('categorie', isEqualTo: categorie)
          .orderBy('dateCreation', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TransactionModel>> searchTransactions(
    String commercantId,
    String searchTerm,
  ) async {
    try {
      final all = await getTransactionsByCommercant(commercantId);
      final term = searchTerm.toLowerCase();
      return all.where((t) {
        return t.description?.toLowerCase().contains(term) == true ||
            t.categorie.toLowerCase().contains(term);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      final oldDoc = await _db
          .collection('transactions')
          .doc(transaction.id)
          .get();

      if (!oldDoc.exists) throw Exception('Transaction introuvable');

      final old = TransactionModel.fromFirestore(oldDoc);
      final delta = transaction.impactSolde - old.impactSolde;

      await _db
          .collection('transactions')
          .doc(transaction.id)
          .update(transaction.toFirestore());

      // ✅ Mise à jour solde non bloquante
      _updateCommercantSolde(transaction.commercantId, delta);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(
      String transactionId, String commercantId) async {
    try {
      final doc = await _db
          .collection('transactions')
          .doc(transactionId)
          .get();

      if (!doc.exists) throw Exception('Transaction introuvable');

      final transaction = TransactionModel.fromFirestore(doc);

      await _db.collection('transactions').doc(transactionId).delete();

      // ✅ Mise à jour solde non bloquante
      _updateCommercantSolde(commercantId, -transaction.impactSolde);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FieldValue.increment fonctionne offline — pas besoin de runTransaction
  void _updateCommercantSolde(String commercantId, double montant) {
    _db.collection('utilisateurs').doc(commercantId).update({
      'soldeActuel': FieldValue.increment(montant),
    }).catchError((e) {
      // Firestore va rejouer cette opération automatiquement
      // quand le réseau revient — pas besoin de bloquer l'UI
      debugPrint('Solde sera sync au retour du réseau: $e');
    });
  }
}