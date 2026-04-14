import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _RapportsScreenState extends State<RapportsScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  final PdfExportService _pdfExportService = PdfExportService();
  
  UtilisateurModel? _currentUser;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = true;
  
  // Filtres avancés
  DateTimeRange? _dateRange;
  String _selectedType = 'Tous';
  String _selectedCategorie = 'Toutes';
  String _searchQuery = '';
  double _montantMin = 0;
  double _montantMax = double.infinity;
  String _sortBy = 'date';
  bool _sortDescending = true;
  
  List<String> _categories = [];
  
  // Contrôleurs
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _montantMinController = TextEditingController();
  final TextEditingController _montantMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _montantMinController.dispose();
    _montantMaxController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text;
    _applyFilters();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _currentUser = await _authService.getCurrentUserData();
      if (_currentUser == null) return;
      
      _allTransactions = await _transactionService.getTransactionsByCommercant(_currentUser!.id);
      _applyFilters();
    } catch (e) {
      print('Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .where('estActive', isEqualTo: true)
          .get();
      
      _categories = snapshot.docs.map((doc) => doc['nom'] as String).toList();
      setState(() {});
    } catch (e) {
      print('Erreur chargement catégories: $e');
    }
  }

  void _applyFilters() {
    var filtered = List<TransactionModel>.from(_allTransactions);
    
    // 1. Filtre par date
    if (_dateRange != null) {
      filtered = filtered.where((t) {
        return t.date.isAfter(_dateRange!.start) && 
               t.date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    
    // 2. Filtre par type
    if (_selectedType != 'Tous') {
      filtered = filtered.where((t) => 
        t.estRecette ? _selectedType == 'Recettes' : _selectedType == 'Dépenses'
      ).toList();
    }
    
    // 3. Filtre par catégorie
    if (_selectedCategorie != 'Toutes') {
      filtered = filtered.where((t) => t.categorie == _selectedCategorie).toList();
    }
    
    // 4. Filtre par recherche (description)
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final description = (t.description ?? t.categorie).toLowerCase();
        return description.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // 5. Filtre par montant min
    if (_montantMin > 0) {
      filtered = filtered.where((t) => t.montant >= _montantMin).toList();
    }
    
    // 6. Filtre par montant max
    if (_montantMax != double.infinity && _montantMax > 0) {
      filtered = filtered.where((t) => t.montant <= _montantMax).toList();
    }
    
    // 7. Tri
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'date':
          comparison = a.date.compareTo(b.date);
          break;
        case 'montant':
          comparison = a.montant.compareTo(b.montant);
          break;
        case 'type':
          comparison = a.estRecette.toString().compareTo(b.estRecette.toString());
          break;
        default:
          comparison = a.date.compareTo(b.date);
      }
      return _sortDescending ? -comparison : comparison;
    });
    
    setState(() => _filteredTransactions = filtered);
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
    );
    
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

  Future<void> _showMontantFilterDialog() async {
    _montantMinController.text = _montantMin > 0 ? _montantMin.toString() : '';
    _montantMaxController.text = _montantMax != double.infinity ? _montantMax.toString() : '';
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrer par montant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montantMinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant minimum (FCFA)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montantMaxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant maximum (FCFA)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _montantMin = double.tryParse(_montantMinController.text) ?? 0;
                _montantMax = double.tryParse(_montantMaxController.text) ?? double.infinity;
              });
              _applyFilters();
              Navigator.pop(context);
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
      builder: (context) => AlertDialog(
        title: const Text('Trier par'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Date'),
              value: 'date',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Montant'),
              value: 'montant',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Type (Recette/Dépense)'),
              value: 'type',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Ordre décroissant'),
              value: _sortDescending,
              onChanged: (value) {
                setState(() => _sortDescending = value);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPDF() async {
    if (_filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune transaction à exporter'),
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
        dateDebut: _dateRange?.start ?? DateTime.now().subtract(const Duration(days: 30)),
        dateFin: _dateRange?.end ?? DateTime.now(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final totalRecettes = _filteredTransactions.where((t) => t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
    final totalDepenses = _filteredTransactions.where((t) => !t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
    final solde = totalRecettes - totalDepenses;

    // ✅ Supprimé l'AppBar (car elle est déjà dans le parent DashboardScreen)
    // ✅ Le titre "Rapports" est géré par le parent
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                // Barre de recherche et filtres
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Recherche
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher par description...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Ligne des filtres rapides
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Filtre date
                            FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: _dateRange != null ? AppColors.primaryGreen : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(_dateRange != null 
                                      ? '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}'
                                      : 'Période'),
                                ],
                              ),
                              selected: _dateRange != null,
                              onSelected: (_) => _selectDateRange(),
                              selectedColor: AppColors.primaryGreen.withOpacity(0.1),
                            ),
                            const SizedBox(width: 8),
                            
                            // Filtre montant
                            FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.attach_money, size: 16, color: (_montantMin > 0 || _montantMax != double.infinity) ? AppColors.primaryGreen : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('Montant'),
                                ],
                              ),
                              selected: _montantMin > 0 || _montantMax != double.infinity,
                              onSelected: (_) => _showMontantFilterDialog(),
                              selectedColor: AppColors.primaryGreen.withOpacity(0.1),
                            ),
                            const SizedBox(width: 8),
                            
                            // Filtre type
                            _buildTypeChip('Tous'),
                            const SizedBox(width: 4),
                            _buildTypeChip('Recettes'),
                            const SizedBox(width: 4),
                            _buildTypeChip('Dépenses'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Filtre catégorie (Dropdown)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategorie,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                            items: [
                              const DropdownMenuItem(value: 'Toutes', child: Text('Toutes les catégories')),
                              ..._categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCategorie = value!);
                              _applyFilters();
                            },
                          ),
                        ),
                      ),
                      
                      // Indicateur de résultats
                      if (_filteredTransactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${_filteredTransactions.length} transaction${_filteredTransactions.length > 1 ? 's' : ''} trouvée${_filteredTransactions.length > 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Synthèse
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Recettes', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('+${_formatAmount(totalRecettes)} FCFA', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Dépenses', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('-${_formatAmount(totalDepenses)} FCFA', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Solde', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${solde >= 0 ? '+' : '-'}${_formatAmount(solde.abs())} FCFA', 
                              style: TextStyle(color: solde >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Boutons d'action (PDF, Tri, Réinitialiser)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Bouton Export PDF
                      TextButton.icon(
                        onPressed: _filteredTransactions.isEmpty ? null : _exportPDF,
                        icon: Icon(Icons.picture_as_pdf, color: _filteredTransactions.isEmpty ? Colors.grey : Colors.red),
                        label: Text('PDF', style: TextStyle(color: _filteredTransactions.isEmpty ? Colors.grey : Colors.red)),
                      ),
                      const SizedBox(width: 8),
                      // Bouton Tri
                      TextButton.icon(
                        onPressed: _showSortDialog,
                        icon: const Icon(Icons.sort, color: AppColors.primaryGreen),
                        label: const Text('Trier', style: TextStyle(color: AppColors.primaryGreen)),
                      ),
                      const SizedBox(width: 8),
                      // Bouton Réinitialiser
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh, color: Colors.orange),
                        label: const Text('Réinitialiser', style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
                
                // Liste des transactions
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune transaction',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              if (_dateRange != null || _selectedType != 'Tous' || _selectedCategorie != 'Toutes' || _searchQuery.isNotEmpty || _montantMin > 0 || _montantMax != double.infinity)
                                TextButton(
                                  onPressed: _resetFilters,
                                  child: const Text('Réinitialiser les filtres'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _filteredTransactions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: t.estRecette ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                  child: Icon(
                                    t.estRecette ? Icons.trending_up : Icons.trending_down,
                                    color: t.estRecette ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(t.description ?? t.categorie),
                                subtitle: Text(
                                  '${DateFormat('dd/MM/yyyy').format(t.date)} • ${t.categorie}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                trailing: Text(
                                  '${t.estRecette ? '+' : '-'} ${_formatAmount(t.montant)} FCFA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: t.estRecette ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      
    );
  }

  Widget _buildTypeChip(String label) {
    final isSelected = _selectedType == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedType = selected ? label : 'Tous');
        _applyFilters();
      },
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
    );
  }
}