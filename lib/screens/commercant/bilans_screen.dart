import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  int _touchedPieIndex = -1;

  String _selectedPeriod = 'mois';
  DateTime _selectedDate = DateTime.now();

  double _totalRecettes = 0;
  double _totalDepenses = 0;
  Map<String, double> _monthlyRecettes = {};
  Map<String, double> _monthlyDepenses = {};
  Map<String, double> _categoryExpenses = {};

  final List<Color> _categoryColors = [
    const Color(0xFFEF5350),
    const Color(0xFFAB47BC),
    const Color(0xFF42A5F5),
    const Color(0xFF26A69A),
    const Color(0xFFFFA726),
  ];

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
      debugPrint('Erreur bilans: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        final q = ((_selectedDate.month - 1) ~/ 3) + 1;
        final startMonth = (q - 1) * 3 + 1;
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

    final periodTx = _transactions.where((t) =>
        t.date.isAfter(startDate) &&
        t.date.isBefore(endDate.add(const Duration(days: 1)))).toList();

    _totalRecettes = periodTx.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
    _totalDepenses = periodTx.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);

    _monthlyRecettes.clear();
    _monthlyDepenses.clear();
    for (int i = 1; i <= 12; i++) {
      final ms = DateTime(_selectedDate.year, i, 1);
      final me = DateTime(_selectedDate.year, i + 1, 0);
      final mtx = _transactions.where((t) =>
          t.date.isAfter(ms) && t.date.isBefore(me.add(const Duration(days: 1)))).toList();
      final key = DateFormat('MMM', 'fr_FR').format(ms);
      _monthlyRecettes[key] = mtx.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
      _monthlyDepenses[key] = mtx.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);
    }

    final expCat = <String, double>{};
    for (var t in periodTx.where((t) => !t.estRecette)) {
      expCat[t.categorie] = (expCat[t.categorie] ?? 0) + t.montant;
    }
    final sorted = expCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _categoryExpenses = {
      for (var e in sorted.take(5)) e.key: e.value,
    };

    if (mounted) setState(() {});
  }

  void _changePeriod(String p) {
    setState(() {
      _selectedPeriod = p;
      _calculateStats();
    });
  }

  void _changeDate(int offset) {
    setState(() {
      if (_selectedPeriod == 'mois') {
        var m = _selectedDate.month + offset;
        var y = _selectedDate.year;
        if (m < 1) { m = 12; y--; }
        else if (m > 12) { m = 1; y++; }
        _selectedDate = DateTime(y, m, 1);
      } else if (_selectedPeriod == 'trimestre') {
        var m = _selectedDate.month + (offset * 3);
        var y = _selectedDate.year;
        if (m < 1) { m = 12; y--; }
        else if (m > 12) { m = 1; y++; }
        _selectedDate = DateTime(y, m, 1);
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
        final q = ((_selectedDate.month - 1) ~/ 3) + 1;
        return 'T$q ${_selectedDate.year}';
      case 'annee':
        return _selectedDate.year.toString();
      default:
        return '';
    }
  }

  String _fmt(double v) =>
      NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

  @override
  Widget build(BuildContext context) {
    final solde = _totalRecettes - _totalDepenses;
    final hasData = _totalRecettes > 0 || _totalDepenses > 0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildPeriodSelector(),
                    _buildSummaryCards(solde),
                    if (hasData) ...[
                      const SizedBox(height: 16),
                      _buildPieChartCard(),
                    ],
                    const SizedBox(height: 16),
                    _buildBarChartCard(),
                    if (_categoryExpenses.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildCategoryCard(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeDate(-1),
              ),
              Text(
                _getPeriodTitle(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeDate(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPeriodChip('Mois', 'mois')),
              const SizedBox(width: 8),
              Expanded(child: _buildPeriodChip('Trimestre', 'trimestre')),
              const SizedBox(width: 8),
              Expanded(child: _buildPeriodChip('Année', 'annee')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final selected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => _changePeriod(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double solde) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Recettes', _totalRecettes, Colors.green, Icons.trending_up)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('Dépenses', _totalDepenses, Colors.red, Icons.trending_down)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('Solde', solde, solde >= 0 ? Colors.green : Colors.red, Icons.account_balance_wallet)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            '${amount < 0 ? '-' : ''}${_fmt(amount.abs())}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildPieChartCard() {
    final total = _totalRecettes + _totalDepenses;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Répartition Recettes / Dépenses',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            _touchedPieIndex =
                                response?.touchedSection?.touchedSectionIndex ?? -1;
                          });
                        },
                      ),
                      sections: [
                        PieChartSectionData(
                          value: _totalRecettes,
                          color: Colors.green,
                          title: _touchedPieIndex == 0
                              ? '${(_totalRecettes / total * 100).toStringAsFixed(1)}%'
                              : '${(_totalRecettes / total * 100).toStringAsFixed(0)}%',
                          radius: _touchedPieIndex == 0 ? 70 : 60,
                          titleStyle: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        PieChartSectionData(
                          value: _totalDepenses,
                          color: Colors.red,
                          title: _touchedPieIndex == 1
                              ? '${(_totalDepenses / total * 100).toStringAsFixed(1)}%'
                              : '${(_totalDepenses / total * 100).toStringAsFixed(0)}%',
                          radius: _touchedPieIndex == 1 ? 70 : 60,
                          titleStyle: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                      centerSpaceRadius: 45,
                      sectionsSpace: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Recettes', Colors.green, _fmt(_totalRecettes)),
                    const SizedBox(height: 16),
                    _buildLegendItem('Dépenses', Colors.red, _fmt(_totalDepenses)),
                    const SizedBox(height: 16),
                    _buildLegendItem('Total', Colors.grey[700]!, _fmt(total)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String amount) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text(amount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChartCard() {
    final months = _monthlyRecettes.keys.toList();
    final maxVal = [
      ..._monthlyRecettes.values,
      ..._monthlyDepenses.values,
    ].fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Évolution mensuelle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendDot(Colors.green, 'Recettes'),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.red, 'Dépenses'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.2 : 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = months[groupIndex];
                      final label = rodIndex == 0 ? 'Recettes' : 'Dépenses';
                      return BarTooltipItem(
                        '$month\n$label\n${_fmt(rod.toY)} F',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(months[idx],
                              style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(months.length, (i) {
                  final month = months[i];
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: _monthlyRecettes[month] ?? 0,
                        color: Colors.green,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: _monthlyDepenses[month] ?? 0,
                        color: Colors.red,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCategoryCard() {
    final total = _categoryExpenses.values.fold(0.0, (s, v) => s + v);
    final entries = _categoryExpenses.entries.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top catégories de dépenses',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...List.generate(entries.length, (i) {
            final entry = entries[i];
            final pct = total > 0 ? entry.value / total : 0.0;
            final color = _categoryColors[i % _categoryColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      Text(
                        '${_fmt(entry.value)} F  (${(pct * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 7,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}