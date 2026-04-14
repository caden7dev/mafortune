import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<BudgetModel?> getCurrentBudget(String commercantId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    try {
      final snapshot = await _firestore
          .collection('budgets')
          .where('commercantId', isEqualTo: commercantId)
          .where('mois', isEqualTo: Timestamp.fromDate(startOfMonth))
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      return BudgetModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveBudget(BudgetModel budget) async {
    try {
      await _firestore
          .collection('budgets')
          .doc(budget.id)
          .set(budget.toFirestore());
    } catch (e) {
      throw 'Erreur lors de la sauvegarde du budget';
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      await _firestore.collection('budgets').doc(budgetId).delete();
    } catch (e) {
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