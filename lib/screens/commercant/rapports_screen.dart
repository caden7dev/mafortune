import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../services/pdf_export_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

class RapportsScreen extends StatefulWidget {
  // ✅ Ajout du paramètre refreshTrigger
  final int refreshTrigger;
  const RapportsScreen({super.key, this.refreshTrigger = 0});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
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

  final Map<String, String> _categoryEmojis = {
    'alimentation': '🍽️',
    'transport': '🚗',
    'stock': '📦',
    'loyer': '🏠',
    'santé': '💊',
    'eau': '💧',
    'électricité': '💡',
    'téléphone': '📱',
  };

  @override
  bool get wantKeepAlive => true;

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

  // ✅ CORRECTION : Déclenche le rechargement quand le Dashboard a fini de mettre à jour le solde
  @override
  void didUpdateWidget(RapportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadData();
    }
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
    if (_allTransactions.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    try {
      _currentUser = await _authService.getCurrentUserData();
      if (_currentUser == null) return;
      
      // ✅ APRÈS
      _allTransactions = await _transactionService.getTransactionsByCommercant(
        _currentUser!.id,
        forceRefresh: true,
      );
      _applyFilters();
    } catch (e) {
      debugPrint('Erreur rapports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('categories').get();
      List<String> fetched = snap.docs.map((d) => d['nom'] as String).toList();
      
      if (mounted) {
        setState(() {
          _categories = fetched.isEmpty 
              ? ['Alimentation', 'Transport', 'Stock', 'Loyer', 'Santé', 'Électricité', 'Téléphone', 'Autre']
              : fetched;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement catégories: $e');
      if (mounted) {
        setState(() {
          _categories = ['Alimentation', 'Transport', 'Stock', 'Loyer', 'Santé', 'Électricité', 'Téléphone', 'Autre'];
        });
      }
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
      list = list.where((t) => t.estRecette
          ? _selectedType == 'Recettes'
          : _selectedType == 'Dépenses').toList();
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

    if (_montantMin > 0) {
      list = list.where((t) => t.montant >= _montantMin).toList();
    }
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
          colorScheme: const ColorScheme.light(primary: emeraldDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _applyFilters();
      });
    }
  }

  Future<void> _showMontantFilter() async {
    _montantMinController.text = _montantMin > 0 ? _montantMin.toStringAsFixed(0) : '';
    _montantMaxController.text = _montantMax != double.infinity ? _montantMax.toStringAsFixed(0) : '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: const Row(
          children: [
            Icon(Icons.attach_money_rounded, size: 24, color: emeraldDark),
            SizedBox(width: 10),
            Text('Filtrer par montant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montantMinController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, color: textDark),
              decoration: InputDecoration(
                labelText: 'Montant minimum (FCFA)',
                labelStyle: const TextStyle(fontSize: 15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: emeraldDark, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _montantMaxController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, color: textDark),
              decoration: InputDecoration(
                labelText: 'Montant maximum (FCFA)',
                labelStyle: const TextStyle(fontSize: 15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: emeraldDark, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _montantMin = double.tryParse(_montantMinController.text) ?? 0;
                  _montantMax = double.tryParse(_montantMaxController.text) ?? double.infinity;
                });
                _applyFilters();
                Navigator.pop(ctx);
              },
              child: const Text('Appliquer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler', style: TextStyle(fontSize: 16)),
            ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.sort_rounded, size: 24, color: emeraldDark),
              SizedBox(width: 10),
              Text('Trier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption(ctx, setLocal, '📅 Par date', 'date'),
              _buildSortOption(ctx, setLocal, '💰 Par montant', 'montant'),
              _buildSortOption(ctx, setLocal, '🏷️ Par type', 'type'),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('Du plus récent au plus ancien', style: TextStyle(fontSize: 14, color: textDark)),
                  value: _sortDescending,
                  activeColor: emeraldDark,
                  onChanged: (v) {
                    setLocal(() => _sortDescending = v);
                    setState(() {});
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer', style: TextStyle(fontSize: 16, color: textDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(BuildContext ctx, StateSetter setLocal, String label, String value) {
    final selected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setLocal(() => _sortBy = value);
        setState(() {});
        _applyFilters();
        Navigator.pop(ctx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? emeraldDark.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? emeraldDark : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? emeraldDark : textDark,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: emeraldDark, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPDF() async {
    if (_filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune transaction à exporter', style: TextStyle(fontSize: 16)),
          backgroundColor: terracotta,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: brickRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double v) => NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

  String _getCatEmoji(String cat) {
    for (final key in _categoryEmojis.keys) {
      if (cat.toLowerCase().contains(key)) return _categoryEmojis[key]!;
    }
    return '📌';
  }

  bool get _hasActiveFilters =>
      _dateRange != null ||
      _selectedType != 'Tous' ||
      _selectedCategorie != 'Toutes' ||
      _searchQuery.isNotEmpty ||
      _montantMin > 0 ||
      _montantMax != double.infinity;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final totalRecettes = _filteredTransactions.where((t) => t.estRecette).fold(0.0, (s, t) => s + t.montant);
    final totalDepenses = _filteredTransactions.where((t) => !t.estRecette).fold(0.0, (s, t) => s + t.montant);
    final solde = totalRecettes - totalDepenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: emeraldDark))
          : Column(
              children: [
                _buildFilterSection(),
                _buildSummaryBar(totalRecettes, totalDepenses, solde),
                _buildActionBar(),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: emeraldDark,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: emeraldDark,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 14),
                    tabs: const [
                      Tab(text: 'Liste'),
                      Tab(text: 'Graphique'),
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

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 16, color: textDark),
            decoration: InputDecoration(
              hintText: 'Rechercher...',
              hintStyle: const TextStyle(fontSize: 15, color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill(
                  label: _dateRange != null
                      ? '${DateFormat('dd/MM').format(_dateRange!.start)} → ${DateFormat('dd/MM').format(_dateRange!.end)}'
                      : 'Période',
                  active: _dateRange != null,
                  onTap: _selectDateRange,
                  icon: Icons.calendar_today_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  label: 'Montant',
                  active: _montantMin > 0 || _montantMax != double.infinity,
                  onTap: _showMontantFilter,
                  icon: Icons.attach_money_rounded,
                ),
                const SizedBox(width: 8),
                ..._buildTypeFilters(),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategorie,
                isExpanded: true,
                hint: const Text('Choisir une catégorie', style: TextStyle(color: Colors.grey)),
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                style: const TextStyle(fontSize: 15, color: textDark, fontWeight: FontWeight.w500),
                items: [
                  const DropdownMenuItem(value: 'Toutes', child: Text('🏷️  Toutes les catégories')),
                  ..._categories.map((c) => DropdownMenuItem(value: c, child: Text('${_getCatEmoji(c)}  $c'))),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedCategorie = v);
                    _applyFilters();
                  }
                },
              ),
            ),
          ),
          if (_filteredTransactions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_filteredTransactions.length} transaction${_filteredTransactions.length > 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterPill({required String label, required bool active, required VoidCallback onTap, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? emeraldDark : Colors.grey[100],
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? emeraldDark : Colors.grey[300]!,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: active ? Colors.white : Colors.grey[700]),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: active ? Colors.white : Colors.grey[700],
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeFilters() {
    final types = ['Tous', 'Recettes', 'Dépenses'];
    return types.map((label) {
      final selected = _selectedType == label;
      Color activeColor = emeraldDark;
      if (label == 'Dépenses') activeColor = brickRed;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedType = label);
            _applyFilters();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? activeColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? activeColor : Colors.grey[300]!,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? Colors.white : Colors.grey[700],
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSummaryBar(double recettes, double depenses, double solde) {
    final isPositif = solde >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _buildSummaryCell(
            icon: Icons.arrow_upward_rounded,
            value: _fmt(recettes),
            label: 'Reçu',
            iconColor: emeraldDark,
            bgColor: emeraldDark.withOpacity(0.1),
          ),
          _buildCellDivider(),
          _buildSummaryCell(
            icon: Icons.arrow_downward_rounded,
            value: _fmt(depenses),
            label: 'Dépensé',
            iconColor: brickRed,
            bgColor: brickRed.withOpacity(0.1),
          ),
          _buildCellDivider(),
          _buildSummaryCell(
            icon: isPositif ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            value: _fmt(solde),
            label: 'Résultat',
            iconColor: isPositif ? emeraldDark : brickRed,
            bgColor: isPositif ? emeraldDark.withOpacity(0.1) : brickRed.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCell({required IconData icon, required String value, required String label, required Color iconColor, required Color bgColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              '$value F',
              style: TextStyle(fontWeight: FontWeight.bold, color: iconColor, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildCellDivider() => Container(width: 1, height: 50, color: Colors.grey[200]);

  Widget _buildActionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _filteredTransactions.isEmpty ? null : _exportPDF,
              style: ElevatedButton.styleFrom(
                backgroundColor: terracotta,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Exporter PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _showSortDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: emeraldDark,
                side: const BorderSide(color: emeraldDark, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sort_rounded, size: 18),
                  SizedBox(width: 4),
                  Text('Trier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _hasActiveFilters ? _resetFilters : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _hasActiveFilters ? textDark : Colors.grey[500],
                side: BorderSide(color: _hasActiveFilters ? textDark : Colors.grey[300]!, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 4),
                  Text('Reset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: emeraldDark,
      child: _filteredTransactions.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Aucune transaction trouvée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 8),
                        Text('Tirez vers le bas pour actualiser\nou changez les filtres.', style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _resetFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: emeraldDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _filteredTransactions.length,
              itemBuilder: (context, index) {
                final t = _filteredTransactions[index];
                final catEmoji = _getCatEmoji(t.categorie);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: t.estRecette ? emeraldDark.withOpacity(0.1) : brickRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              t.estRecette ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              color: t.estRecette ? emeraldDark : brickRed,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.description ?? t.categorie,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(DateFormat('dd/MM/yyyy').format(t.date), style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                                  const SizedBox(width: 8),
                                  Text('$catEmoji ${t.categorie}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${t.estRecette ? '+' : '-'}${_fmt(t.montant)} F',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: t.estRecette ? emeraldDark : brickRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildChartView(double totalRecettes, double totalDepenses) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: emeraldDark,
      child: _filteredTransactions.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_rounded, size: 56, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucune donnée à afficher', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat('${_filteredTransactions.length}', 'Total', Icons.receipt_long_rounded, emeraldDark)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMiniStat('${_filteredTransactions.where((t) => t.estRecette).length}', 'Reçus', Icons.arrow_upward_rounded, emeraldDark)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMiniStat('${_filteredTransactions.where((t) => !t.estRecette).length}', 'Dépensés', Icons.arrow_downward_rounded, brickRed)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
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
                      final spots = List.generate(sortedKeys.length, (i) => FlSpot(i.toDouble(), dailyData[sortedKeys[i]]!));
                      final maxY = spots.fold(0.0, (m, s) => s.y > m ? s.y : m);
                      final minY = spots.fold(0.0, (m, s) => s.y < m ? s.y : m);

                      return spots.length > 1
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.trending_up_rounded, size: 22, color: textDark),
                                      SizedBox(width: 10),
                                      Text('Évolution du résultat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 200,
                                    child: LineChart(
                                      LineChartData(
                                        minY: minY * 1.2,
                                        maxY: maxY > 0 ? maxY * 1.2 : 100,
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: spots,
                                            isCurved: true,
                                            color: emeraldDark,
                                            barWidth: 3,
                                            belowBarData: BarAreaData(show: true, color: emeraldDark.withOpacity(0.1)),
                                            dotData: FlDotData(
                                              show: spots.length <= 10,
                                              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: emeraldDark),
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
                                                  child: Text(sortedKeys[i], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF5F5F5), strokeWidth: 1)),
                                        borderData: FlBorderData(show: false),
                                        lineTouchData: LineTouchData(
                                          touchTooltipData: LineTouchTooltipData(
                                            getTooltipItems: (spots) => spots.map((s) {
                                              final i = s.x.toInt();
                                              final date = i < sortedKeys.length ? sortedKeys[i] : '';
                                              return LineTooltipItem('$date\n${_fmt(s.y)} F', const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 16),
                  if (totalRecettes > 0 || totalDepenses > 0)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pie_chart_outline_rounded, size: 22, color: textDark),
                              SizedBox(width: 10),
                              Text('Répartition de la sélection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.trending_up_rounded, color: emeraldDark, size: 18),
                                  const SizedBox(width: 6),
                                  Text('${_fmt(totalRecettes)} F', style: const TextStyle(color: emeraldDark, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.trending_down_rounded, color: brickRed, size: 18),
                                  const SizedBox(width: 6),
                                  Text('${_fmt(totalDepenses)} F', style: const TextStyle(color: brickRed, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Row(
                              children: [
                                if (totalRecettes > 0) Expanded(flex: (totalRecettes / (totalRecettes + totalDepenses) * 100).round(), child: Container(height: 22, color: emeraldDark)),
                                if (totalDepenses > 0) Expanded(flex: (totalDepenses / (totalRecettes + totalDepenses) * 100).round(), child: Container(height: 22, color: brickRed)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${(totalRecettes / (totalRecettes + totalDepenses) * 100).toStringAsFixed(0)}% reçu', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              Text('${(totalDepenses / (totalRecettes + totalDepenses) * 100).toStringAsFixed(0)}% dépensé', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }
}