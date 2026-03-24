import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';

class BilansScreen extends StatefulWidget {
  const BilansScreen({super.key});

  @override
  State<BilansScreen> createState() => _BilansScreenState();
}

class _BilansScreenState extends State<BilansScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  bool _isLoading = true;
  String _selectedPeriod = 'Mois';
  
  Map<String, dynamic> _stats = {
    'totalRecettes': 0.0,
    'totalDepenses': 0.0,
    'balance': 0.0,
    'nombreTransactions': 0,
    'recettesParCategorie': <String, double>{},
    'depensesParCategorie': <String, double>{},
  };

  @override
  void initState() {
    super.initState();
    _loadBilans();
  }

  Future<void> _loadBilans() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await _authService.getCurrentUserData();
      if (user == null) return;

      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case 'Semaine':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Mois':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Année':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      final transactions = await _transactionService.getTransactionsByPeriode(
        user.id,
        startDate,
        endDate,
      );

      double totalRecettes = 0;
      double totalDepenses = 0;
      Map<String, double> recettesParCategorie = {};
      Map<String, double> depensesParCategorie = {};

      for (var t in transactions) {
        if (t.estRecette) {
          totalRecettes += t.montant;
          recettesParCategorie[t.categorie] = 
            (recettesParCategorie[t.categorie] ?? 0) + t.montant;
        } else {
          totalDepenses += t.montant;
          depensesParCategorie[t.categorie] = 
            (depensesParCategorie[t.categorie] ?? 0) + t.montant;
        }
      }

      setState(() {
        _stats = {
          'totalRecettes': totalRecettes,
          'totalDepenses': totalDepenses,
          'balance': totalRecettes - totalDepenses,
          'nombreTransactions': transactions.length,
          'recettesParCategorie': recettesParCategorie,
          'depensesParCategorie': depensesParCategorie,
        };
      });
    } catch (e) {
      print('❌ Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bilans Financiers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _buildPeriodButton('Semaine'),
                      const SizedBox(width: 10),
                      _buildPeriodButton('Mois'),
                      const SizedBox(width: 10),
                      _buildPeriodButton('Année'),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                  : RefreshIndicator(
                      onRefresh: _loadBilans,
                      color: AppColors.primaryGreen,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 20),
                            const Text('Recettes par catégorie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _buildCategoryList(_stats['recettesParCategorie'] as Map<String, double>, _stats['totalRecettes'] as double, isRecette: true),
                            const SizedBox(height: 20),
                            const Text('Dépenses par catégorie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _buildCategoryList(_stats['depensesParCategorie'] as Map<String, double>, _stats['totalDepenses'] as double, isRecette: false),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = period);
          _loadBilans();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            period,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.primaryGreen : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final balance = _stats['balance'] as double;
    final isPositive = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.primaryGreen.withValues(alpha: 0.1) : AppColors.expenseRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('Balance ${_selectedPeriod.toLowerCase()}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text(
                  '${isPositive ? '+' : ''}${_formatAmount(balance)} FCFA',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isPositive ? AppColors.primaryGreen : AppColors.expenseRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('📈 Recettes', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('${_formatAmount(_stats['totalRecettes'] as double)} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              Expanded(
                child: Column(
                  children: [
                    const Text('📉 Dépenses', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('${_formatAmount(_stats['totalDepenses'] as double)} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.expenseRed)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Text('${_stats['nombreTransactions']} transactions', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(Map<String, double> categories, double total, {required bool isRecette}) {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text('Aucune ${isRecette ? 'recette' : 'dépense'}', style: const TextStyle(color: Colors.grey))),
      );
    }

    final sortedEntries = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedEntries.map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('${_formatAmount(entry.value)} FCFA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isRecette ? AppColors.primaryGreen : AppColors.expenseRed)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(isRecette ? AppColors.primaryGreen : AppColors.expenseRed),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}