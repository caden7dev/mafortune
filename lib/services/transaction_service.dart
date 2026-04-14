import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Ajouter une transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    print('\n💾 === AJOUT TRANSACTION ===');
    print('Type: ${transaction.type.name}');
    print('Montant: ${transaction.montant} FCFA');
    print('Catégorie: ${transaction.categorie}');
    
    try {
      final docRef = await _firestore.collection('transactions').add(transaction.toFirestore());
      print('✅ Transaction ajoutée - ID: ${docRef.id}');

      await _updateCommercantSolde(
        transaction.commercantId,
        transaction.impactSolde,
      );
      print('✅ Solde mis à jour: ${transaction.impactSolde > 0 ? '+' : ''}${transaction.impactSolde} FCFA');
      print('========================================\n');
    } catch (e) {
      print('❌ Erreur ajout transaction: $e\n');
      rethrow;
    }
  }

  // ✅ Récupérer toutes les transactions d'un commerçant (SANS INDEX COMPOSITE)
  Future<List<TransactionModel>> getTransactionsByCommercant(
    String commercantId, {
    int? limit,
  }) async {
    print('\n📋 === RÉCUPÉRATION TRANSACTIONS ===');
    print('CommerçantID: $commercantId');
    print('Limit: ${limit ?? "aucune"}');
    
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .get();
      
      print('📦 Transactions trouvées: ${snapshot.docs.length}');

      var transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      
      transactions.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
      
      if (limit != null && limit < transactions.length) {
        transactions = transactions.sublist(0, limit);
      }

      print('✅ Transactions chargées: ${transactions.length}');
      for (var i = 0; i < transactions.length && i < 5; i++) {
        final t = transactions[i];
        print('   ${i + 1}. ${t.description ?? t.categorie}: ${t.montant} FCFA (${t.estRecette ? "R" : "D"})');
      }
      if (transactions.length > 5) {
        print('   ... et ${transactions.length - 5} autres');
      }
      print('========================================\n');

      return transactions;
    } catch (e) {
      print('❌ Erreur récupération transactions: $e\n');
      rethrow;
    }
  }

  // ✅ Récupérer les transactions par période (utilise `commercantId`)
  Future<List<TransactionModel>> getTransactionsByPeriode(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    print('\n📅 === RÉCUPÉRATION PAR PÉRIODE ===');
    print('CommerçantID: $commercantId');
    print('Période: ${dateDebut.toString().split(' ')[0]} → ${dateFin.toString().split(' ')[0]}');
    
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateDebut))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dateFin))
          .orderBy('date', descending: true)
          .get();

      print('📦 Transactions trouvées: ${snapshot.docs.length}');

      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      print('========================================\n');
      return transactions;
    } catch (e) {
      print('❌ Erreur récupération par période: $e\n');
      print('🔄 Utilisation de la méthode alternative...');
      return await _getTransactionsByPeriodeAlternative(commercantId, dateDebut, dateFin);
    }
  }

  // ✅ Méthode alternative pour les périodes (SANS INDEX)
  Future<List<TransactionModel>> _getTransactionsByPeriodeAlternative(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    try {
      final allTransactions = await getTransactionsByCommercant(commercantId);
      
      final filteredTransactions = allTransactions.where((transaction) {
        return transaction.date.isAfter(dateDebut) && 
               transaction.date.isBefore(dateFin);
      }).toList();
      
      filteredTransactions.sort((a, b) => b.date.compareTo(a.date));
      
      print('📦 Transactions filtrées (alternative): ${filteredTransactions.length}');
      return filteredTransactions;
    } catch (e) {
      print('❌ Erreur méthode alternative: $e');
      return [];
    }
  }

  // ✅ Statistiques rapides (aujourd'hui) - utilise la date de la transaction
  Future<Map<String, dynamic>> getQuickStats(String commercantId) async {
    print('\n📊 === STATS RAPIDES ===');
    print('CommerçantID: $commercantId');
    
    try {
      final allTransactions = await getTransactionsByCommercant(commercantId);
      print('📦 Total transactions: ${allTransactions.length}');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      print('📅 Aujourd\'hui: ${today.day}/${today.month}/${today.year}');

      double todayIncome = 0;
      double todayExpense = 0;
      int todayCount = 0;

      for (var transaction in allTransactions) {
        final transDate = transaction.date;
        
        final isSameDay = transDate.year == today.year &&
                         transDate.month == today.month &&
                         transDate.day == today.day;
        
        if (isSameDay) {
          todayCount++;
          if (transaction.estRecette) {
            todayIncome += transaction.montant;
            print('   ✅ RECETTE ajoutée: ${transaction.montant} FCFA (${transaction.description ?? transaction.categorie})');
          } else {
            todayExpense += transaction.montant;
            print('   ✅ DÉPENSE ajoutée: ${transaction.montant} FCFA (${transaction.description ?? transaction.categorie})');
          }
        }
      }

      print('\n💰 RÉSULTAT FINAL:');
      print('💰 Recettes aujourd\'hui: $todayIncome FCFA');
      print('🛒 Dépenses aujourd\'hui: $todayExpense FCFA');
      print('📊 Transactions aujourd\'hui: $todayCount');
      print('========================================\n');

      return {
        'todayIncome': todayIncome,
        'todayExpense': todayExpense,
        'todayTransactionsCount': todayCount,
      };
    } catch (e) {
      print('❌ Erreur stats rapides: $e\n');
      return {
        'todayIncome': 0.0,
        'todayExpense': 0.0,
        'todayTransactionsCount': 0,
      };
    }
  }

  // ✅ Statistiques détaillées pour les rapports
  Future<Map<String, dynamic>> getDetailedStats(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
  ) async {
    print('\n📈 === STATISTIQUES DÉTAILLÉES ===');
    print('Période: ${dateDebut.day}/${dateDebut.month}/${dateDebut.year} → ${dateFin.day}/${dateFin.month}/${dateFin.year}');
    
    try {
      final transactions = await getTransactionsByPeriode(
        commercantId,
        dateDebut,
        dateFin,
      );

      double totalRecettes = 0;
      double totalDepenses = 0;
      int nombreRecettes = 0;
      int nombreDepenses = 0;
      Map<String, double> recettesParCategorie = {};
      Map<String, double> depensesParCategorie = {};

      for (var transaction in transactions) {
        if (transaction.estRecette) {
          totalRecettes += transaction.montant;
          nombreRecettes++;
          recettesParCategorie[transaction.categorie] =
              (recettesParCategorie[transaction.categorie] ?? 0) + transaction.montant;
        } else {
          totalDepenses += transaction.montant;
          nombreDepenses++;
          depensesParCategorie[transaction.categorie] =
              (depensesParCategorie[transaction.categorie] ?? 0) + transaction.montant;
        }
      }

      final result = {
        'totalRecettes': totalRecettes,
        'totalDepenses': totalDepenses,
        'beneficeNet': totalRecettes - totalDepenses,
        'nombreRecettes': nombreRecettes,
        'nombreDepenses': nombreDepenses,
        'nombreTransactions': transactions.length,
        'recettesParCategorie': recettesParCategorie,
        'depensesParCategorie': depensesParCategorie,
        'periode': {
          'debut': dateDebut,
          'fin': dateFin,
        },
      };

      print('✅ Statistiques calculées:');
      print('   - Recettes: $totalRecettes FCFA');
      print('   - Dépenses: $totalDepenses FCFA');
      print('   - Bénéfice: ${totalRecettes - totalDepenses} FCFA');
      print('========================================\n');

      return result;
    } catch (e) {
      print('❌ Erreur stats détaillées: $e');
      return {
        'totalRecettes': 0.0,
        'totalDepenses': 0.0,
        'beneficeNet': 0.0,
        'nombreRecettes': 0,
        'nombreDepenses': 0,
        'nombreTransactions': 0,
        'recettesParCategorie': {},
        'depensesParCategorie': {},
        'periode': {
          'debut': dateDebut,
          'fin': dateFin,
        },
      };
    }
  }

  // ✅ Récupérer les transactions par type (recette/dépense)
  Future<List<TransactionModel>> getTransactionsByType(
    String commercantId,
    TypeTransaction type,
  ) async {
    print('\n🔍 === RÉCUPÉRATION PAR TYPE ===');
    print('Type: ${type.name}');
    
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('type', isEqualTo: type.name)
          .orderBy('dateCreation', descending: true)
          .get();

      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      print('📦 Transactions ${type.name}: ${transactions.length}');
      return transactions;
    } catch (e) {
      print('❌ Erreur récupération par type: $e');
      return [];
    }
  }

  // ✅ Récupérer les transactions par catégorie
  Future<List<TransactionModel>> getTransactionsByCategorie(
    String commercantId,
    String categorie,
  ) async {
    print('\n🏷️ === RÉCUPÉRATION PAR CATÉGORIE ===');
    print('Catégorie: $categorie');
    
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('commercantId', isEqualTo: commercantId)
          .where('categorie', isEqualTo: categorie)
          .orderBy('dateCreation', descending: true)
          .get();

      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      print('📦 Transactions pour $categorie: ${transactions.length}');
      return transactions;
    } catch (e) {
      print('❌ Erreur récupération par catégorie: $e');
      return [];
    }
  }

  // ✅ Récupérer les statistiques mensuelles
  Future<Map<String, Map<String, double>>> getMonthlyStats(
    String commercantId,
    int year,
  ) async {
    print('\n📅 === STATISTIQUES MENSUELLES ===');
    print('Année: $year');
    
    final stats = <String, Map<String, double>>{};
    
    try {
      for (int month = 1; month <= 12; month++) {
        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
        
        final monthlyStats = await getDetailedStats(
          commercantId,
          startDate,
          endDate,
        );
        
        final monthKey = '${month.toString().padLeft(2, '0')}/$year';
        stats[monthKey] = {
          'recettes': monthlyStats['totalRecettes'] ?? 0,
          'depenses': monthlyStats['totalDepenses'] ?? 0,
          'benefice': monthlyStats['beneficeNet'] ?? 0,
        };
      }
      
      print('✅ Statistiques mensuelles calculées');
      return stats;
    } catch (e) {
      print('❌ Erreur stats mensuelles: $e');
      return {};
    }
  }

  // ✅ Calculer le total des transactions sur une période
  Future<double> getTotalByPeriod(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
    {bool recettes = true}
  ) async {
    try {
      final stats = await getDetailedStats(commercantId, dateDebut, dateFin);
      return recettes ? stats['totalRecettes'] ?? 0 : stats['totalDepenses'] ?? 0;
    } catch (e) {
      print('❌ Erreur calcul total: $e');
      return 0;
    }
  }

  // ✅ Récupérer les meilleures catégories (top 5)
  Future<Map<String, double>> getTopCategories(
    String commercantId,
    DateTime dateDebut,
    DateTime dateFin,
    {bool recettes = true}
  ) async {
    try {
      final stats = await getDetailedStats(commercantId, dateDebut, dateFin);
      final categories = recettes 
          ? stats['recettesParCategorie'] as Map<String, double>
          : stats['depensesParCategorie'] as Map<String, double>;
      
      final sortedEntries = categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topCategories = <String, double>{};
      for (int i = 0; i < sortedEntries.length && i < 5; i++) {
        topCategories[sortedEntries[i].key] = sortedEntries[i].value;
      }
      
      return topCategories;
    } catch (e) {
      print('❌ Erreur top catégories: $e');
      return {};
    }
  }

  // ✅ Modifier une transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    print('\n✏️ === MODIFICATION TRANSACTION ===');
    print('ID: ${transaction.id}');
    print('Nouveau montant: ${transaction.montant} FCFA');
    
    try {
      final oldDoc = await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .get();

      if (!oldDoc.exists) {
        throw Exception('Transaction introuvable');
      }

      final oldTransaction = TransactionModel.fromFirestore(oldDoc);
      print('Ancien montant: ${oldTransaction.montant} FCFA');

      final oldImpact = oldTransaction.impactSolde;
      final newImpact = transaction.impactSolde;
      final delta = newImpact - oldImpact;

      print('Delta solde: ${delta > 0 ? '+' : ''}$delta FCFA');

      await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .update(transaction.toFirestore());
      print('✅ Transaction mise à jour');

      await _updateCommercantSolde(transaction.commercantId, delta);
      print('✅ Solde mis à jour');
      print('========================================\n');
    } catch (e) {
      print('❌ Erreur modification: $e\n');
      rethrow;
    }
  }

  // ✅ Supprimer une transaction
  Future<void> deleteTransaction(String transactionId, String commercantId) async {
    print('\n🗑️ === SUPPRESSION TRANSACTION ===');
    print('ID: $transactionId');
    
    try {
      final doc = await _firestore
          .collection('transactions')
          .doc(transactionId)
          .get();

      if (!doc.exists) {
        throw Exception('Transaction introuvable');
      }

      final transaction = TransactionModel.fromFirestore(doc);
      print('Montant: ${transaction.montant} FCFA');

      await _firestore.collection('transactions').doc(transactionId).delete();
      print('✅ Transaction supprimée');

      await _updateCommercantSolde(commercantId, -transaction.impactSolde);
      print('✅ Solde mis à jour: ${-transaction.impactSolde > 0 ? '+' : ''}${-transaction.impactSolde} FCFA');
      print('========================================\n');
    } catch (e) {
      print('❌ Erreur suppression: $e\n');
      rethrow;
    }
  }

  // ✅ Rechercher des transactions par description
  Future<List<TransactionModel>> searchTransactions(
    String commercantId,
    String searchTerm,
  ) async {
    print('\n🔍 === RECHERCHE TRANSACTIONS ===');
    print('Terme: $searchTerm');
    
    try {
      final allTransactions = await getTransactionsByCommercant(commercantId);
      
      final searchLower = searchTerm.toLowerCase();
      
      final results = allTransactions.where((transaction) {
        return transaction.description?.toLowerCase().contains(searchLower) == true ||
               transaction.categorie.toLowerCase().contains(searchLower);
      }).toList();
      
      print('📦 Résultats trouvés: ${results.length}');
      return results;
    } catch (e) {
      print('❌ Erreur recherche: $e');
      return [];
    }
  }

  // ✅ Mettre à jour le solde du commerçant
  Future<void> _updateCommercantSolde(String commercantId, double montant) async {
    try {
      final userRef = _firestore.collection('utilisateurs').doc(commercantId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('Utilisateur introuvable');
        }

        final currentSolde = (userDoc.data()?['soldeActuel'] ?? 0.0).toDouble();
        final newSolde = currentSolde + montant;

        transaction.update(userRef, {'soldeActuel': newSolde});
        
        print('💰 Solde mis à jour: $currentSolde → $newSolde');
      });
    } catch (e) {
      print('❌ Erreur mise à jour solde: $e');
      rethrow;
    }
  }
}