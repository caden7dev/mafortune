import 'dart:async'; // ✅ AJOUTÉ POUR LE STREAM
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';

class TransactionService {
  // ✅ SINGLETON : indispensable pour que le stream soit partagé entre TOUS
  // les écrans (Dashboard, SaisieRapide, Bilans, Rapports...). Sans ça,
  // chaque écran avait sa propre instance avec son propre stream isolé —
  // notifyListeners() d'un écran n'atteignait jamais les autres.
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final StreamController<void> _transactionUpdatedController = StreamController<void>.broadcast();
  Stream<void> get transactionUpdatedStream => _transactionUpdatedController.stream;

  void notifyListeners() {
    _transactionUpdatedController.add(null);
  }

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
    _cache[key] = List<TransactionModel>.from(data);
    _cacheTimestamps[key] = DateTime.now();
  }

  void invalidateCache(String commercantId) {
    _cache.removeWhere((key, _) => key.contains(commercantId));
    _cacheTimestamps.removeWhere((key, _) => key.contains(commercantId));
  }

  // ─── RECALCUL DU SOLDE (Pour garantir la cohérence) ─────────────────────
  Future<double> recalculerSolde(String commercantId) async {
    try {
      final transactions = await getTransactionsByCommercant(
        commercantId,
        forceRefresh: true,
      );

      double solde = 0;
      for (var t in transactions) {
        solde += t.impactSolde; 
      }

      _db.collection('utilisateurs').doc(commercantId).update({
        'soldeActuel': solde,
      }).catchError((e) {
        debugPrint('⚠️ Écriture solde en attente de sync réseau: $e');
      });

      return solde;
    } catch (e) {
      debugPrint('Erreur recalculSolde: $e');
      return 0;
    }
  }

  // ─── ADD TRANSACTION ─────────────────────────────────────────────────────────
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    try {
      final docRef = _db.collection('transactions').doc();
      final transactionEnregistree = transaction.copyWith(
        id: docRef.id,
        dateModification: DateTime.now(),
      );

      docRef.set(transactionEnregistree.toFirestore()).catchError((e) {
        debugPrint('⚠️ Écriture transaction en attente de sync réseau: $e');
      });

      invalidateCache(transactionEnregistree.commercantId);
      notifyListeners(); // ✅ CRUCIAL : Prévenir les écrans qu'il y a une nouvelle transaction

      _updateCommercantSolde(
        transactionEnregistree.commercantId,
        transactionEnregistree.impactSolde,
      );

      return transactionEnregistree;
    } catch (e) {
      debugPrint('Erreur addTransaction: $e');
      rethrow;
    }
  }

  // ─── GET ALL TRANSACTIONS (✅ CORRIGÉ : Sans orderBy pour éviter l'erreur d'index) ──
  Future<List<TransactionModel>> getTransactionsByCommercant(
    String commercantId, {
    int? limit,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${commercantId}_all';

    if (forceRefresh) {
      invalidateCache(commercantId);
    }

    if (!forceRefresh && _isCacheValid(cacheKey) && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (limit != null && limit < cached.length) {
        return cached.sublist(0, limit);
      }
      return cached;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        // ✅ MODIFICATION : On retire le .orderBy() pour éviter l'erreur d'index composite manquant
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
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

      // ✅ MODIFICATION : On trie en Dart (évite les crashs si 'dateCreation' manque ou index manquant)
      list.sort((a, b) {
        final dateA = a.dateCreation ?? DateTime(2000);
        final dateB = b.dateCreation ?? DateTime(2000);
        return dateB.compareTo(dateA); // Décroissant (le plus récent en premier)
      });

      _setCache(cacheKey, list);
      debugPrint('✅ [Service] ${list.length} transactions chargées pour $commercantId');

      if (limit != null && limit < list.length) {
        return list.sublist(0, limit);
      }
      return list;
    } catch (e) {
      debugPrint('❌ [Service] Erreur getTransactionsByCommercant: $e');
      return _cache[cacheKey] ?? [];
    }
  }

  // ─── GET QUICK STATS (Jour) ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getQuickStats(
    String commercantId, {
    bool forceRefresh = false,
  }) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        snapshot = await _db
            .collection('transactions')
            .where('commercantId', isEqualTo: commercantId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
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
      final debut = DateTime(dateDebut.year, dateDebut.month, dateDebut.day, 0, 0, 0);
      final fin = DateTime(dateFin.year, dateFin.month, dateFin.day, 23, 59, 59);

      final snapshot = await _db
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(fin))
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Fallback local pour période: $e');
      final all = await getTransactionsByCommercant(commercantId);
      final debut = DateTime(dateDebut.year, dateDebut.month, dateDebut.day, 0, 0, 0);
      final fin = DateTime(dateFin.year, dateFin.month, dateFin.day, 23, 59, 59);

      return all.where((t) => !t.date.isBefore(debut) && !t.date.isAfter(fin)).toList()
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
          recettesParCategorie[t.categorie] = (recettesParCategorie[t.categorie] ?? 0) + t.montant;
        } else {
          totalDepenses += t.montant;
          nombreDepenses++;
          depensesParCategorie[t.categorie] = (depensesParCategorie[t.categorie] ?? 0) + t.montant;
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

  // ─── HELPERS ─────────────────────────────────────────────────────────────────
  Future<double> getTotalByPeriod(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin, {
    bool recettes = true,
  }) async {
    try {
      final stats = await getDetailedStats(commercantId, dateDebut, dateFin);
      return recettes ? stats['totalRecettes'] ?? 0 : stats['totalDepenses'] ?? 0;
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

      final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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

      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
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

      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
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

  // ─── UPDATE TRANSACTION ──────────────────────────────────────────────────────
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      final oldDoc = await _db.collection('transactions').doc(transaction.id).get();
      if (!oldDoc.exists) throw Exception('Transaction introuvable');

      final old = TransactionModel.fromFirestore(oldDoc);
      final updatedTransaction = transaction.copyWith(dateModification: DateTime.now());

      final delta = updatedTransaction.impactSolde - old.impactSolde;

      _db
          .collection('transactions')
          .doc(updatedTransaction.id)
          .set(updatedTransaction.toFirestore(), SetOptions(merge: true))
          .catchError((e) {
        debugPrint('⚠️ Mise à jour transaction en attente de sync réseau: $e');
      });

      invalidateCache(updatedTransaction.commercantId);
      notifyListeners(); // ✅ CRUCIAL : Prévenir les écrans qu'une transaction a été modifiée

      if (delta != 0) {
        _updateCommercantSolde(updatedTransaction.commercantId, delta);
      }
    } catch (e) {
      debugPrint('Erreur updateTransaction: $e');
      rethrow;
    }
  }

  // ─── DELETE TRANSACTION ──────────────────────────────────────────────────────
  Future<void> deleteTransaction(String transactionId, String commercantId) async {
    try {
      final doc = await _db.collection('transactions').doc(transactionId).get();
      if (!doc.exists) throw Exception('Transaction introuvable');

      final transaction = TransactionModel.fromFirestore(doc);

      _db.collection('transactions').doc(transactionId).delete().catchError((e) {
        debugPrint('⚠️ Suppression transaction en attente de sync réseau: $e');
      });

      invalidateCache(commercantId);
      notifyListeners(); // ✅ CRUCIAL : Prévenir les écrans qu'une transaction a été supprimée

      _updateCommercantSolde(commercantId, -transaction.impactSolde);
    } catch (e) {
      debugPrint('Erreur deleteTransaction: $e');
      rethrow;
    }
  }

  // ─── MISE À JOUR DU SOLDE ───────────────────────
  void _updateCommercantSolde(String commercantId, double montant) {
    if (montant == 0) return;

    _db.collection('utilisateurs').doc(commercantId).update({
      'soldeActuel': FieldValue.increment(montant),
    }).catchError((e) {
      debugPrint('⚠️ Échec mise à jour solde (sera sync au retour réseau): $e');
    });
  }
}