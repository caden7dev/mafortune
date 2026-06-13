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
import 'notifications_screen.dart';
import 'profil_screen.dart';
import 'theme_screen.dart';
import '../../widgets/offline_banner.dart';

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

  String _getTitle() {
    switch (_currentIndex) {
      case 0: return 'Tableau de bord';
      case 1: return 'Bilans';
      case 2: return 'Rapports';
      case 3: return 'Notifications';
      case 4: return 'Profil';
      default: return 'Tableau de bord';
    }
  }

  String _getInitial() {
    if (_currentUser == null) return '?';
    final name = _currentUser!.nomComplet;
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex == 0 && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _recentTransactions = [];
        _weekData = [];
        _quickStats = {};
      });
    }

    try {
      _currentUser = await _authService.getCurrentUserData();
      if (_currentUser == null) return;

      final stats = await _transactionService.getQuickStats(_currentUser!.id);
      if (mounted) setState(() => _quickStats = stats);

      final allTransactions = await _transactionService
          .getTransactionsByCommercant(_currentUser!.id);
      allTransactions.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      if (mounted) setState(() => _recentTransactions = allTransactions.take(10).toList());

      await _loadWeekData(allTransactions);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeekData(List<TransactionModel> allTransactions) async {
    final now = DateTime.now();
    final weekData = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      double recettes = 0, depenses = 0;
      for (var t in allTransactions) {
        if (t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay)) {
          if (t.estRecette) recettes += t.montant;
          else depenses += t.montant;
        }
      }

      weekData.add({
        'jour': DateFormat('EEE', 'fr_FR').format(date).substring(0, 3).toUpperCase(),
        'recettes': recettes,
        'depenses': depenses,
        'date': date,
      });
    }

    if (mounted) setState(() => _weekData = weekData);
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
    if (lower.contains('electricite') || lower.contains('électricité')) return '💡';
    return '📊';
  }

  Future<void> _supprimerTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer cette transaction de '
          '${_formatAmount(transaction.montant)} FCFA ?\n\n'
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
            transaction.id, transaction.commercantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Transaction supprimée'),
              backgroundColor: AppColors.success));
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
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
    if (result == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.palette),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ThemeScreen())),
              tooltip: 'Changer le thème',
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildDashboardContent(),
                const BilansScreen(),
                const RapportsScreen(),
                const NotificationsScreen(),
                const ProfilScreen(),
              ],
            ),
          ),
        ],
      ),
      // ✅ AJOUT DE LA BARRE DE NAVIGATION
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            Future.delayed(
                const Duration(milliseconds: 100), () => _loadData());
          }
        },
      ),
      floatingActionButton: _currentIndex == 0 && !_isLoading
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primaryGreen,
              onPressed: _loadData,
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildDashboardContent() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }

    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('❌ Utilisateur non connecté'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
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
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top > 0 ? 16 : 40,
                20,
                24,
              ),
              child: Column(
                children: [
                  // Avatar + nom
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: _currentUser!.photo != null &&
                                  _currentUser!.photo!.isNotEmpty
                              ? Image.network(
                                  _currentUser!.photo!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(_getInitial(),
                                        style: const TextStyle(
                                            fontSize: 28, color: Colors.white)),
                                  ),
                                )
                              : Center(
                                  child: Text(_getInitial(),
                                      style: const TextStyle(
                                          fontSize: 28, color: Colors.white)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser!.nomComplet,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_currentUser!.typeActivite ?? 'Commerçant'}'
                              '${_currentUser!.adresse != null && _currentUser!.adresse!.isNotEmpty ? ' • ${_currentUser!.adresse}' : ''}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Carte solde + stats
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solde actuel',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('📈',
                                          style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Recettes auj.',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.85),
                                              fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '+${_formatAmount(_quickStats['todayIncome'] ?? 0)} F',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.3),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('📉',
                                          style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Dépenses auj.',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.85),
                                              fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '-${_formatAmount(_quickStats['todayExpense'] ?? 0)} F',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
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
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(width: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Évolution (7 derniers jours)',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Détails →',
                            style: TextStyle(color: AppColors.primaryGreen)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildWeekChart(),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transactions récentes (${_recentTransactions.length})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Voir tout →',
                        style: TextStyle(color: AppColors.primaryGreen)),
                  ),
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
                          Text('Aucune transaction',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildTransactionCard(_recentTransactions[index]),
                    childCount: _recentTransactions.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    final theme = Theme.of(context);

    if (_weekData.isEmpty) {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📊', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Aucune donnée',
                  style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      );
    }

    final maxValue = _weekData.fold<double>(0, (max, day) {
      final r = day['recettes'] as double;
      final d = day['depenses'] as double;
      return r > max ? r : (d > max ? d : max);
    });

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _weekData.map((day) {
          final recettes = day['recettes'] as double;
          final depenses = day['depenses'] as double;
          final hR = maxValue > 0 ? (recettes / maxValue) * 110 : 0.0;
          final hD = maxValue > 0 ? (depenses / maxValue) * 110 : 0.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 16,
                    height: hR.clamp(2, 110),
                    decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 16,
                    height: hD.clamp(2, 110),
                    decoration: BoxDecoration(
                        color: AppColors.expenseRed,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(day['jour'] as String,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _ouvrirNouvelleTransaction(bool isRecette) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => NouvelleTransactionScreen(isRecette: isRecette)),
    );
    if (result == true) await _loadData();
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('HH:mm').format(transaction.dateCreation);
    final dateStr = DateFormat('dd/MM/yyyy').format(transaction.date);
    final now = DateTime.now();
    final isToday = transaction.dateCreation.year == now.year &&
        transaction.dateCreation.month == now.month &&
        transaction.dateCreation.day == now.day;
    final isYesterday = transaction.dateCreation.day == now.day - 1 &&
        transaction.dateCreation.month == now.month &&
        transaction.dateCreation.year == now.year;

    final displayDate = isToday
        ? 'Aujourd\'hui, $timeStr'
        : isYesterday
            ? 'Hier, $timeStr'
            : dateStr;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: transaction.estRecette
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(_getCategoryIcon(transaction.categorie),
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description ?? transaction.categorie,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(displayDate,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${transaction.estRecette ? '+' : '-'}${_formatAmount(transaction.montant)} F',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: transaction.estRecette
                            ? Colors.green.shade600
                            : Colors.red.shade600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _modifierTransaction(transaction),
                  icon: const Icon(Icons.edit, size: 15),
                  label: const Text('Modifier', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side:
                          const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _supprimerTransaction(transaction),
                  icon: const Icon(Icons.delete, size: 15),
                  label:
                      const Text('Supprimer', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}