import 'dart:async'; // ✅ AJOUTÉ POUR LE STREAM
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class BilansScreen extends StatefulWidget {
  final int refreshTrigger;
  const BilansScreen({super.key, this.refreshTrigger = 0});

  @override
  State<BilansScreen> createState() => _BilansScreenState();
}

class _BilansScreenState extends State<BilansScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  // ✅ NOUVEAU : Abonnement au flux de mise à jour
  StreamSubscription<void>? _transactionSub;

  UtilisateurModel? _currentUser;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  int _touchedPieIndex = -1;

  String _selectedPeriod = 'mois';
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customDateRange;

  double _totalRecettes = 0;
  double _totalDepenses = 0;
  Map<String, double> _monthlyRecettes = {};
  Map<String, double> _monthlyDepenses = {};
  Map<String, double> _categoryExpenses = {};

  final List<Color> _categoryColors = [terracotta, const Color(0xFF6B7280), const Color(0xFF3B82F6), emeraldDark, const Color(0xFFD97706)];

  final Map<String, String> _categoryEmojis = {
    'Alimentation': '🍽️', 'Transport': '🚗', 'Stock': '📦', 'Loyer': '🏠',
    'Santé': '💊', 'Eau': '💧', 'Électricité': '💡', 'Téléphone': '📱', 'Autre': '📌',
  };

  @override
  void initState() {
    super.initState();
    
    // ✅ Écoute le Service : dès qu'une transaction est ajoutée, on rafraîchit automatiquement
    _transactionSub = _transactionService.transactionUpdatedStream.listen((_) {
      debugPrint('🔄 [Bilans] Nouvelle transaction détectée, rafraîchissement en cours...');
      _loadData(force: true);
    });

    _loadData(force: true);
  }

  @override
  void dispose() {
    _transactionSub?.cancel(); // ✅ Très important pour éviter les fuites de mémoire
    super.dispose();
  }

  @override
