import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import 'modifier_transaction_screen.dart';

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
  String _filterType = 'TOUT'; // 'TOUT', 'RECETTE', 'DEPENSE'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllTransactions();
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

  String _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('vente')) return '💰';
    if (lower.contains('achat') || lower.contains('stock')) return '🛒';
    if (lower.contains('transport')) return '🚗';
    if (lower.contains('service')) return '🔧';
    if (lower.contains('loyer')) return '🏠';
    if (lower.contains('salaire')) return '👨‍💼';
    return '📊';
  }

  void _afficherOptionsTransaction(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.description ?? transaction.categorie,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_formatAmount(transaction.montant)} FCFA • ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              title: const Text('Modifier l\'opération'),
              onTap: () async {
                Navigator.pop(context);
                final res = await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ModifierTransactionSheet(transaction: transaction),
                );
                if (res != null) _loadAllTransactions(forceRefresh: true);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.delete, color: Colors.white, size: 20),
              ),
              title: const Text('Supprimer l\'opération', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _transactionService.deleteTransaction(transaction.id, transaction.commercantId);
                _loadAllTransactions(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique (${_allTransactions.length})'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 🔍 Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher une opération, un montant...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // 🏷️ Filtres (Tout / Recettes / Dépenses)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterChip('Tout', 'TOUT'),
              const SizedBox(width: 8),
              _buildFilterChip('Ventes 💰', 'RECETTE'),
              const SizedBox(width: 8),
              _buildFilterChip('Dépenses 🛒', 'DEPENSE'),
            ],
          ),
          const Divider(height: 20),

          // 📋 Liste complète des transactions
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : _filteredTransactions.isEmpty
                    ? const Center(child: Text('Aucune transaction trouvée'))
                    : RefreshIndicator(
                        onRefresh: () => _loadAllTransactions(forceRefresh: true),
                        child: ListView.builder(
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _filteredTransactions[index];
                            final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(t.date);

                            return ListTile(
                              leading: Text(_getCategoryIcon(t.categorie), style: const TextStyle(fontSize: 24)),
                              title: Text(t.description ?? t.categorie, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                              trailing: Text(
                                '${t.estRecette ? '+' : '-'}${_formatAmount(t.montant)} F',
                                style: TextStyle(
                                  color: t.estRecette ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              onTap: () => _afficherOptionsTransaction(t),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
      onSelected: (selected) {
        if (selected) {
          _filterType = value;
          _applyFilters();
        }
      },
    );
  }
}