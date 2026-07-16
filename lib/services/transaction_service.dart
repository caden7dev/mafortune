import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'package:flutter/foundation.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── CACHE MÉMOIRE ───────────────────────────────────────────────────────────
  // Évite de refaire des appels Firestore identiques dans la même session
  final Map<String, List<TransactionModel>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Durée de validité du cache : 2 minutes
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

  /// Invalide le cache d'un commerçant — à appeler après add/update/delete
  void invalidateCache(String commercantId) {
    _cache.removeWhere((key, _) => key.startsWith(commercantId));
    _cacheTimestamps.removeWhere((key, _) => key.startsWith(commercantId));
  }

  // ─── ADD ─────────────────────────────────────────────────────────────────────
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      final docRef = _db.collection('transactions').doc();
      final transactionEnregistree = transaction.copyWith(id: docRef.id);
      await docRef.set(transactionEnregistree.toFirestore());

      // Invalide le cache pour forcer un rechargement
      invalidateCache(transactionEnregistree.commercantId);

      _updateCommercantSolde(
          transactionEnregistree.commercantId,
          transactionEnregistree.impactSolde);
    } catch (e) {
      debugPrint('Erreur addTransaction: $e');
      rethrow;
    }
  }

  // ─── GET ALL — avec cache mémoire ────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactionsByCommercant(
    String commercantId, {
    int? limit,
  }) async {
    final cacheKey = '${commercantId}_all';

    // Retourne le cache si encore valide
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
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
            .get(const GetOptions(source: Source.cache));
      }

      final list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      // Tri déjà fait par Firestore (orderBy dateCreation desc)
      // On met en cache TOUTE la liste
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

  // ─── GET QUICK STATS — requête Firestore ciblée sur aujourd'hui ──────────────
  // ✅ OPTIMISATION : au lieu de charger TOUTES les transactions et filtrer
  // en mémoire, on demande directement à Firestore les transactions du jour.
  Future<Map<String, dynamic>> getQuickStats(String commercantId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        // Fallback cache si pas d'index ou pas de réseau
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get(const GetOptions(source: Source.cache));
      }

      double todayIncome = 0;
      double todayExpense = 0;

      for (final doc in snapshot.docs) {
        final t = TransactionModel.fromFirestore(doc);
        if (t.estRecette) {
          todayIncome += t.montant;
        } else {
          todayExpense += t.montant;
        }
      }

      return {
        'todayIncome': todayIncome,
        'todayExpense': todayExpense,
        'todayTransactionsCount': snapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Erreur getQuickStats: $e');
      rethrow;
    }
  }

  // ─── GET PAR PÉRIODE ─────────────────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactionsByPeriode(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    try {
      final debut =
          DateTime(dateDebut.year, dateDebut.month, dateDebut.day, 0, 0, 0);
      final fin =
          DateTime(dateFin.year, dateFin.month, dateFin.day, 23, 59, 59);

      final snapshot = await _db
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(debut))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(fin))
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Fallback local pour période: $e');
      // Fallback si index composite manquant
      final all = await getTransactionsByCommercant(commercantId);
      final debut =
          DateTime(dateDebut.year, dateDebut.month, dateDebut.day, 0, 0, 0);
      final fin =
          DateTime(dateFin.year, dateFin.month, dateFin.day, 23, 59, 59);
      return all.where((t) {
        return !t.date.isBefore(debut) && !t.date.isAfter(fin);
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
  }

  // ─── GET DETAILED STATS ───────────────────────────────────────────────────────
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

  // ─── GET MONTHLY STATS — ✅ UNE SEULE LECTURE FIRESTORE ──────────────────────
  // Au lieu de faire 12 appels séparés, on charge toutes les transactions
  // de l'année en UNE SEULE requête et on trie en mémoire.
  Future<Map<String, Map<String, double>>> getMonthlyStats(
    String commercantId,
    int year,
  ) async {
    final stats = <String, Map<String, double>>{};

    try {
      // Une seule requête pour toute l'année
      final startOfYear = DateTime(year, 1, 1, 0, 0, 0);
      final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

      final transactions = await getTransactionsByPeriode(
          commercantId, startOfYear, endOfYear);

      // Initialiser tous les mois à 0
      for (int month = 1; month <= 12; month++) {
        stats['${month.toString().padLeft(2, '0')}/$year'] = {
          'recettes': 0,
          'depenses': 0,
          'benefice': 0,
        };
      }

      // Trier en mémoire — zéro appel Firestore supplémentaire
      for (final t in transactions) {
        final key =
            '${t.date.month.toString().padLeft(2, '0')}/$year';
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
      // Retourne des stats vides si erreur
      for (int month = 1; month <= 12; month++) {
        stats['${month.toString().padLeft(2, '0')}/$year'] = {
          'recettes': 0,
          'depenses': 0,
          'benefice': 0,
        };
      }
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
          .orderBy('dateCreation', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Erreur getTransactionsByType: $e');
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
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Erreur getTransactionsByCategorie: $e');
      return [];
    }
  }

  Future<List<TransactionModel>> searchTransactions(
    String commercantId,
    String searchTerm,
  ) async {
    try {
      // Utilise le cache si disponible
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

      await _db
          .collection('transactions')
          .doc(transaction.id)
          .update(transaction.toFirestore());

      invalidateCache(transaction.commercantId);
      _updateCommercantSolde(transaction.commercantId, delta);
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
      await _db.collection('transactions').doc(transactionId).delete();

      invalidateCache(commercantId);
      _updateCommercantSolde(commercantId, -transaction.impactSolde);
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
      debugPrint('Solde sera sync au retour du réseau: $e');
    });
  }
}