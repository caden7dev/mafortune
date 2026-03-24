import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/custom_bottom_nav.dart';
import 'nouvelle_transaction_screen.dart';
import 'bilans_screen.dart';
import 'rapports_screen.dart';
import 'alertes_screen.dart';
import 'profil_screen.dart';
import 'theme_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  UtilisateurModel? _currentUser;
  List<TransactionModel> _recentTransactions = [];
  Map<String, dynamic> _quickStats = {};
  List<Map<String, dynamic>> _weekData = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  // ✅ Liste des écrans
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildDashboardContent(), // Accueil
      const BilansScreen(), // Bilans
      const RapportsScreen(), // Rapports
      const AlertesScreen(), // Alertes
      const ProfilScreen(), // Profil
    ];
    print('🚀 INIT DashboardScreen');
    _loadData();
  }

  // ✅ Recharger quand on change d'onglet vers Accueil
  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex == 0 && !_isLoading) {
      print('🔄 didUpdateWidget - Rechargement Accueil');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }
  }

  Future<void> _loadData() async {
    print('\n🔄 ========================================');
    print('🔄 DÉBUT CHARGEMENT DASHBOARD');
    print('🔄 Timestamp: ${DateTime.now()}');
    print('🔄 ========================================');
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _recentTransactions = [];
        _weekData = [];
        _quickStats = {};
      });
      print('✅ État reset - isLoading = true');
    }

    try {
      // 1. Charger l'utilisateur
      print('\n👤 === CHARGEMENT UTILISATEUR ===');
      _currentUser = await _authService.getCurrentUserData();
      
      if (_currentUser == null) {
        print('❌ Utilisateur NULL - Arrêt du chargement\n');
        return;
      }
      
      print('✅ Utilisateur chargé:');
      print('   - Nom: ${_currentUser!.nomComplet}');
      print('   - ID: ${_currentUser!.id}');
      print('   - Solde: ${_currentUser!.soldeActuel ?? 0} FCFA');

      // 2. Charger les statistiques du jour
      print('\n📊 === CHARGEMENT STATS DU JOUR ===');
      final stats = await _transactionService.getQuickStats(_currentUser!.id);
      
      print('📊 Stats reçues du service:');
      print('   - todayIncome: ${stats['todayIncome']}');
      print('   - todayExpense: ${stats['todayExpense']}');
      print('   - todayTransactionsCount: ${stats['todayTransactionsCount']}');
      
      if (mounted) {
        setState(() {
          _quickStats = stats;
        });
        print('✅ Stats appliquées au state:');
        print('   - _quickStats[todayIncome] = ${_quickStats['todayIncome']}');
        print('   - _quickStats[todayExpense] = ${_quickStats['todayExpense']}');
      }
      
      // 3. Charger TOUTES les transactions
      print('\n📋 === CHARGEMENT TRANSACTIONS ===');
      final allTransactions = await _transactionService.getTransactionsByCommercant(_currentUser!.id);
      
      print('📦 Transactions chargées: ${allTransactions.length}');
      
      if (allTransactions.isEmpty) {
        print('⚠️ AUCUNE TRANSACTION TROUVÉE !');
        print('   Vérifiez:');
        print('   1. Que des transactions existent dans Firestore');
        print('   2. Que le commercantId est correct');
        print('   3. Les règles Firestore autorisent la lecture');
      }
      
      // 4. Trier par date de création (plus récentes en premier)
      allTransactions.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
      
      // 5. Prendre 10 transactions récentes
      const int maxRecentTransactions = 10;
      final recent = allTransactions.take(maxRecentTransactions).toList();
      
      print('\n✅ Top ${recent.length} transactions récentes:');
      for (var i = 0; i < recent.length; i++) {
        final t = recent[i];
        print('   ${i + 1}. ${t.description ?? t.categorie}');
        print('      Montant: ${t.montant} FCFA');
        print('      Type: ${t.estRecette ? "RECETTE" : "DÉPENSE"}');
        print('      Date création: ${t.dateCreation}');
        print('      Date transaction: ${t.date}');
      }
      
      if (mounted) {
        setState(() {
          _recentTransactions = recent;
        });
        print('\n✅ Transactions appliquées au state:');
        print('   - _recentTransactions.length = ${_recentTransactions.length}');
      }
      
      // 6. Charger le graphique
      print('\n📈 === CHARGEMENT GRAPHIQUE ===');
      await _loadWeekData(allTransactions);
      
      // 7. Forcer un dernier setState pour être sûr
      if (mounted) {
        setState(() {});
        print('✅ setState final forcé');
      }
      
      print('\n✅ ========================================');
      print('✅ CHARGEMENT TERMINÉ AVEC SUCCÈS');
      print('✅ - Stats: ${_quickStats.isNotEmpty ? "OK" : "VIDE"}');
      print('✅ - Transactions: ${_recentTransactions.length}');
      print('✅ - Graphique: ${_weekData.length} jours');
      print('✅ ========================================\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ========================================');
      print('❌ ERREUR CHARGEMENT DASHBOARD');
      print('❌ ========================================');
      print('❌ Erreur: $e');
      print('❌ Stack: $stackTrace');
      print('❌ ========================================\n');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('✅ isLoading = false\n');
      }
    }
  }

  Future<void> _loadWeekData(List<TransactionModel> allTransactions) async {
    final now = DateTime.now();
    final weekData = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      double recettes = 0;
      double depenses = 0;

      for (var t in allTransactions) {
        if (t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay)) {
          if (t.estRecette) {
            recettes += t.montant;
          } else {
            depenses += t.montant;
          }
        }
      }

      final jourNom = DateFormat('EEE', 'fr_FR').format(date);

      weekData.add({
        'jour': jourNom.substring(0, 3).toUpperCase(),
        'recettes': recettes,
        'depenses': depenses,
        'date': date,
      });
    }

    if (mounted) setState(() => _weekData = weekData);
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  String _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    if (categoryLower.contains('vente')) return '💰';
    if (categoryLower.contains('achat') || categoryLower.contains('stock')) return '🛒';
    if (categoryLower.contains('transport')) return '🚗';
    if (categoryLower.contains('service')) return '🔧';
    if (categoryLower.contains('loyer')) return '🏠';
    if (categoryLower.contains('salaire')) return '👨‍💼';
    if (categoryLower.contains('electricite') || categoryLower.contains('électricité')) return '💡';
    return '📊';
  }

  Future<void> _supprimerTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer cette transaction de ${_formatAmount(transaction.montant)} FCFA ?\n\n'
          'Description: ${transaction.description ?? transaction.categorie}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await _transactionService.deleteTransaction(
          transaction.id,
          transaction.commercantId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Transaction supprimée'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _modifierTransaction(TransactionModel transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NouvelleTransactionScreen(
          isRecette: transaction.estRecette,
          transactionToEdit: transaction,
        ),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 BUILD Dashboard - isLoading: $_isLoading, stats: ${_quickStats.isNotEmpty}, trans: ${_recentTransactions.length}');
    print('   - todayIncome: ${_quickStats['todayIncome']}');
    print('   - todayExpense: ${_quickStats['todayExpense']}');
    
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ Icône de thème dans l'AppBar
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeScreen()),
              );
            },
            tooltip: 'Changer le thème',
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildDashboardContent() : _screens[_currentIndex],
      // ✅ Utilisation de CustomBottomNav réutilisable
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          print('📱 Bottom Nav tap: $index (ancien: $_currentIndex)');
          
          if (index == 0 && _currentIndex != 0) {
            print('🔄 Retour sur Accueil - Rechargement des données...');
            setState(() => _currentIndex = index);
            Future.delayed(const Duration(milliseconds: 100), () {
              _loadData();
            });
          } else {
            setState(() => _currentIndex = index);
          }
        },
      ),
      floatingActionButton: _currentIndex == 0 && !_isLoading
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primaryGreen,
              onPressed: () async {
                print('\n🧪 === TEST MANUEL DÉCLENCHÉ ===');
                await _loadData();
                print('🧪 Test terminé\n');
              },
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('❌ Utilisateur non connecté'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGreen,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: Text('👤', style: TextStyle(fontSize: 32))),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser!.nomComplet,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_currentUser!.typeActivite ?? 'Commerçant'} • ${_currentUser!.adresse ?? ""}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solde actuel', style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('📈', style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text('Recettes aujourd\'hui', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('+${_formatAmount(_quickStats['todayIncome'] ?? 0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('📉', style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text('Dépenses aujourd\'hui', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('-${_formatAmount(_quickStats['todayExpense'] ?? 0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Nouvelle Recette',
                      icon: Icons.add,
                      color: AppColors.primaryGreen,
                      onTap: () => _ouvrirNouvelleTransaction(true),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Nouvelle Dépense',
                      icon: Icons.remove,
                      color: AppColors.expenseRed,
                      onTap: () => _ouvrirNouvelleTransaction(false),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Évolution (7 derniers jours)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () {}, child: const Text('Détails →', style: TextStyle(color: AppColors.primaryGreen))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildWeekChart(),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transactions récentes (${_recentTransactions.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () {}, child: const Text('Voir tout →', style: TextStyle(color: AppColors.primaryGreen))),
                ],
              ),
            ),
          ),

          _recentTransactions.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Text('📭', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 10),
                          Text('Aucune transaction', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final transaction = _recentTransactions[index];
                      return _buildTransactionCard(transaction);
                    },
                    childCount: _recentTransactions.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    if (_weekData.isEmpty) {
      return Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📊', style: TextStyle(fontSize: 48)),
              SizedBox(height: 10),
              Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final maxValue = _weekData.fold<double>(0, (max, day) {
      final recettes = day['recettes'] as double;
      final depenses = day['depenses'] as double;
      return recettes > max ? recettes : (depenses > max ? depenses : max);
    });

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _weekData.map((day) {
          final recettes = day['recettes'] as double;
          final depenses = day['depenses'] as double;
          final heightRecettes = maxValue > 0 ? (recettes / maxValue) * 120 : 0.0;
          final heightDepenses = maxValue > 0 ? (depenses / maxValue) * 120 : 0.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 18,
                    height: heightRecettes.clamp(2, 120),
                    decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: heightDepenses.clamp(2, 120),
                    decoration: BoxDecoration(color: AppColors.expenseRed, borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(day['jour'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _ouvrirNouvelleTransaction(bool isRecette) async {
    print('\n➕ === NOUVELLE ${isRecette ? "RECETTE" : "DÉPENSE"} ===');
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => NouvelleTransactionScreen(isRecette: isRecette),
      ),
    );

    print('🔙 Retour nouvelle transaction: result=$result');
    
    if (result == true) {
      print('🔄 Rechargement dashboard après transaction...');
      await _loadData();
      print('✅ Dashboard rechargé\n');
    } else {
      print('❌ Pas de rechargement (annulé ou échec)\n');
    }
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final timeStr = DateFormat('HH:mm').format(transaction.dateCreation);
    final dateStr = DateFormat('dd/MM/yyyy').format(transaction.date);
    final isToday = transaction.dateCreation.day == DateTime.now().day &&
        transaction.dateCreation.month == DateTime.now().month &&
        transaction.dateCreation.year == DateTime.now().year;

    final displayDate = isToday
        ? 'Aujourd\'hui, $timeStr'
        : transaction.dateCreation.day == DateTime.now().day - 1
            ? 'Hier, $timeStr'
            : dateStr;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: transaction.estRecette ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(_getCategoryIcon(transaction.categorie), style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description ?? transaction.categorie,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(displayDate, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Text(
                '${transaction.estRecette ? '+' : '-'}${_formatAmount(transaction.montant)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: transaction.estRecette ? Colors.green.shade600 : Colors.red.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _modifierTransaction(transaction),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _supprimerTransaction(transaction),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Supprimer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}