void didUpdateWidget(BilansScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.refreshTrigger != oldWidget.refreshTrigger) {
    _loadData(force: true);
  }
}

  // ✅ CORRECTION : Ajout du paramètre 'force' pour contourner le cache
  Future<void> _loadData({bool force = false}) async {
    if (!force && _transactions.isNotEmpty) return;

    if (_transactions.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
     _currentUser = await _authService.getCurrentUserData(forceRefresh: true);
      if (_currentUser == null) return;
      
      final freshTransactions = await _transactionService.getTransactionsByCommercant(
        _currentUser!.id,
        forceRefresh: true, 
      );
      
      if (mounted) {
        setState(() {
          _transactions = freshTransactions;
          _isLoading = false;
        });
        _calculateStats(); // Recalcule les graphiques et les totaux immédiatement
      }
    } catch (e) {
      debugPrint('Erreur bilans: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    DateTime startDate;
    DateTime endDate;

    if (_selectedPeriod == 'custom' && _customDateRange != null) {
      startDate = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
      endDate = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
    } else {
      switch (_selectedPeriod) {
        case 'mois':
          startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
          endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
          break;
        case 'trimestre':
          final q = ((_selectedDate.month - 1) ~/ 3) + 1;
          final startMonth = (q - 1) * 3 + 1;
          startDate = DateTime(_selectedDate.year, startMonth, 1);
          endDate = DateTime(_selectedDate.year, startMonth + 3, 0, 23, 59, 59);
          break;
        case 'annee':
          startDate = DateTime(_selectedDate.year, 1, 1);
          endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
          break;
        default:
          startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
          endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
      }
    }

    final periodTx = _transactions.where((t) => !t.date.isBefore(startDate) && !t.date.isAfter(endDate)).toList();

    _totalRecettes = periodTx.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
    _totalDepenses = periodTx.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);

    _monthlyRecettes.clear();
    _monthlyDepenses.clear();
    for (int i = 1; i <= 12; i++) {
      final ms = DateTime(_selectedDate.year, i, 1);
      final me = DateTime(_selectedDate.year, i + 1, 0, 23, 59, 59);
      final mtx = _transactions.where((t) => !t.date.isBefore(ms) && !t.date.isAfter(me)).toList();
      final key = DateFormat('MMM', 'fr_FR').format(ms);
      _monthlyRecettes[key] = mtx.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
      _monthlyDepenses[key] = mtx.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);
    }

    final expCat = <String, double>{};
    for (var t in periodTx.where((t) => !t.estRecette)) {
      expCat[t.categorie] = (expCat[t.categorie] ?? 0) + t.montant;
    }
    final sorted = expCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _categoryExpenses = {for (var e in sorted.take(5)) e.key: e.value};

    if (mounted) setState(() {});
  }

  void _changePeriod(String p) {
    if (p == 'custom') {
      _selectCustomDateRange();
    } else {
      setState(() { _selectedPeriod = p; _calculateStats(); });
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customDateRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: emeraldDark, onPrimary: Colors.white)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() { _selectedPeriod = 'custom'; _customDateRange = picked; _calculateStats(); });
    }
  }

  void _changeDate(int offset) {
    if (_selectedPeriod == 'custom') return;
    setState(() {
      if (_selectedPeriod == 'mois') {
        var m = _selectedDate.month + offset; var y = _selectedDate.year;
        if (m < 1) { m = 12; y--; } else if (m > 12) { m = 1; y++; }
        _selectedDate = DateTime(y, m, 1);
      } else if (_selectedPeriod == 'trimestre') {
        var m = _selectedDate.month + (offset * 3); var y = _selectedDate.year;
        if (m < 1) { m = 12; y--; } else if (m > 12) { m = 1; y++; }
        _selectedDate = DateTime(y, m, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year + offset, 1, 1);
      }
      _calculateStats();
    });
  }

  String _getPeriodTitle() {
    switch (_selectedPeriod) {
      case 'mois': return DateFormat('MMMM yyyy', 'fr_FR').format(_selectedDate);
      case 'trimestre':
        final q = ((_selectedDate.month - 1) ~/ 3) + 1;
        return 'Trimestre $q — ${_selectedDate.year}';
      case 'annee': return 'Année ${_selectedDate.year}';
      case 'custom':
        if (_customDateRange == null) return 'Période sur mesure';
        return '${DateFormat('dd/MM').format(_customDateRange!.start)} au ${DateFormat('dd/MM/yyyy').format(_customDateRange!.end)}';
      default: return '';
    }
  }

  String _fmt(double v) => NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

  String _getCategoryEmoji(String category) {
    for (final key in _categoryEmojis.keys) {
      if (category.toLowerCase().contains(key.toLowerCase())) return _categoryEmojis[key]!;
    }
    return '📌';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final soldeGlobal = _currentUser?.soldeActuel ?? 0.0;
    final resultatPeriode = _totalRecettes - _totalDepenses;
    final hasData = _totalRecettes > 0 || _totalDepenses > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading && _transactions.isEmpty
          ? const Center(child: CircularProgressIndicator(color: emeraldDark))
          : RefreshIndicator(
              onRefresh: () => _loadData(force: true), 
              color: emeraldDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),
                    _buildSummarySection(soldeGlobal),
                    const SizedBox(height: 14),
                    _buildConseilCard(resultatPeriode),
                    const SizedBox(height: 20),
                    if (!hasData) _buildEmptyState(),
                    if (hasData) ...[_buildPieChartCard(), const SizedBox(height: 16)],
                    _buildBarChartCard(),
                    if (_categoryExpenses.isNotEmpty) ...[const SizedBox(height: 16), _buildCategoryCard()],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _selectedPeriod == 'custom' ? null : () => _changeDate(-1),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _selectedPeriod == 'custom' ? Colors.grey[200] : const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.chevron_left_rounded, size: 28, color: _selectedPeriod == 'custom' ? Colors.grey : textDark),
                ),
              ),
              Expanded(
                child: Text(_getPeriodTitle(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
              ),
              GestureDetector(
                onTap: _selectedPeriod == 'custom' ? null : () => _changeDate(1),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _selectedPeriod == 'custom' ? Colors.grey[200] : const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.chevron_right_rounded, size: 28, color: _selectedPeriod == 'custom' ? Colors.grey : textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('Mois', 'mois'), const SizedBox(width: 8),
                _buildPeriodChip('Trimestre', 'trimestre'), const SizedBox(width: 8),
                _buildPeriodChip('Année', 'annee'), const SizedBox(width: 8),
                _buildPeriodChip('Sur mesure', 'custom'),
              ],
            ),
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
        duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? emeraldDark : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? emeraldDark : Colors.grey.shade300, width: selected ? 1.5 : 1),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade700, fontWeight: selected ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildConseilCard(double solde) {
    String message = "";
    IconData icon = Icons.lightbulb_outline;
    Color color = terracotta;

    if (_totalRecettes == 0 && _totalDepenses == 0) {
      message = "Aucune opération enregistrée pour cette période.";
      icon = Icons.info_outline; color = Colors.grey.shade600;
    } else if (solde >= 0) {
      double ratio = _totalRecettes > 0 ? (_totalDepenses / _totalRecettes) * 100 : 0;
      if (ratio < 50) {
        message = "Excellente gestion ! Vos dépenses ne représentent que ${ratio.toStringAsFixed(0)}% de vos recettes.";
        icon = Icons.stars_rounded; color = terracotta;
      } else {
        message = "Vous êtes bénéficiaire, mais vos dépenses absorbent ${ratio.toStringAsFixed(0)}% de vos revenus.";
        icon = Icons.trending_up_rounded; color = emeraldDark;
      }
    } else {
      message = "Attention : Vos dépenses dépassent vos ventes sur cette période.";
      icon = Icons.warning_amber_rounded; color = brickRed;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: textDark.withOpacity(0.8), height: 1.3, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildSummarySection(double solde) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildBigSoldeCard(solde),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(icon: Icons.arrow_upward_rounded, label: 'Argent reçu', amount: _totalRecettes, iconColor: emeraldDark, bgColor: emeraldDark.withOpacity(0.1))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(icon: Icons.arrow_downward_rounded, label: 'Argent dépensé', amount: _totalDepenses, iconColor: brickRed, bgColor: brickRed.withOpacity(0.1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigSoldeCard(double solde) {
    final isPositif = solde >= 0;
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isPositif ? [const Color(0xFF0B4F36), const Color(0xFF0D5F41)] : [const Color(0xFF7F1D1D), const Color(0xFF9B2C2C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: (isPositif ? emeraldDark : brickRed).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPositif ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(isPositif ? 'Vous êtes en bénéfice' : 'Vous êtes en déficit', style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${solde < 0 ? '-' : ''}${_fmt(solde.abs())} FCFA', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 4),
          Text('Solde actuel du compte', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required double amount, required Color iconColor, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, child: Text('${_fmt(amount)} F', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor))),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: iconColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Pas de données pour cette période', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Ajoutez des recettes et dépenses\npour voir vos bilans ici.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPieChartCard() {
    final total = _totalRecettes + _totalDepenses;
    if (total == 0) return const SizedBox.shrink();

    final pctRecettes = (_totalRecettes / total * 100);
    final pctDepenses = (_totalDepenses / total * 100);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.pie_chart_outline_rounded, size: 22, color: textDark), SizedBox(width: 10), Text('Répartition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark))]),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(touchCallback: (event, response) { setState(() { _touchedPieIndex = response?.touchedSection?.touchedSectionIndex ?? -1; }); }),
                      sections: [
                        PieChartSectionData(value: _totalRecettes, color: emeraldDark, title: '${pctRecettes.toStringAsFixed(0)}%', radius: _touchedPieIndex == 0 ? 70 : 58, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        PieChartSectionData(value: _totalDepenses, color: brickRed, title: '${pctDepenses.toStringAsFixed(0)}%', radius: _touchedPieIndex == 1 ? 70 : 58, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                      centerSpaceRadius: 36, sectionsSpace: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPieLegend(Icons.arrow_upward_rounded, 'Reçu', _totalRecettes, emeraldDark),
                    const SizedBox(height: 16),
                    _buildPieLegend(Icons.arrow_downward_rounded, 'Dépensé', _totalDepenses, brickRed),
                    const SizedBox(height: 16),
                    _buildPieLegend(Icons.analytics_rounded, 'Total', total, textDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend(IconData icon, String label, double amount, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            Text('${_fmt(amount)} F', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChartCard() {
    final months = _monthlyRecettes.keys.toList();
    final maxVal = [..._monthlyRecettes.values, ..._monthlyDepenses.values].fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.bar_chart_rounded, size: 22, color: textDark), SizedBox(width: 10), Text('Évolution sur l\'année', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark))]),
          const SizedBox(height: 16),
          Row(children: [_buildLegendDot(emeraldDark, 'Reçu'), const SizedBox(width: 20), _buildLegendDot(brickRed, 'Dépensé')]),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround, maxY: maxVal > 0 ? maxVal * 1.2 : 100, barTouchData: BarTouchData(enabled: true),
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
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(months[idx], style: const TextStyle(fontSize: 10, color: Colors.grey)));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(months.length, (i) {
                  final month = months[i];
                  return BarChartGroupData(
                    x: i, barsSpace: 3,
                    barRods: [
                      BarChartRodData(toY: _monthlyRecettes[month] ?? 0, color: emeraldDark, width: 7, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      BarChartRodData(toY: _monthlyDepenses[month] ?? 0, color: brickRed, width: 7, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
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
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500))]);
  }

  Widget _buildCategoryCard() {
    final total = _categoryExpenses.values.fold(0.0, (s, v) => s + v);
    final entries = _categoryExpenses.entries.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.category_rounded, size: 22, color: textDark), SizedBox(width: 10), Text('Où va votre argent ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark))]),
          const SizedBox(height: 20),
          ...List.generate(entries.length, (i) {
            final entry = entries[i];
            final pct = total > 0 ? entry.value / total : 0.0;
            final color = _categoryColors[i % _categoryColors.length];
            final emoji = _getCategoryEmoji(entry.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark))),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_fmt(entry.value)} F', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                          Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color)),
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