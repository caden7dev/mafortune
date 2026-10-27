import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<BudgetModel?> getCurrentBudget(String commercantId) async {
    final now = DateTime.now();
    // Normalisation stricte au premier jour du mois à minuit UTC/Local
    final startOfMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
    
    try {
      final snapshot = await _firestore
          .collection('budgets')
          .where('commercantId', isEqualTo: commercantId)
          .where('mois', isEqualTo: Timestamp.fromDate(startOfMonth))
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache)); // Optimisation hors-ligne
      
      if (snapshot.docs.isEmpty) return null;
      return BudgetModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Erreur lors de la récupération du budget : $e');
      return null;
    }
  }

  Future<void> saveBudget(BudgetModel budget) async {
    try {
      // Normalisation de la date avant sauvegarde
      final budgetNormalise = budget.copyWith(
        mois: DateTime(budget.mois.year, budget.mois.month, 1, 0, 0, 0),
      );
      
      await _firestore
          .collection('budgets')
          .doc(budgetNormalise.id)
          .set(budgetNormalise.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde du budget : $e');
      throw 'Erreur lors de la sauvegarde du budget';
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      await _firestore.collection('budgets').doc(budgetId).delete();
    } catch (e) {
      debugPrint('Erreur lors de la suppression du budget : $e');
      throw 'Erreur lors de la suppression du budget';
    }
  }
}

enum AlertNiveau { info, avertissement, critique }

class BudgetAlert {
  final AlertNiveau niveau;
  final String message;
  final double pourcentage;
  
  BudgetAlert({
    required this.niveau,
    required this.message,
    required this.pourcentage,
  });
  
  Color get couleur {
    switch (niveau) {
      case AlertNiveau.info:
        return Colors.blue;
      case AlertNiveau.avertissement:
        return Colors.orange;
      case AlertNiveau.critique:
        return Colors.red;
    }
  }
}