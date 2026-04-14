import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';

class BilansScreen extends StatefulWidget {
  const BilansScreen({super.key});

  @override
  State<BilansScreen> createState() => _BilansScreenState();
}

class _BilansScreenState extends State<BilansScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  
  UtilisateurModel? _currentUser;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  
  // Période sélectionnée
  String _selectedPeriod = 'mois';
  DateTime _selectedDate = DateTime.now();
  
  // Statistiques
  double _totalRecettes = 0;
  double _totalDepenses = 0;
  Map<String, double> _monthlyRecettes = {};
  Map<String, double> _monthlyDepenses = {};
  Map<String, double> _categoryExpenses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _currentUser = await _authService.getCurrentUserData();
      if (_currentUser == null) return;
      
      _transactions = await _transactionService.getTransactionsByCommercant(_currentUser!.id);
      _calculateStats();
    } catch (e) {
      print('Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    DateTime startDate;
    DateTime endDate = DateTime.now();
    
    switch (_selectedPeriod) {
      case 'mois':
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        break;
      case 'trimestre':
        final quarter = ((_selectedDate.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        startDate = DateTime(_selectedDate.year, startMonth, 1);
        endDate = DateTime(_selectedDate.year, startMonth + 3, 0);
        break;
      case 'annee':
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31);
        break;
      default:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
    }
    
    final periodTransactions = _transactions.where((t) {
      return t.date.isAfter(startDate) && t.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    _totalRecettes = periodTransactions.where((t) => t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
    _totalDepenses = periodTransactions.where((t) => !t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
    
    // Calcul par mois pour l'évolution (uniquement pour l'année en cours)
    _monthlyRecettes.clear();
    _monthlyDepenses.clear();
    
    final currentYear = _selectedDate.year;
    for (int i = 1; i <= 12; i++) {
      final monthStart = DateTime(currentYear, i, 1);
      final monthEnd = DateTime(currentYear, i + 1, 0);
      
      final monthTransactions = _transactions.where((t) {
        return t.date.isAfter(monthStart) && t.date.isBefore(monthEnd.add(const Duration(days: 1)));
      }).toList();
      
      final monthRecettes = monthTransactions.where((t) => t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
      final monthDepenses = monthTransactions.where((t) => !t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
      
      final monthName = DateFormat('MMM', 'fr_FR').format(monthStart);
      _monthlyRecettes[monthName] = monthRecettes;
      _monthlyDepenses[monthName] = monthDepenses;
    }
    
    // Top 5 catégories de dépenses
    final expensesByCategory = <String, double>{};
    for (var t in periodTransactions.where((t) => !t.estRecette)) {
      expensesByCategory[t.categorie] = (expensesByCategory[t.categorie] ?? 0) + t.montant;
    }
    
    final sortedEntries = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _categoryExpenses = {};
    for (int i = 0; i < (sortedEntries.length > 5 ? 5 : sortedEntries.length); i++) {
      _categoryExpenses[sortedEntries[i].key] = sortedEntries[i].value;
    }
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      _calculateStats();
    });
  }

  void _changeDate(int offset) {
    setState(() {
      if (_selectedPeriod == 'mois') {
        var newMonth = _selectedDate.month + offset;
        var newYear = _selectedDate.year;
        if (newMonth < 1) {
          newMonth = 12;
          newYear--;
        } else if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
        _selectedDate = DateTime(newYear, newMonth, 1);
      } else if (_selectedPeriod == 'trimestre') {
        var newMonth = _selectedDate.month + (offset * 3);
        var newYear = _selectedDate.year;
        if (newMonth < 1) {
          newMonth = 12;
          newYear--;
        } else if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
        _selectedDate = DateTime(newYear, newMonth, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year + offset, 1, 1);
      }
      _calculateStats();
    });
  }

  String _getPeriodTitle() {
    switch (_selectedPeriod) {
      case 'mois':
        return DateFormat('MMMM yyyy', 'fr_FR').format(_selectedDate);
      case 'trimestre':
        final quarter = ((_selectedDate.month - 1) ~/ 3) + 1;
        return 'Trimestre $quarter ${_selectedDate.year}';
      case 'annee':
        return _selectedDate.year.toString();
      default:
        return '';
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  @override
Widget build(BuildContext context) {
  final solde = _totalRecettes - _totalDepenses;
  final hasData = _totalRecettes > 0 || _totalDepenses > 0;

  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
        : SingleChildScrollView(
            child: Column(
              children: [
                // Sélecteur de période
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Navigation date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeDate(-1),
                          ),
                          Text(
                            _getPeriodTitle(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _changeDate(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Boutons période
                      Row(
                        children: [
                          Expanded(
                            child: _buildPeriodChip('Mois', 'mois'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPeriodChip('Trimestre', 'trimestre'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPeriodChip('Année', 'annee'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Cartes récapitulatives
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Recettes',
                          _totalRecettes,
                          Colors.green,
                          Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Dépenses',
                          _totalDepenses,
                          Colors.red,
                          Icons.trending_down,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Solde',
                          solde,
                          solde >= 0 ? Colors.green : Colors.red,
                          Icons.account_balance,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Graphique camembert simplifié
                if (hasData)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Répartition Recettes / Dépenses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSimplePieChart(),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Graphique évolution mensuelle simplifié
                if (_monthlyRecettes.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Évolution mensuelle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSimpleBarChart(),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Top catégories de dépenses
                if (_categoryExpenses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top catégories de dépenses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._categoryExpenses.entries.map((entry) {
                          final total = _categoryExpenses.values.fold(0.0, (sum, v) => sum + v);
                          final percent = total > 0 ? (entry.value / total) * 100 : 0;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      '${_formatAmount(entry.value)} FCFA (${percent.toStringAsFixed(1)}%)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: percent / 100,
                                  backgroundColor: Colors.red[100],
                                  color: Colors.red,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
    
  );
}

Widget _buildSimplePieChart() {
  final total = _totalRecettes + _totalDepenses;
  if (total == 0) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Aucune donnée à afficher'),
      ),
    );
  }

  final recettesPercent = (_totalRecettes / total) * 100;
  final depensesPercent = (_totalDepenses / total) * 100;

  return Column(
    children: [
      SizedBox(
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Graphique circulaire simple avec CustomPaint
            CustomPaint(
              size: const Size(180, 180),
              painter: _SimplePiePainter(
                recettesPercent: recettesPercent,
                depensesPercent: depensesPercent,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_formatAmount(total)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Total', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegend('Recettes', Colors.green),
          const SizedBox(width: 24),
          _buildLegend('Dépenses', Colors.red),
        ],
      ),
    ],
  );
}

Widget _buildSimpleBarChart() {
  final months = _monthlyRecettes.keys.toList();
  final maxValue = [
    ..._monthlyRecettes.values,
    ..._monthlyDepenses.values,
  ].fold(0.0, (max, v) => v > max ? v : max);
  
  final maxHeight = maxValue > 0 ? maxValue : 1;

  return Column(
    children: [
      SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: months.map((month) {
            final recettes = _monthlyRecettes[month] ?? 0;
            final depenses = _monthlyDepenses[month] ?? 0;
            final recettesHeight = (recettes / maxHeight) * 150;
            final depensesHeight = (depenses / maxHeight) * 150;
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Barre Recettes
                Container(
                  width: 18,
                  height: recettesHeight > 2 ? recettesHeight : 2,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                // Barre Dépenses
                Container(
                  width: 18,
                  height: depensesHeight > 2 ? depensesHeight : 2,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  month,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegend('Recettes', Colors.green),
          const SizedBox(width: 24),
          _buildLegend('Dépenses', Colors.red),
        ],
      ),
    ],
  );
}

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changePeriod(value),
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            '${amount >= 0 ? '+' : '-'}${_formatAmount(amount.abs())} FCFA',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ✅ Painter personnalisé pour le camembert
class _SimplePiePainter extends CustomPainter {
  final double recettesPercent;
  final double depensesPercent;

  _SimplePiePainter({
    required this.recettesPercent,
    required this.depensesPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 1;

    // Calcul des angles
    final recettesAngle = 360 * (recettesPercent / 100);
    final depensesAngle = 360 * (depensesPercent / 100);

    // Dessiner la part Recettes (verte)
    paint.color = Colors.green;
    var startAngle = -90 * (3.14159 / 180); // Départ à 12h
    var sweepAngle = recettesAngle * (3.14159 / 180);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      true,
      paint,
    );

    // Dessiner la part Dépenses (rouge)
    paint.color = Colors.red;
    startAngle += sweepAngle;
    sweepAngle = depensesAngle * (3.14159 / 180);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}