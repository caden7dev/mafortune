import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/offline_banner.dart';
import 'saisie_rapide_screen.dart';
import 'modifier_transaction_screen.dart';
import 'historique_complet_screen.dart';
import 'bilans_screen.dart';
import 'rapports_screen.dart';
import 'notifications_screen.dart';
import 'profil_screen.dart';
import 'theme_screen.dart';
import '../../services/tts_service.dart';
import '../../services/bilan_notification_service.dart';

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
      case 0: return 'Accueil';
      case 1: return 'Bilans';
      case 2: return 'Rapports';
      case 3: return 'Notifications';
      case 4: return 'Mon profil';
      default: return 'Accueil';
    }
  }

  String _getInitial() {
    if (_currentUser == null) return '?';
    final name = _currentUser!.nomComplet;
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  String _getPrenom() {
    if (_currentUser == null) return '';
    final parts = _currentUser!.nomComplet.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : _currentUser!.nomComplet;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Ne pas afficher de spinner de chargement si des données existent déjà (fluidité)
    if (_currentUser == null) {
      setState(() => _isLoading = true);
    }

    try {
      _currentUser = await _authService.getCurrentUserData(
        forceRefresh: forceRefresh,
      );
      if (_currentUser == null) return;

      final results = await Future.wait([
        _transactionService.getQuickStats(_currentUser!.id, forceRefresh: forceRefresh),
        _transactionService.getTransactionsByCommercant(_currentUser!.id, forceRefresh: forceRefresh),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final allTransactions = results[1] as List<TransactionModel>;

      allTransactions.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      if (mounted) {
        setState(() {
          _quickStats = stats;
          _recentTransactions = List<TransactionModel>.from(allTransactions.take(10));
        });
      }

      await _loadWeekData(allTransactions);

      if (BilanNotificationService.launchedFromBilan) {
        BilanNotificationService.launchedFromBilan = false;
        final recettes = (stats['todayIncome'] ?? 0).toDouble();
        final depenses = (stats['todayExpense'] ?? 0).toDouble();
        await Future.delayed(const Duration(milliseconds: 600));
        TtsService().bilanDuJour(recettes, depenses);
      }
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

  Future<void> _ouvrirSaisie({required bool isVente}) async {
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaisieRapideScreen(isVenteInitial: isVente),
    );

    if (result != null) {
      _loadData(forceRefresh: true);
    }
  }

  void _afficherOptionsTransaction(TransactionModel transaction) {
    HapticFeedback.selectionClick();
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
              onTap: () {
                Navigator.pop(context);
                _modifierTransaction(transaction);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.delete, color: Colors.white, size: 20),
              ),
              title: const Text('Supprimer l\'opération', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _supprimerTransaction(transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _modifierTransaction(TransactionModel transaction) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModifierTransactionSheet(transaction: transaction),
    );

    if (result != null) {
      await _loadData(forceRefresh: true);
    }
  }

  Future<void> _supprimerTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Supprimer cette transaction de ${_formatAmount(transaction.montant)} FCFA ?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Oui, supprimer', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _transactionService.deleteTransaction(
            transaction.id, transaction.commercantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Transaction supprimée'),
              backgroundColor: AppColors.success));
          await _loadData(forceRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
        }
      }
    }
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
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ThemeScreen())),
              tooltip: 'Thème',
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            // ⚡ IndexedStack préserve le contenu de chaque onglet sans rechargement
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildDashboardContent(),
                const BilansScreen(),
                const RapportsScreen(),
                const NotificationsScreen(),
                ProfilScreen(preloadedUser: _currentUser),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Navigation fluide et instantanée
          setState(() => _currentIndex = index);
        },
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _ouvrirSaisie(isVente: true),
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white, size: 26),
              label: const Text(
                'Saisie simple',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              elevation: 4,
            )
          : null,
    );
  }

  Widget _buildDashboardContent() {
    if (_isLoading && _currentUser == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }

    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('❌ Utilisateur non connecté',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      color: AppColors.primaryGreen,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(_getInitial(),
                              style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour ${_getPrenom()} 👋',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 19,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _currentUser!.typeActivite ?? 'Commerçant(e)',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Carte Solde
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💵 ARGENT EN CAISSE',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 32,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildBadgeStat(
                                'Entrées',
                                '+${_formatAmount(_quickStats['todayIncome'] ?? 0)} F',
                                Colors.greenAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildBadgeStat(
                                'Sorties',
                                '-${_formatAmount(_quickStats['todayExpense'] ?? 0)} F',
                                Colors.redAccent.shade100,
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

          // Boutons d'action
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _ouvrirSaisie(isVente: true),
                      child: Container(
                        height: 105,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primaryGreen.withValues(alpha: 0.35),
                                blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('💰', style: TextStyle(fontSize: 34)),
                            SizedBox(height: 6),
                            Text("J'AI VENDU",
                                style: TextStyle(color: Colors.white,
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _ouvrirSaisie(isVente: false),
                      child: Container(
                        height: 105,
                        decoration: BoxDecoration(
                          color: AppColors.expenseRed,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.expenseRed.withValues(alpha: 0.35),
                                blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🛒', style: TextStyle(fontSize: 34)),
                            SizedBox(height: 6),
                            Text("J'AI DÉPENSÉ",
                                style: TextStyle(color: Colors.white,
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Graphique Semaine
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activité de la semaine',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildWeekChart(),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // En-tête avec bouton Voir tout
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dernières opérations (${_recentTransactions.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (_currentUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoriqueCompletScreen(
                              commercantId: _currentUser!.id,
                            ),
                          ),
                        ).then((_) => _loadData(forceRefresh: true));
                      }
                    },
                    icon: const Icon(Icons.history, size: 16, color: AppColors.primaryGreen),
                    label: const Text(
                      'Voir tout >',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 4)),

          // Liste dynamique des dernières opérations
          _recentTransactions.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Text('📭', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('Aucune opération enregistrée aujourd\'hui',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = _recentTransactions[index];
                      return KeyedSubtree(
                        key: ValueKey('${t.id}_${t.montant}_${t.type.name}_${t.dateCreation.millisecondsSinceEpoch}'),
                        child: _buildCleanTransactionCard(t),
                      );
                    },
                    childCount: _recentTransactions.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildBadgeStat(String label, String valeur, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valeur,
              style: TextStyle(color: couleur, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    final theme = Theme.of(context);

    if (_weekData.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
            color: theme.cardColor, borderRadius: BorderRadius.circular(14)),
        child: const Center(
          child: Text('📊 Aucune donnée cette semaine',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    final maxValue = _weekData.fold<double>(0, (max, day) {
      final r = day['recettes'] as double;
      final d = day['depenses'] as double;
      return r > max ? r : (d > max ? d : max);
    });

    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: theme.cardColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _weekData.map((day) {
          final recettes = day['recettes'] as double;
          final depenses = day['depenses'] as double;
          final hR = maxValue > 0 ? (recettes / maxValue) * 80 : 0.0;
          final hD = maxValue > 0 ? (depenses / maxValue) * 80 : 0.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 12, height: hR.clamp(3.0, 80.0),
                    decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 12, height: hD.clamp(3.0, 80.0),
                    decoration: BoxDecoration(
                        color: AppColors.expenseRed,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(day['jour'] as String,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCleanTransactionCard(TransactionModel transaction) {
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
        : isYesterday ? 'Hier, $timeStr' : dateStr;

    String displayDescription = transaction.description ?? transaction.categorie;
    if (displayDescription == 'Vente rapide') displayDescription = 'Vente';
    if (displayDescription == 'Dépense rapide') displayDescription = 'Dépense';

    return InkWell(
      onTap: () => _afficherOptionsTransaction(transaction),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: transaction.estRecette
                  ? AppColors.primaryGreen : AppColors.expenseRed,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: transaction.estRecette
                    ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(_getCategoryIcon(transaction.categorie),
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayDescription,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(displayDate,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${transaction.estRecette ? '+' : '-'}${_formatAmount(transaction.montant)} F',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: transaction.estRecette
                    ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}