import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import 'modifier_transaction_screen.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

class HistoriqueCompletScreen extends StatefulWidget {
  final String commercantId;

  const HistoriqueCompletScreen({super.key, required this.commercantId});

  @override
  State<HistoriqueCompletScreen> createState() => _HistoriqueCompletScreenState();
}

class _HistoriqueCompletScreenState extends State<HistoriqueCompletScreen> {
  final TransactionService _transactionService = TransactionService();

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = true;
  String _filterType = 'TOUT';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTransactions({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final list = await _transactionService.getTransactionsByCommercant(
        widget.commercantId,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _allTransactions = list;
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement historique: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _allTransactions.where((t) {
        final matchesType = _filterType == 'TOUT' ||
            (_filterType == 'RECETTE' && t.estRecette) ||
            (_filterType == 'DEPENSE' && !t.estRecette);

        final query = _searchQuery.toLowerCase();
        final matchesSearch = query.isEmpty ||
            (t.description?.toLowerCase().contains(query) ?? false) ||
            t.categorie.toLowerCase().contains(query) ||
            t.montant.toString().contains(query);

        return matchesType && matchesSearch;
      }).toList();
    });
  }

  String _formatAmount(double amount) =>
      NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('vente')) return Icons.payments_rounded;
    if (lower.contains('achat') || lower.contains('stock')) return Icons.shopping_cart_rounded;
    if (lower.contains('transport')) return Icons.directions_car_rounded;
    if (lower.contains('service')) return Icons.build_rounded;
    if (lower.contains('loyer')) return Icons.home_rounded;
    if (lower.contains('salaire')) return Icons.people_rounded;
    if (lower.contains('electricite') || lower.contains('électricité')) return Icons.bolt_rounded;
    return Icons.receipt_long_rounded;
  }

  void _afficherOptionsTransaction(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding:  EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poignée de drag
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Titre de la transaction
            Text(
              transaction.description ?? transaction.categorie,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  transaction.estRecette ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: transaction.estRecette ? emeraldDark : brickRed,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${transaction.estRecette ? '+' : '-'}${_formatAmount(transaction.montant)} FCFA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: transaction.estRecette ? emeraldDark : brickRed,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd/MM/yyyy • HH:mm').format(transaction.date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Bouton Modifier
            _buildOptionButton(
              icon: Icons.edit_rounded,
              label: 'Modifier l\'opération',
              color: emeraldDark,
              onTap: () async {
                Navigator.pop(context);
                final res = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ModifierTransactionSheet(transaction: transaction),
                );
                if (res == true) _loadAllTransactions(forceRefresh: true);
              },
            ),
            
            const SizedBox(height: 12),
            
            // Bouton Supprimer
            _buildOptionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer l\'opération',
              color: brickRed,
              isDestructive: true,
              onTap: () async {
                Navigator.pop(context);
                await _confirmerSuppression(transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmerSuppression(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: brickRed.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, size: 40, color: brickRed),
            ),
            const SizedBox(height: 16),
            const Text(
              'Supprimer cette transaction ?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Montant : ${_formatAmount(transaction.montant)} FCFA\nCette action est irréversible.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brickRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Oui, supprimer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textDark,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _transactionService.deleteTransaction(transaction.id, transaction.commercantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Transaction supprimée', style: TextStyle(fontSize: 15)),
              backgroundColor: emeraldDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          await _loadAllTransactions(forceRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: $e', style: const TextStyle(fontSize: 15)),
              backgroundColor: brickRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? brickRed : textDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Historique (${_allTransactions.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche harmonisée
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              style: const TextStyle(fontSize: 15, color: textDark),
              decoration: InputDecoration(
                hintText: 'Rechercher une opération, un montant...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _applyFilters();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filtres (Tout / Recettes / Dépenses) harmonisés
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(child: _buildFilterChip('Tout', 'TOUT', Icons.receipt_long_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterChip('Ventes', 'RECETTE', Icons.arrow_upward_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterChip('Dépenses', 'DEPENSE', Icons.arrow_downward_rounded)),
              ],
            ),
          ),

          // Liste complète des transactions
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: emeraldDark))
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucune transaction trouvée',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Modifiez vos filtres ou votre recherche',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadAllTransactions(forceRefresh: true),
                        color: emeraldDark,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _filteredTransactions[index];
                            return _buildTransactionCard(t);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterType == value;
    Color activeColor = emeraldDark;
    if (value == 'DEPENSE') activeColor = brickRed;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildTransactionCard(TransactionModel transaction) {
    final timeStr = DateFormat('HH:mm').format(transaction.date);
    final dateStr = DateFormat('dd/MM/yyyy').format(transaction.date);
    final now = DateTime.now();
    final isToday = transaction.date.year == now.year && transaction.date.month == now.month && transaction.date.day == now.day;
    final isYesterday = transaction.date.day == now.day - 1 && transaction.date.month == now.month && transaction.date.year == now.year;

    final displayDate = isToday ? 'Aujourd\'hui, $timeStr' : (isYesterday ? 'Hier, $timeStr' : '$dateStr à $timeStr');

    String displayDescription = transaction.description ?? transaction.categorie;
    if (displayDescription == 'Vente rapide') displayDescription = 'Vente';
    if (displayDescription == 'Dépense rapide') displayDescription = 'Dépense';

    // ✅ GestureDetector garantit que le clic sur TOUTE la carte fonctionne parfaitement
    return GestureDetector(
      onTap: () => _afficherOptionsTransaction(transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: transaction.estRecette ? emeraldDark : brickRed, width: 4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: transaction.estRecette ? emeraldDark.withOpacity(0.1) : brickRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(transaction.categorie),
                  color: transaction.estRecette ? emeraldDark : brickRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayDescription,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(displayDate, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${transaction.estRecette ? '+' : '-'}${_formatAmount(transaction.montant)} F',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: transaction.estRecette ? emeraldDark : brickRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Petite flèche pour indiquer visuellement que la carte est cliquable
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}