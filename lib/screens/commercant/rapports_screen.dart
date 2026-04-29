import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../services/pdf_export_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';

class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  final PdfExportService _pdfExportService = PdfExportService();

  late TabController _tabController;

  UtilisateurModel? _currentUser;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = true;

  DateTimeRange? _dateRange;
  String _selectedType = 'Tous';
  String _selectedCategorie = 'Toutes';
  String _searchQuery = '';
  double _montantMin = 0;
  double _montantMax = double.infinity;
  String _sortBy = 'date';
  bool _sortDescending = true;

  List<String> _categories = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _montantMinController = TextEditingController();
  final TextEditingController _montantMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _loadCategories();
    _searchController.addListener(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _montantMinController.dispose();
    _montantMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _authService.getCurrentUserData();
      if (_currentUser == null) return;
      _allTransactions =
          await _transactionService.getTransactionsByCommercant(_currentUser!.id);
      _applyFilters();
    } catch (e) {
      debugPrint('Erreur rapports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .where('estActive', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _categories = snap.docs.map((d) => d['nom'] as String).toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur catégories: $e');
    }
  }

  void _applyFilters() {
    var list = List<TransactionModel>.from(_allTransactions);

    if (_dateRange != null) {
      list = list.where((t) =>
          t.date.isAfter(_dateRange!.start) &&
          t.date.isBefore(_dateRange!.end.add(const Duration(days: 1)))).toList();
    }

    if (_selectedType != 'Tous') {
      list = list
          .where((t) => t.estRecette
              ? _selectedType == 'Recettes'
              : _selectedType == 'Dépenses')
          .toList();
    }

    if (_selectedCategorie != 'Toutes') {
      list = list.where((t) => t.categorie == _selectedCategorie).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((t) {
        final desc = (t.description ?? t.categorie).toLowerCase();
        return desc.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_montantMin > 0) list = list.where((t) => t.montant >= _montantMin).toList();
    if (_montantMax != double.infinity && _montantMax > 0) {
      list = list.where((t) => t.montant <= _montantMax).toList();
    }

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'montant':
          cmp = a.montant.compareTo(b.montant);
          break;
        case 'type':
          cmp = a.estRecette.toString().compareTo(b.estRecette.toString());
          break;
        default:
          cmp = a.date.compareTo(b.date);
      }
      return _sortDescending ? -cmp : cmp;
    });

    setState(() => _filteredTransactions = list);
  }

  void _resetFilters() {
    setState(() {
      _dateRange = null;
      _selectedType = 'Tous';
      _selectedCategorie = 'Toutes';
      _searchQuery = '';
      _searchController.clear();
      _montantMin = 0;
      _montantMax = double.infinity;
      _montantMinController.clear();
      _montantMaxController.clear();
      _sortBy = 'date';
      _sortDescending = true;
    });
    _applyFilters();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

  Future<void> _showMontantFilter() async {
    _montantMinController.text = _montantMin > 0 ? _montantMin.toStringAsFixed(0) : '';
    _montantMaxController.text =
        _montantMax != double.infinity ? _montantMax.toStringAsFixed(0) : '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filtrer par montant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montantMinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Montant minimum (FCFA)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montantMaxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Montant maximum (FCFA)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () {
              setState(() {
                _montantMin = double.tryParse(_montantMinController.text) ?? 0;
                _montantMax =
                    double.tryParse(_montantMaxController.text) ?? double.infinity;
              });
              _applyFilters();
              Navigator.pop(ctx);
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSortDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Trier par'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortRadio(ctx, setLocal, 'Date', 'date'),
              _buildSortRadio(ctx, setLocal, 'Montant', 'montant'),
              _buildSortRadio(ctx, setLocal, 'Type', 'type'),
              const Divider(),
              SwitchListTile(
                title: const Text('Ordre décroissant'),
                value: _sortDescending,
                activeColor: AppColors.primaryGreen,
                onChanged: (v) {
                  setLocal(() => _sortDescending = v);
                  setState(() {});
                  _applyFilters();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }

  Widget _buildSortRadio(
      BuildContext ctx, StateSetter setLocal, String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _sortBy,
      activeColor: AppColors.primaryGreen,
      onChanged: (v) {
        setLocal(() => _sortBy = v!);
        setState(() {});
        _applyFilters();
        Navigator.pop(ctx);
      },
    );
  }

  Future<void> _exportPDF() async {
    if (_filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucune transaction à exporter'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _pdfExportService.exportRapportTransactions(
        transactions: _filteredTransactions,
        user: _currentUser!,
        dateDebut: _dateRange?.start ?? DateTime.now().subtract(const Duration(days: 30)),
        dateFin: _dateRange?.end ?? DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur export: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double v) =>
      NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

  @override
  Widget build(BuildContext context) {
    final totalRecettes =
        _filteredTransactions.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
    final totalDepenses =
        _filteredTransactions.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);
    final solde = totalRecettes - totalDepenses;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                // Filtres
                _buildFilterBar(),

                // Synthèse
                _buildSummaryBar(totalRecettes, totalDepenses, solde),

                // Boutons action
                _buildActionBar(),

                // Tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primaryGreen,
                    tabs: const [
                      Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Liste'),
                      Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Graphique'),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionList(),
                      _buildChartView(totalRecettes, totalDepenses),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par description...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  icon: Icons.calendar_today,
                  label: _dateRange != null
                      ? '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}'
                      : 'Période',
                  active: _dateRange != null,
                  onTap: _selectDateRange,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  icon: Icons.attach_money,
                  label: 'Montant',
                  active: _montantMin > 0 || _montantMax != double.infinity,
                  onTap: _showMontantFilter,
                ),
                const SizedBox(width: 8),
                ..._buildTypeChips(),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[50],
              ),
              child: DropdownButton<String>(
                value: _selectedCategorie,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                items: [
                  const DropdownMenuItem(value: 'Toutes', child: Text('Toutes les catégories')),
                  ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) {
                  setState(() => _selectedCategorie = v!);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_filteredTransactions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_filteredTransactions.length} transaction${_filteredTransactions.length > 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      {required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGreen.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.primaryGreen : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? AppColors.primaryGreen : Colors.grey[600]),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.primaryGreen : Colors.grey[700],
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeChips() {
    return ['Tous', 'Recettes', 'Dépenses'].map((label) {
      final selected = _selectedType == label;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedType = label);
            _applyFilters();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? (label == 'Recettes'
                      ? Colors.green.withOpacity(0.15)
                      : label == 'Dépenses'
                          ? Colors.red.withOpacity(0.15)
                          : AppColors.primaryGreen.withOpacity(0.1))
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected
                      ? (label == 'Recettes'
                          ? Colors.green
                          : label == 'Dépenses'
                              ? Colors.red
                              : AppColors.primaryGreen)
                      : Colors.grey[300]!),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? (label == 'Recettes'
                            ? Colors.green
                            : label == 'Dépenses'
                                ? Colors.red
                                : AppColors.primaryGreen)
                        : Colors.grey[700],
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSummaryBar(double recettes, double depenses, double solde) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _buildSummaryItem('+${_fmt(recettes)}', 'Recettes', Colors.green),
          _buildDivider(),
          _buildSummaryItem('-${_fmt(depenses)}', 'Dépenses', Colors.red),
          _buildDivider(),
          _buildSummaryItem(
            '${solde >= 0 ? '+' : '-'}${_fmt(solde.abs())}',
            'Solde',
            solde >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      Container(width: 1, height: 36, color: Colors.grey[200]);

  Widget _buildActionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _filteredTransactions.isEmpty ? null : _exportPDF,
            icon: Icon(Icons.picture_as_pdf,
                color: _filteredTransactions.isEmpty ? Colors.grey : Colors.red,
                size: 18),
            label: Text('PDF',
                style: TextStyle(
                    color: _filteredTransactions.isEmpty ? Colors.grey : Colors.red)),
          ),
          TextButton.icon(
            onPressed: _showSortDialog,
            icon: const Icon(Icons.sort, color: AppColors.primaryGreen, size: 18),
            label: const Text('Trier', style: TextStyle(color: AppColors.primaryGreen)),
          ),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh, color: Colors.orange, size: 18),
            label: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Aucune transaction', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 8),
            TextButton(onPressed: _resetFilters, child: const Text('Réinitialiser les filtres')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final t = _filteredTransactions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: t.estRecette
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                t.estRecette ? Icons.trending_up : Icons.trending_down,
                color: t.estRecette ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(t.description ?? t.categorie,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy').format(t.date)} • ${t.categorie}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            trailing: Text(
              '${t.estRecette ? '+' : '-'}${_fmt(t.montant)} F',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: t.estRecette ? Colors.green : Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartView(double totalRecettes, double totalDepenses) {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Aucune donnée', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    // Grouper par jour pour le graphique linéaire
    final Map<String, double> dailyData = {};
    for (var t in _filteredTransactions) {
      final key = DateFormat('dd/MM').format(t.date);
      if (t.estRecette) {
        dailyData[key] = (dailyData[key] ?? 0) + t.montant;
      } else {
        dailyData[key] = (dailyData[key] ?? 0) - t.montant;
      }
    }

    final sortedKeys = dailyData.keys.toList()..sort();
    final spots = List.generate(sortedKeys.length, (i) {
      return FlSpot(i.toDouble(), dailyData[sortedKeys[i]]!);
    });

    final maxY = spots.fold(0.0, (m, s) => s.y > m ? s.y : m);
    final minY = spots.fold(0.0, (m, s) => s.y < m ? s.y : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mini stats cards
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                    '${_filteredTransactions.length}', 'Transactions', Icons.receipt_long, AppColors.primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                    '${_filteredTransactions.where((t) => t.estRecette).length}',
                    'Recettes',
                    Icons.trending_up,
                    Colors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                    '${_filteredTransactions.where((t) => !t.estRecette).length}',
                    'Dépenses',
                    Icons.trending_down,
                    Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Graphique linéaire évolution
          if (spots.length > 1)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Évolution du solde net',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        minY: minY * 1.2,
                        maxY: maxY * 1.2,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.primaryGreen,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primaryGreen.withOpacity(0.1),
                            ),
                            dotData: FlDotData(
                              show: spots.length <= 10,
                              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (spots.length / 5).ceilToDouble(),
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= sortedKeys.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(sortedKeys[i],
                                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              const FlLine(color: Color(0xFFF5F5F5), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots.map((s) {
                              final i = s.x.toInt();
                              final date = i < sortedKeys.length ? sortedKeys[i] : '';
                              return LineTooltipItem(
                                '$date\n${_fmt(s.y)} F',
                                TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: s.y >= 0 ? FontWeight.w600 : FontWeight.normal),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Répartition recettes vs dépenses
          if (totalRecettes > 0 || totalDepenses > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Répartition de la sélection',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('${_fmt(totalRecettes)} F',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const Text('Recettes',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              if (totalRecettes > 0)
                                Expanded(
                                  flex: (totalRecettes /
                                          (totalRecettes + totalDepenses) *
                                          100)
                                      .round(),
                                  child: Container(height: 20, color: Colors.green),
                                ),
                              if (totalDepenses > 0)
                                Expanded(
                                  flex: (totalDepenses /
                                          (totalRecettes + totalDepenses) *
                                          100)
                                      .round(),
                                  child: Container(height: 20, color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('${_fmt(totalDepenses)} F',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                                textAlign: TextAlign.right),
                            const Text('Dépenses',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.right),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}