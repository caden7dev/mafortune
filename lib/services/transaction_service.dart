import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'package:flutter/foundation.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── CACHE MÉMOIRE ───────────────────────────────────────────────────────────
  final Map<String, List<TransactionModel>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  static const Duration _cacheDuration = Duration(minutes: 2);

  bool _isCacheValid(String key) {
    final ts = _cacheTimestamps[key];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cacheDuration;
  }

  void _setCache(String key, List<TransactionModel> data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  void invalidateCache(String commercantId) {
    _cache.removeWhere((key, _) => key.startsWith(commercantId));
    _cacheTimestamps.removeWhere((key, _) => key.startsWith(commercantId));
  }

  // ─── ADD ─────────────────────────────────────────────────────────────────────
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      final docRef = _db.collection('transactions').doc();
      final transactionEnregistree = transaction.copyWith(id: docRef.id);
      
      final batch = _db.batch();
      batch.set(docRef, transactionEnregistree.toFirestore());
      
      final userDocRef = _db.collection('utilisateurs').doc(transactionEnregistree.commercantId);
      batch.update(userDocRef, {
        'soldeActuel': FieldValue.increment(transactionEnregistree.impactSolde),
      });

      await batch.commit();
      invalidateCache(transactionEnregistree.commercantId);
    } catch (e) {
      debugPrint('❌ Erreur addTransaction avec Batch, tentative fallback : $e');
      await _fallbackAddTransaction(transaction);
    }
  }

  Future<void> _fallbackAddTransaction(TransactionModel transaction) async {
    try {
      final docRef = _db.collection('transactions').doc();
      final transactionEnregistree = transaction.copyWith(id: docRef.id);
      await docRef.set(transactionEnregistree.toFirestore());
      
      invalidateCache(transactionEnregistree.commercantId);
      _updateCommercantSolde(
          transactionEnregistree.commercantId,
          transactionEnregistree.impactSolde);
    } catch (e) {
      debugPrint('❌ Erreur critique lors du fallback d\'ajout : $e');
      rethrow;
    }
  }

  // ─── GET ALL ─────────────────────────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactionsByCommercant(
    String commercantId, {
    int? limit,
  }) async {
    final cacheKey = '${commercantId}_all';

    if (_isCacheValid(cacheKey) && _cache.containsKey(cacheKey)) {
      debugPrint('✅ Cache hit: $cacheKey');
      final cached = _cache[cacheKey]!;
      if (limit != null && limit < cached.length) {
        return cached.sublist(0, limit);
      }
      return cached;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
            .orderBy('dateCreation', descending: true)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        // Fallback immédiat sur le cache local Firestore si pas de réseau ou erreur d'index
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
            .get(const GetOptions(source: Source.cache));
      }

      final list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      // Tri mémoire si la requête sans index à cause de l'orderBy a échoué et qu'on utilise le fallback local
      list.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      _setCache(cacheKey, list);

      if (limit != null && limit < list.length) {
        return list.sublist(0, limit);
      }
      return list;
    } catch (e) {
      debugPrint('Erreur getTransactionsByCommercant: $e');
      rethrow;
    }
  }

  // ─── GET QUICK STATS ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getQuickStats(String commercantId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // On s'appuie d'abord sur la fonction de filtrage par période (qui gère l'absence d'index)
      final transactions = await getTransactionsByPeriode(commercantId, startOfDay, endOfDay);

      double todayIncome = 0;
      double todayExpense = 0;

      for (final t in transactions) {
        if (t.estRecette) {
          todayIncome += t.montant;
        } else {
          todayExpense += t.montant;
        }
      }

      return {
        'todayIncome': todayIncome,
        'todayExpense': todayExpense,
        'todayTransactionsCount': transactions.length,
      };
    } catch (e) {
      debugPrint('Erreur getQuickStats: $e');
      return {
        'todayIncome': 0.0,
        'todayExpense': 0.0,
        'todayTransactionsCount': 0,
      };
    }
  }

  // ─── GET PAR PÉRIODE ─────────────────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactionsByPeriode(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    final debut = DateTime(dateDebut.year, dateDebut.month, dateDebut.day, 0, 0, 0);
    final fin = DateTime(dateFin.year, dateFin.month, dateFin.day, 23, 59, 59);

    try {
      // Tente d'exécuter la requête composite
      final snapshot = await _db
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(fin))
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // ✅ Sécurité absolue : Si index composite manquant ou hors-ligne, filtrage propre en mémoire
      debugPrint('⚠️ Requête filtrée par date échouée (Index composite requis ?). Bascule sur filtrage mémoire : $e');
      final all = await getTransactionsByCommercant(commercantId);
      
      return all.where((t) {
        return !t.date.isBefore(debut) && !t.date.isAfter(fin);
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
  }

  // ─── GET DETAILED STATS ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDetailedStats(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    try {
      final transactions = await getTransactionsByPeriode(commercantId, dateDebut, dateFin);

      double totalRecettes = 0;
      double totalDepenses = 0;
      int nombreRecettes = 0;
      int nombreDepenses = 0;
      final recettesParCategorie = <String, double>{};
      final depensesParCategorie = <String, double>{};

      for (final t in transactions) {
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
      debugPrint('Erreur getDetailedStats: $e');
      rethrow;
    }
  }

  // ─── GET MONTHLY STATS ───────────────────────────────────────────────────────
  Future<Map<String, Map<String, double>>> getMonthlyStats(
    String commercantId,
    int year,
  ) async {
    final stats = <String, Map<String, double>>{};

    for (int month = 1; month <= 12; month++) {
      stats['${month.toString().padLeft(2, '0')}/$year'] = {
        'recettes': 0,
        'depenses': 0,
        'benefice': 0,
      };
    }

    try {
      final startOfYear = DateTime(year, 1, 1, 0, 0, 0);
      final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

      final transactions = await getTransactionsByPeriode(
          commercantId, startOfYear, endOfYear);

      for (final t in transactions) {
        final key = '${t.date.month.toString().padLeft(2, '0')}/$year';
        if (!stats.containsKey(key)) continue;

        if (t.estRecette) {
          stats[key]!['recettes'] = (stats[key]!['recettes'] ?? 0) + t.montant;
        } else {
          stats[key]!['depenses'] = (stats[key]!['depenses'] ?? 0) + t.montant;
        }
        stats[key]!['benefice'] =
            (stats[key]!['recettes'] ?? 0) - (stats[key]!['depenses'] ?? 0);
      }
    } catch (e) {
      debugPrint('Erreur getMonthlyStats: $e');
    }

    return stats;
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────
  Future<double> getTotalByPeriod(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin, {
    bool recettes = true,
  }) async {
    try {
      final stats = await getDetailedStats(commercantId, dateDebut, dateFin);
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
      final stats = await getDetailedStats(commercantId, dateDebut, dateFin);
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
          .get(const GetOptions(source: Source.serverAndCache));

      final list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      
      return list..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    } catch (e) {
      debugPrint('Erreur getTransactionsByType, bascule sur cache global local : $e');
      final all = await getTransactionsByCommercant(commercantId);
      return all.where((t) => t.type == type).toList();
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
          .get(const GetOptions(source: Source.serverAndCache));

      final list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      
      return list..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    } catch (e) {
      debugPrint('Erreur getTransactionsByCategorie, bascule mémoire : $e');
      final all = await getTransactionsByCommercant(commercantId);
      return all.where((t) => t.categorie == categorie).toList();
    }
  }

  Future<List<TransactionModel>> searchTransactions(
    String commercantId,
    String searchTerm,
  ) async {
    try {
      final all = await getTransactionsByCommercant(commercantId);
      final term = searchTerm.toLowerCase().trim();
      if (term.isEmpty) return all;
      
      return all.where((t) {
        return (t.description?.toLowerCase().contains(term) == true) ||
            t.categorie.toLowerCase().contains(term);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── UPDATE ──────────────────────────────────────────────────────────────────
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      final oldDoc = await _db
          .collection('transactions')
          .doc(transaction.id)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!oldDoc.exists) throw Exception('Transaction introuvable');

      final old = TransactionModel.fromFirestore(oldDoc);
      final delta = transaction.impactSolde - old.impactSolde;

      final batch = _db.batch();
      
      batch.update(
        _db.collection('transactions').doc(transaction.id), 
        transaction.toFirestore()
      );
      
      batch.update(
        _db.collection('utilisateurs').doc(transaction.commercantId), 
        {'soldeActuel': FieldValue.increment(delta)}
      );

      await batch.commit();
      invalidateCache(transaction.commercantId);
    } catch (e) {
      debugPrint('Erreur updateTransaction: $e');
      rethrow;
    }
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────────
  Future<void> deleteTransaction(
      String transactionId, String commercantId) async {
    try {
      final doc = await _db
          .collection('transactions')
          .doc(transactionId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) throw Exception('Transaction introuvable');

      final transaction = TransactionModel.fromFirestore(doc);
      
      final batch = _db.batch();
      
      batch.delete(_db.collection('transactions').doc(transactionId));
      batch.update(
        _db.collection('utilisateurs').doc(commercantId), 
        {'soldeActuel': FieldValue.increment(-transaction.impactSolde)}
      );

      await batch.commit();
      invalidateCache(commercantId);
    } catch (e) {
      debugPrint('Erreur deleteTransaction: $e');
      rethrow;
    }
  }

  // ─── SOLDE ───────────────────────────────────────────────────────────────────
  void _updateCommercantSolde(String commercantId, double montant) {
    _db.collection('utilisateurs').doc(commercantId).update({
      'soldeActuel': FieldValue.increment(montant),
    }).catchError((e) {
      debugPrint('Solde sera synchronisé au retour du réseau : $e');
    });
  }
}