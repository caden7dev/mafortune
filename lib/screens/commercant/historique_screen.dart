import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre (Sécurité, Structure, Recettes)
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux (Dépenses, Alertes)
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé (lisibilité)

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
      backgroundColor: const Color(0xFFF8F9FA), // Fond gris très clair et doux
      appBar: AppBar(
        // ✅ 1. BANDEAU SUPÉRIEUR : Vert Émeraude Sombre
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Historique', // Texte épuré sans émoji
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: emeraldDark))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: emeraldDark,
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
            style: const TextStyle(fontSize: 16, color: textDark),
            decoration: InputDecoration(
              hintText: 'Rechercher une transaction...',
              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
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
              Expanded(child: _buildFiltreBtn('Tout', 'tous')),
              const SizedBox(width: 8),
              Expanded(child: _buildFiltreBtn('Reçu', 'recettes')),
              const SizedBox(width: 8),
              Expanded(child: _buildFiltreBtn('Dépensé', 'depenses')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltreBtn(String label, String value) {
    final selected = _filtre == value;
    
    // ✅ 1. FILTRE ACTIF : Vert Émeraude pour 'tous' et 'recettes', Rouge Brique pour 'depenses'
    Color activeColor = emeraldDark;
    if (value == 'depenses') activeColor = brickRed;

    return GestureDetector(
      onTap: () => _setFiltre(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? activeColor : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
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
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Nombre de transactions
            Text(
              '${_filtered.length} opération${_filtered.length > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            // ✅ 3. MONTANTS POSITIFS : Vert Émeraude Sombre pour un contraste fort
            Text(
              '+${_fmt(recettes)} F',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: emeraldDark,
              ),
            ),
            const SizedBox(width: 14),
            // ✅ 3. MONTANTS NÉGATIFS : Rouge Brique adouci (plus de rose fluo)
            Text(
              '-${_fmt(depenses)} F',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: brickRed,
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
              color: textDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }

  // ─── CARTE TRANSACTION ────────────────────────────────────────────────────────
  Widget _buildTransactionCard(TransactionModel t) {
    final isRecette = t.estRecette;
    
    // ✅ 2. ICÔNES SYSTÈME ÉPURÉES AVEC FOND À 10% D'OPACITÉ
    final IconData iconData = isRecette ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final Color iconColor = isRecette ? emeraldDark : brickRed;
    final Color iconBgColor = isRecette ? emeraldDark.withOpacity(0.1) : brickRed.withOpacity(0.1);
    
    final label = t.description?.isNotEmpty == true ? t.description! : t.categorie;
    final heure = DateFormat('HH:mm').format(t.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ✅ Cercle icône harmonisé (plus d'émoji générique)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(iconData, color: iconColor, size: 24),
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
                      color: textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        t.categorie,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '• $heure',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ✅ Montant avec la couleur correspondante (Emerald ou BrickRed)
            Text(
              '${isRecette ? '+' : '-'}${_fmt(t.montant)} F',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
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
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.receipt_long_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              isSearching ? 'Aucun résultat' : 'Aucune transaction',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Essayez un autre mot ou changez le filtre.'
                  : 'Vos transactions apparaîtront ici après les avoir saisies.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
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
                  backgroundColor: emeraldDark, // ✅ Bouton harmonisé
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Réinitialiser les filtres',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
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