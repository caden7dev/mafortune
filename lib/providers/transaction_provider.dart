import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../services/transaction_service.dart';
import '../services/budget_service.dart';

class TransactionProvider with ChangeNotifier {
  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();

  List<TransactionModel> _transactions = [];
  BudgetModel? _currentBudget;
  bool _isLoading = false;
  String? _errorMessage;

  // Stats rapides du jour
  double _todayIncome = 0.0;
  double _todayExpense = 0.0;
  int _todayCount = 0;

  // Getters
  List<TransactionModel> get transactions => _transactions;
  BudgetModel? get currentBudget => _currentBudget;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get todayIncome => _todayIncome;
  double get todayExpense => _todayExpense;
  int get todayCount => _todayCount;

  /// Charge toutes les données initiales nécessaires pour le Dashboard d'un commerçant
  Future<void> loadDashboardData(String commercantId) async {
    _setLoading(true);
    _clearErrors();
    try {
      // Chargement parallèle des transactions, des statistiques rapides et du budget du mois
      await Future.wait([
        _fetchTransactions(commercantId),
        _fetchQuickStats(commercantId),
        _fetchCurrentBudget(commercantId),
      ]);
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des données : $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Récupération des transactions
  Future<void> _fetchTransactions(String commercantId) async {
    _transactions = await _transactionService.getTransactionsByCommercant(commercantId);
  }

  /// Récupération des statistiques rapides du jour
  Future<void> _fetchQuickStats(String commercantId) async {
    final stats = await _transactionService.getQuickStats(commercantId);
    _todayIncome = stats['todayIncome'] ?? 0.0;
    _todayExpense = stats['todayExpense'] ?? 0.0;
    _todayCount = stats['todayTransactionsCount'] ?? 0;
  }

  /// Récupération du budget en cours
  Future<void> _fetchCurrentBudget(String commercantId) async {
    _currentBudget = await _budgetService.getCurrentBudget(commercantId);
  }

  /// AJOUTER UNE TRANSACTION
  Future<bool> addTransaction(TransactionModel transaction) async {
    _clearErrors();
    try {
      await _transactionService.addTransaction(transaction);
      
      // Rafraîchir les listes et les compteurs locaux pour l'UI
      await _fetchTransactions(transaction.commercantId);
      await _fetchQuickStats(transaction.commercantId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  /// MODIFIER UNE TRANSACTION (Gère automatiquement le recalcul du solde global)
  Future<bool> updateTransaction(TransactionModel transaction) async {
    _clearErrors();
    try {
      await _transactionService.updateTransaction(transaction);
      
      await _fetchTransactions(transaction.commercantId);
      await _fetchQuickStats(transaction.commercantId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  /// SUPPRIMER UNE TRANSACTION (Recalcule le solde en conséquence)
  Future<bool> deleteTransaction(String transactionId, String commercantId) async {
    _clearErrors();
    try {
      await _transactionService.deleteTransaction(transactionId, commercantId);
      
      await _fetchTransactions(commercantId);
      await _fetchQuickStats(commercantId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  /// ENREGISTRER / MODIFIER UN BUDGET MENSUEL
  Future<bool> saveMonthlyBudget(BudgetModel budget) async {
    _clearErrors();
    try {
      await _budgetService.saveBudget(budget);
      _currentBudget = budget;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // ===========================================================================
  // MODULE D'ALERTES DE BUDGET (MÉTHODES ET CALCULS COMPENSATOIRES)
  // ===========================================================================

  /// Retourne le total cumulé des dépenses (Dépenses uniquement) du mois en cours
  double get totalDepensesMoisEnCours {
    final now = DateTime.now();
    double total = 0.0;
    
    for (var t in _transactions) {
      // On filtre uniquement les dépenses du mois et de l'année en cours
      if (!t.estRecette && t.date.month == now.month && t.date.year == now.year) {
        total += t.montant;
      }
    }
    return total;
  }

  /// Analyse les dépenses vis-à-vis du budget défini pour lever des alertes
  BudgetAlert? get analyseBudget {
    if (_currentBudget == null || _currentBudget!.montant <= 0) return null;

    final depenses = totalDepensesMoisEnCours;
    final limite = _currentBudget!.montant;
    final pourcentageUsage = (depenses / limite) * 100;

    if (pourcentageUsage >= 100) {
      return BudgetAlert(
        niveau: AlertNiveau.critique,
        pourcentage: pourcentageUsage,
        message: 'Alerte Critique : Vous avez dépassé votre budget mensuel de ${pourcentageUsage.toStringAsFixed(0)}% (${depenses.toStringAsFixed(0)} FCFA dépensés sur un budget de ${limite.toStringAsFixed(0)} FCFA) !',
      );
    } else if (pourcentageUsage >= 80) {
      return BudgetAlert(
        niveau: AlertNiveau.avertissement,
        pourcentage: pourcentageUsage,
        message: 'Avertissement : Vous avez consommé ${pourcentageUsage.toStringAsFixed(0)}% de votre budget mensuel. Modérez vos dépenses.',
      );
    } else if (pourcentageUsage >= 50) {
      return BudgetAlert(
        niveau: AlertNiveau.info,
        pourcentage: pourcentageUsage,
        message: 'Info : Moitié de votre budget atteinte (${pourcentageUsage.toStringAsFixed(0)}%).',
      );
    }
    
    return null;
  }

  // Helpers internes
  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _clearErrors() {
    _errorMessage = null;
  }
}