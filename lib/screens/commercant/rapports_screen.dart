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
import '../../widgets/screenshot_wrapper.dart';

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

  // Emojis catégories
  final Map<String, String> _categoryEmojis = {
    'alimentation': '🍽️',
    'transport': '🚗',
    'stock': '📦',
    'loyer': '🏠',
    'santé': '💊',
    'eau': '💡',
    'électricité': '💡',
    'téléphone': '📱',
  };

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
      _allTransactions = await _transactionService
          .getTransactionsByCommercant(_currentUser!.id);
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
      list = list
          .where((t) =>
              t.date.isAfter(_dateRange!.start) &&
              t.date.isBefore(_dateRange!.end.add(const Duration(days: 1))))
          .toList();
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
    _montantMinController.text =
        _montantMin > 0 ? _montantMin.toStringAsFixed(0) : '';
    _montantMaxController.text =
        _montantMax != double.infinity ? _montantMax.toStringAsFixed(0) : '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: const Row(
          children: [
            Text('💰', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text('Filtrer par montant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montantMinController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Montant minimum (FCFA)',
                labelStyle: const TextStyle(fontSize: 15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _montantMaxController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Montant maximum (FCFA)',
                labelStyle: const TextStyle(fontSize: 15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
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
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _montantMin = double.tryParse(_montantMinController.text) ?? 0;
                  _montantMax =
                      double.tryParse(_montantMaxController.text) ?? double.infinity;
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
              Text('🔃', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Text('Trier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  title: const Text('Du plus récent au plus ancien',
                      style: TextStyle(fontSize: 14)),
                  value: _sortDescending,
                  activeColor: AppColors.primaryGreen,
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
                child: const Text('Fermer', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
      BuildContext ctx, StateSetter setLocal, String label, String value) {
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
          color: selected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : Colors.grey[200]!,
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
                  color: selected ? AppColors.primaryGreen : Colors.black87,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 22),
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
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _pdfExportService.exportRapportTransactions(
        transactions: _filteredTransactions,
        user: _currentUser!,
        dateDebut: _dateRange?.start ??
            DateTime.now().subtract(const Duration(days: 30)),
        dateFin: _dateRange?.end ?? DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double v) =>
      NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

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

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalRecettes = _filteredTransactions
        .where((t) => t.estRecette)
        .fold(0.0, (s, t) => s + t.montant);
    final totalDepenses = _filteredTransactions
        .where((t) => !t.estRecette)
        .fold(0.0, (s, t) => s + t.montant);
    final solde = totalRecettes - totalDepenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                // Zone filtres
                _buildFilterSection(),

                // Résumé rapide
                _buildSummaryBar(totalRecettes, totalDepenses, solde),

                // Barre d'actions
                _buildActionBar(),

                // Tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primaryGreen,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 14),
                    tabs: const [
                      Tab(text: '📋 Liste'),
                      Tab(text: '📊 Graphique'),
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

  // ─── FILTRES ────────────────────────────────────────────────────────────────
  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: '🔍  Rechercher...',
              hintStyle: const TextStyle(fontSize: 15, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // Chips filtres — défilables
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Période
                _buildFilterPill(
                  emoji: '📅',
                  label: _dateRange != null
                      ? '${DateFormat('dd/MM').format(_dateRange!.start)} → ${DateFormat('dd/MM').format(_dateRange!.end)}'
                      : 'Période',
                  active: _dateRange != null,
                  onTap: _selectDateRange,
                ),
                const SizedBox(width: 8),

                // Montant
                _buildFilterPill(
                  emoji: '💰',
                  label: 'Montant',
                  active: _montantMin > 0 || _montantMax != double.infinity,
                  onTap: _showMontantFilter,
                ),
                const SizedBox(width: 8),

                // Type : Tous / Recettes / Dépenses
                ..._buildTypeFilters(),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Catégorie
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey[50],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategorie,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                items: [
                  const DropdownMenuItem(
                    value: 'Toutes',
                    child: Text('🏷️  Toutes les catégories'),
                  ),
                  ..._categories.map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text('${_getCatEmoji(c)}  $c'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedCategorie = v!);
                  _applyFilters();
                },
              ),
            ),
          ),

          // Compteur résultats
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

  Widget _buildFilterPill({
    required String emoji,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? AppColors.primaryGreen : Colors.grey[300]!,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: active ? AppColors.primaryGreen : Colors.grey[700],
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeFilters() {
    final types = [
      ('Tous', '📋'),
      ('Recettes', '📈'),
      ('Dépenses', '📉'),
    ];
    return types.map((item) {
      final label = item.$1;
      final emoji = item.$2;
      final selected = _selectedType == label;
      Color activeColor = AppColors.primaryGreen;
      if (label == 'Recettes') activeColor = const Color(0xFF2E7D32);
      if (label == 'Dépenses') activeColor = const Color(0xFFC62828);

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
              color: selected ? activeColor.withValues(alpha: 0.12) : Colors.grey[100],
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? activeColor : Colors.grey[300]!,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? activeColor : Colors.grey[700],
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

  // ─── RÉSUMÉ ─────────────────────────────────────────────────────────────────
  Widget _buildSummaryBar(double recettes, double depenses, double solde) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          _buildSummaryCell('📈', _fmt(recettes), 'Reçu', const Color(0xFF2E7D32)),
          _buildCellDivider(),
          _buildSummaryCell('📉', _fmt(depenses), 'Dépensé', const Color(0xFFC62828)),
          _buildCellDivider(),
          _buildSummaryCell(
            solde >= 0 ? '✅' : '⚠️',
            _fmt(solde.abs()),
            'Solde',
            solde >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCell(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '$value F',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCellDivider() =>
      Container(width: 1, height: 50, color: Colors.grey[200]);

  // ─── BARRE ACTIONS ───────────────────────────────────────────────────────────
  Widget _buildActionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          // Export PDF
          Expanded(
            child: _buildActionButton(
              emoji: '📄',
              label: 'Exporter PDF',
              color: Colors.red,
              onTap: _filteredTransactions.isEmpty ? null : _exportPDF,
            ),
          ),
          const SizedBox(width: 8),

          // Trier
          Expanded(
            child: _buildActionButton(
              emoji: '🔃',
              label: 'Trier',
              color: AppColors.primaryGreen,
              onTap: _showSortDialog,
            ),
          ),
          const SizedBox(width: 8),

          // Reset
          Expanded(
            child: _buildActionButton(
              emoji: '🔄',
              label: 'Réinitialiser',
              color: _hasActiveFilters ? Colors.orange : Colors.grey,
              onTap: _hasActiveFilters ? _resetFilters : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: disabled ? Colors.grey[100] : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled ? Colors.grey[200]! : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 16, color: disabled ? Colors.grey : null)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: disabled ? Colors.grey[400] : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LISTE TRANSACTIONS ──────────────────────────────────────────────────────
  Widget _buildTransactionList() {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Aucune transaction trouvée',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Changez les filtres pour voir\nd\'autres résultats.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('🔄 Réinitialiser les filtres',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icône type
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: t.estRecette
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      t.estRecette ? '📈' : '📉',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Description + date + catégorie
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.description ?? t.categorie,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(t.date),
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$catEmoji ${t.categorie}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Montant
                Text(
                  '${t.estRecette ? '+' : '-'}${_fmt(t.montant)} F',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: t.estRecette
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── VUE GRAPHIQUE ───────────────────────────────────────────────────────────
  Widget _buildChartView(double totalRecettes, double totalDepenses) {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📊', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Aucune donnée à afficher',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
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

    final nbRecettes =
        _filteredTransactions.where((t) => t.estRecette).length;
    final nbDepenses =
        _filteredTransactions.where((t) => !t.estRecette).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        children: [
          // Mini stats — 3 chiffres
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '${_filteredTransactions.length}',
                  'Total',
                  '📋',
                  AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  '$nbRecettes',
                  'Reçus',
                  '📈',
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  '$nbDepenses',
                  'Dépensés',
                  '📉',
                  const Color(0xFFC62828),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Graphique linéaire
          if (spots.length > 1)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('📈', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 10),
                      Text(
                        'Évolution du solde',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
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
                            color: AppColors.primaryGreen,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                            ),
                            dotData: FlDotData(
                              show: spots.length <= 10,
                              getDotPainter: (spot, _, __, ___) =>
                                  FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval:
                                  (spots.length / 5).ceilToDouble(),
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= sortedKeys.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    sortedKeys[i],
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(
                              color: Color(0xFFF5F5F5), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) =>
                                spots.map((s) {
                              final i = s.x.toInt();
                              final date = i < sortedKeys.length
                                  ? sortedKeys[i]
                                  : '';
                              return LineTooltipItem(
                                '$date\n${_fmt(s.y)} F',
                                const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
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

          // Barre répartition recettes vs dépenses
          if (totalRecettes > 0 || totalDepenses > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
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
                        'Répartition de la sélection',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Légende haut
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📈 ${_fmt(totalRecettes)} F',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        '📉 ${_fmt(totalDepenses)} F',
                        style: const TextStyle(
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Barre bicolore — plus épaisse
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        if (totalRecettes > 0)
                          Expanded(
                            flex: (totalRecettes /
                                    (totalRecettes + totalDepenses) *
                                    100)
                                .round(),
                            child: Container(
                                height: 22,
                                color: const Color(0xFF2E7D32)),
                          ),
                        if (totalDepenses > 0)
                          Expanded(
                            flex: (totalDepenses /
                                    (totalRecettes + totalDepenses) *
                                    100)
                                .round(),
                            child: Container(
                                height: 22,
                                color: const Color(0xFFC62828)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Pourcentages
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(totalRecettes / (totalRecettes + totalDepenses) * 100).toStringAsFixed(0)}% reçu',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(totalDepenses / (totalRecettes + totalDepenses) * 100).toStringAsFixed(0)}% dépensé',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Mini stat card ──────────────────────────────────────────────────────────
  Widget _buildMiniStat(
      String value, String label, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }
}