import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/screenshot_wrapper.dart';

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

  // Emojis pour les catégories de dépenses
  final Map<String, String> _categoryEmojis = {
    'Alimentation': '🍽️',
    'Transport': '🚗',
    'Stock': '📦',
    'Loyer': '🏠',
    'Santé': '💊',
    'Eau/Électricité': '💡',
    'Téléphone': '📱',
    'Autre': '📌',
  };

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
      _transactions = await _transactionService
          .getTransactionsByCommercant(_currentUser!.id);
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

    final periodTx = _transactions
        .where((t) =>
            t.date.isAfter(startDate) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();

    _totalRecettes =
        periodTx.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
    _totalDepenses =
        periodTx.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);

    _monthlyRecettes.clear();
    _monthlyDepenses.clear();
    for (int i = 1; i <= 12; i++) {
      final ms = DateTime(_selectedDate.year, i, 1);
      final me = DateTime(_selectedDate.year, i + 1, 0);
      final mtx = _transactions
          .where((t) =>
              t.date.isAfter(ms) &&
              t.date.isBefore(me.add(const Duration(days: 1))))
          .toList();
      final key = DateFormat('MMM', 'fr_FR').format(ms);
      _monthlyRecettes[key] =
          mtx.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
      _monthlyDepenses[key] =
          mtx.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);
    }

    final expCat = <String, double>{};
    for (var t in periodTx.where((t) => !t.estRecette)) {
      expCat[t.categorie] = (expCat[t.categorie] ?? 0) + t.montant;
    }
    final sorted = expCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
        if (m < 1) {
          m = 12;
          y--;
        } else if (m > 12) {
          m = 1;
          y++;
        }
        _selectedDate = DateTime(y, m, 1);
      } else if (_selectedPeriod == 'trimestre') {
        var m = _selectedDate.month + (offset * 3);
        var y = _selectedDate.year;
        if (m < 1) {
          m = 12;
          y--;
        } else if (m > 12) {
          m = 1;
          y++;
        }
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
        return 'Trimestre $q — ${_selectedDate.year}';
      case 'annee':
        return 'Année ${_selectedDate.year}';
      default:
        return '';
    }
  }

  String _fmt(double v) =>
      NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

  String _getCategoryEmoji(String category) {
    for (final key in _categoryEmojis.keys) {
      if (category.toLowerCase().contains(key.toLowerCase())) {
        return _categoryEmojis[key]!;
      }
    }
    return '📌';
  }

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final solde = _totalRecettes - _totalDepenses;
    final hasData = _totalRecettes > 0 || _totalDepenses > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Sélecteur de période
                    _buildPeriodSelector(),

                    const SizedBox(height: 16),

                    // 3 grandes cartes de résumé
                    _buildSummarySection(solde),

                    const SizedBox(height: 20),

                    // Message si pas de données
                    if (!hasData) _buildEmptyState(),

                    // Graphique camembert
                    if (hasData) ...[
                      _buildPieChartCard(),
                      const SizedBox(height: 16),
                    ],

                    // Graphique barres mensuel
                    _buildBarChartCard(),

                    // Top catégories dépenses
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

  // ─── SÉLECTEUR PÉRIODE ──────────────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          // Navigation date
          Row(
            children: [
              // Bouton précédent — grand
              GestureDetector(
                onTap: () => _changeDate(-1),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chevron_left, size: 28, color: Colors.black87),
                ),
              ),

              // Titre période — centré
              Expanded(
                child: Text(
                  _getPeriodTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Bouton suivant — grand
              GestureDetector(
                onTap: () => _changeDate(1),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chevron_right, size: 28, color: Colors.black87),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Chips de période — grands et clairs
          Row(
            children: [
              Expanded(child: _buildPeriodChip('📅 Mois', 'mois')),
              const SizedBox(width: 8),
              Expanded(child: _buildPeriodChip('📆 Trimestre', 'trimestre')),
              const SizedBox(width: 8),
              Expanded(child: _buildPeriodChip('🗓️ Année', 'annee')),
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
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? null
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ─── RÉSUMÉ — 3 GRANDS CHIFFRES ─────────────────────────────────────────────
  Widget _buildSummarySection(double solde) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Solde — le chiffre le plus important, en grand
          _buildBigSoldeCard(solde),
          const SizedBox(height: 12),
          // Recettes et Dépenses côte à côte
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  emoji: '📈',
                  label: 'Argent reçu',
                  amount: _totalRecettes,
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  emoji: '📉',
                  label: 'Argent dépensé',
                  amount: _totalDepenses,
                  color: const Color(0xFFC62828),
                  bgColor: const Color(0xFFFFEBEE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigSoldeCard(double solde) {
    final isPositif = solde >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositif
              ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)]
              : [const Color(0xFFB71C1C), const Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPositif ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isPositif ? '✅' : '⚠️',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 8),
              Text(
                isPositif ? 'Vous êtes en bénéfice' : 'Vous êtes en déficit',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${solde < 0 ? '-' : ''}${_fmt(solde.abs())} FCFA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Solde de la période',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String emoji,
    required String label,
    required double amount,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          Text(
            '${_fmt(amount)} F',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  // ─── ÉTAT VIDE ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Pas de données pour cette période',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des recettes et dépenses\npour voir vos bilans ici.',
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── GRAPHIQUE CAMEMBERT ────────────────────────────────────────────────────
  Widget _buildPieChartCard() {
    final total = _totalRecettes + _totalDepenses;
    if (total == 0) return const SizedBox.shrink();

    final pctRecettes = (_totalRecettes / total * 100);
    final pctDepenses = (_totalDepenses / total * 100);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🥧', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text(
                'Répartition',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Camembert
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
                          color: const Color(0xFF2E7D32),
                          title: '${pctRecettes.toStringAsFixed(0)}%',
                          radius: _touchedPieIndex == 0 ? 75 : 62,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        PieChartSectionData(
                          value: _totalDepenses,
                          color: const Color(0xFFC62828),
                          title: '${pctDepenses.toStringAsFixed(0)}%',
                          radius: _touchedPieIndex == 1 ? 75 : 62,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      centerSpaceRadius: 40,
                      sectionsSpace: 3,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Légende
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPieLegend('📈', 'Reçu', _totalRecettes, const Color(0xFF2E7D32)),
                    const SizedBox(height: 20),
                    _buildPieLegend('📉', 'Dépensé', _totalDepenses, const Color(0xFFC62828)),
                    const SizedBox(height: 20),
                    _buildPieLegend('📊', 'Total', total, Colors.grey[700]!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend(String emoji, String label, double amount, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(
              '${_fmt(amount)} F',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── GRAPHIQUE BARRES ────────────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📊', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text(
                'Évolution sur l\'année',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Légende
          Row(
            children: [
              _buildLegendDot(const Color(0xFF2E7D32), '📈 Reçu'),
              const SizedBox(width: 20),
              _buildLegendDot(const Color(0xFFC62828), '📉 Dépensé'),
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
                      final label = rodIndex == 0 ? '📈 Reçu' : '📉 Dépensé';
                      return BarTooltipItem(
                        '$month\n$label\n${_fmt(rod.toY)} F',
                        const TextStyle(color: Colors.white, fontSize: 12),
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
                        if (idx < 0 || idx >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            months[idx],
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFF0F0F0),
                    strokeWidth: 1,
                  ),
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
                        color: const Color(0xFF2E7D32),
                        width: 9,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                      BarChartRodData(
                        toY: _monthlyDepenses[month] ?? 0,
                        color: const Color(0xFFC62828),
                        width: 9,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }

  // ─── TOP CATÉGORIES DÉPENSES ────────────────────────────────────────────────
  Widget _buildCategoryCard() {
    final total = _categoryExpenses.values.fold(0.0, (s, v) => s + v);
    final entries = _categoryExpenses.entries.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🏷️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text(
                'Où va votre argent ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(entries.length, (i) {
            final entry = entries[i];
            final pct = total > 0 ? entry.value / total : 0.0;
            final color = _categoryColors[i % _categoryColors.length];
            final emoji = _getCategoryEmoji(entry.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + montant
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_fmt(entry.value)} F',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Barre de progression — plus épaisse
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
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