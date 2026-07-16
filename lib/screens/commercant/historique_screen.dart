import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filtered = [];
  bool _isLoading = true;

  // Filtre actif : 'tous', 'recettes', 'depenses'
  String _filtre = 'tous';

  // Recherche
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Map<String, String> _catEmojis = {
    'alimentation': '🍽️',
    'transport': '🚗',
    'stock': '📦',
    'loyer': '🏠',
    'santé': '💊',
    'eau': '💡',
    'électricité': '💡',
    'téléphone': '📱',
    'salaire': '💵',
    'vente': '🛒',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final txs = await _transactionService.getTransactionsByCommercant(user.uid);
      // Plus récentes en premier
      txs.sort((a, b) => b.date.compareTo(a.date));
      _allTransactions = txs;
      _applyFilters();
    } catch (e) {
      debugPrint('Erreur historique: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var list = List<TransactionModel>.from(_allTransactions);

    // Filtre type
    if (_filtre == 'recettes') {
      list = list.where((t) => t.estRecette).toList();
    } else if (_filtre == 'depenses') {
      list = list.where((t) => !t.estRecette).toList();
    }

    // Filtre recherche
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final desc = (t.description ?? t.categorie).toLowerCase();
        final cat = t.categorie.toLowerCase();
        return desc.contains(q) || cat.contains(q);
      }).toList();
    }

    setState(() => _filtered = list);
  }

  void _setFiltre(String f) {
    setState(() => _filtre = f);
    _applyFilters();
  }

  String _fmt(double v) =>
      NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

  String _getCatEmoji(String cat) {
    for (final key in _catEmojis.keys) {
      if (cat.toLowerCase().contains(key)) return _catEmojis[key]!;
    }
    return '📌';
  }

  // Grouper les transactions par date (aujourd'hui, hier, date)
  String _groupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return "Aujourd'hui";
    if (d == today.subtract(const Duration(days: 1))) return 'Hier';
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
  }

  // Construire la liste groupée par jour
  List<_ListItem> _buildGroupedList() {
    final items = <_ListItem>[];
    String? lastGroup;

    for (final t in _filtered) {
      final label = _groupLabel(t.date);
      if (label != lastGroup) {
        items.add(_ListItem.header(label));
        lastGroup = label;
      }
      items.add(_ListItem.transaction(t));
    }
    return items;
  }

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalRecettes = _filtered
        .where((t) => t.estRecette)
        .fold(0.0, (s, t) => s + t.montant);
    final totalDepenses = _filtered
        .where((t) => !t.estRecette)
        .fold(0.0, (s, t) => s + t.montant);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '📋 Historique',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryGreen,
              child: Column(
                children: [
                  // ── Barre filtres + recherche ──────────────────────────────
                  _buildTopBar(),

                  // ── Mini résumé ────────────────────────────────────────────
                  if (_filtered.isNotEmpty)
                    _buildSummaryBar(totalRecettes, totalDepenses),

                  // ── Liste ──────────────────────────────────────────────────
                  Expanded(
                    child: _filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildList(),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── BARRE FILTRES ───────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          // Recherche
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: '🔍  Rechercher une transaction...',
              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // Filtres type — 3 boutons larges
          Row(
            children: [
              Expanded(child: _buildFiltreBtn('📋', 'Tout', 'tous')),
              const SizedBox(width: 8),
              Expanded(child: _buildFiltreBtn('📈', 'Reçu', 'recettes')),
              const SizedBox(width: 8),
              Expanded(child: _buildFiltreBtn('📉', 'Dépensé', 'depenses')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltreBtn(String emoji, String label, String value) {
    final selected = _filtre == value;
    Color activeColor = AppColors.primaryGreen;
    if (value == 'recettes') activeColor = const Color(0xFF2E7D32);
    if (value == 'depenses') activeColor = const Color(0xFFC62828);

    return GestureDetector(
      onTap: () => _setFiltre(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RÉSUMÉ RAPIDE ───────────────────────────────────────────────────────────
  Widget _buildSummaryBar(double recettes, double depenses) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Nombre de transactions
            Text(
              '${_filtered.length} opération${_filtered.length > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Spacer(),
            // Recettes
            Text(
              '+${_fmt(recettes)} F',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 14),
            // Dépenses
            Text(
              '-${_fmt(depenses)} F',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC62828),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LISTE GROUPÉE ───────────────────────────────────────────────────────────
  Widget _buildList() {
    final items = _buildGroupedList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) return _buildDayHeader(item.label!);
        return _buildTransactionCard(item.transaction!);
      },
    );
  }

  // ─── EN-TÊTE JOUR ────────────────────────────────────────────────────────────
  Widget _buildDayHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        ],
      ),
    );
  }

  // ─── CARTE TRANSACTION ────────────────────────────────────────────────────────
  Widget _buildTransactionCard(TransactionModel t) {
    final isRecette = t.estRecette;
    final emoji = isRecette ? '📈' : _getCatEmoji(t.categorie);
    final color =
        isRecette ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final bgColor =
        isRecette ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final label = t.description?.isNotEmpty == true ? t.description! : t.categorie;
    final heure = DateFormat('HH:mm').format(t.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Cercle emoji
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),

            const SizedBox(width: 14),

            // Description + catégorie + heure
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
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
                        '🏷️ ${t.categorie}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '🕐 $heure',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Montant
            Text(
              '${isRecette ? '+' : '-'}${_fmt(t.montant)} F',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ÉTAT VIDE ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty || _filtre != 'tous';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSearching ? '🔍' : '📋',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching
                  ? 'Aucun résultat'
                  : 'Aucune transaction',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Essayez un autre mot\nou changez le filtre.'
                  : 'Vos transactions apparaîtront\nici après les avoir saisies.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  _setFiltre('tous');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('🔄 Tout afficher',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Modèle interne pour la liste groupée ────────────────────────────────────
class _ListItem {
  final bool isHeader;
  final String? label;
  final TransactionModel? transaction;

  _ListItem.header(this.label)
      : isHeader = true,
        transaction = null;

  _ListItem.transaction(this.transaction)
      : isHeader = false,
        label = null;
}