import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/offline_banner.dart';
import 'saisie_rapide_screen.dart';
import 'bilans_screen.dart';
import 'rapports_screen.dart';
import 'notifications_screen.dart';
import 'profil_screen.dart';
import 'theme_screen.dart';
import '../../services/tts_service.dart';
import '../../services/bilan_notification_service.dart';
import '../../widgets/screenshot_wrapper.dart';


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

  // Prénom seulement — plus simple à lire
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

    final stats =
        await _transactionService.getQuickStats(_currentUser!.id);
    if (mounted) setState(() => _quickStats = stats);

    final allTransactions = await _transactionService
        .getTransactionsByCommercant(_currentUser!.id);
    allTransactions
        .sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

    if (mounted) {
      setState(
          () => _recentTransactions = allTransactions.take(10).toList());
    }

    await _loadWeekData(allTransactions);
    if (mounted) setState(() {});

    // ✅ NOUVEAU — Si l'app a été ouverte via la notif du bilan, lire à voix haute
    if (BilanNotificationService.launchedFromBilan) {
      BilanNotificationService.launchedFromBilan = false; // consommé
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

  Future<void> _loadWeekData(
      List<TransactionModel> allTransactions) async {
    final now = DateTime.now();
    final weekData = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay =
          DateTime(date.year, date.month, date.day, 23, 59, 59);

      double recettes = 0, depenses = 0;
      for (var t in allTransactions) {
        if (t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay)) {
          if (t.estRecette)
            recettes += t.montant;
          else
            depenses += t.montant;
        }
      }

      weekData.add({
        'jour': DateFormat('EEE', 'fr_FR')
            .format(date)
            .substring(0, 3)
            .toUpperCase(),
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
    if (lower.contains('electricite') ||
        lower.contains('électricité')) return '💡';
    return '📊';
  }

  Future<void> _ouvrirSaisie({required bool isVente}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaisieRapideScreen(isVenteInitial: isVente),
    );
    if (result == true) await _loadData();
  }

  Future<void> _supprimerTransaction(
      TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Oui, supprimer',
                style: TextStyle(fontSize: 16)),
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
              content: Text('❌ Erreur: $e'),
              backgroundColor: Colors.red));
          setState(() => _isLoading = false);
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
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ThemeScreen())),
              tooltip: 'Thème',
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _ouvrirSaisie(isVente: true),
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white, size: 26),
              label: const Text(
                'Saisie rapide',
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
    if (_isLoading) {
      return const Center(
          child:
              CircularProgressIndicator(color: AppColors.primaryGreen));
    }

    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('❌ Utilisateur non connecté',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _loadData,
                child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGreen,
      child: CustomScrollView(
        slivers: [
          // ─── HEADER ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Salutation + avatar
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(_getInitial(),
                              style: const TextStyle(
                                  fontSize: 26, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour ${_getPrenom()} 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currentUser!.typeActivite ??
                                  'Commerçante',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Carte solde
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mon argent aujourd\'hui',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniStat(
                                '📈',
                                'Gagné',
                                '+${_formatAmount(_quickStats['todayIncome'] ?? 0)} F',
                                Colors.greenAccent,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white30,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12),
                            ),
                            Expanded(
                              child: _buildMiniStat(
                                '📉',
                                'Dépensé',
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

          // ─── 2 GROS BOUTONS ACCESSIBLES ──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  // J'AI VENDU — vert
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _ouvrirSaisie(isVente: true),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen
                                  .withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('💰',
                                style: TextStyle(fontSize: 38)),
                            SizedBox(height: 8),
                            Text(
                              "J'AI VENDU",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // J'AI DÉPENSÉ — rouge
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _ouvrirSaisie(isVente: false),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.expenseRed,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.expenseRed.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🛒',
                                style: TextStyle(fontSize: 38)),
                            SizedBox(height: 8),
                            Text(
                              "J'AI DÉPENSÉ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── GRAPHIQUE SEMAINE ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cette semaine',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildWeekChart(),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ─── TRANSACTIONS RÉCENTES ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dernières opérations (${_recentTransactions.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          _recentTransactions.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Text('📭', style: TextStyle(fontSize: 52)),
                          SizedBox(height: 12),
                          Text(
                            'Aucune opération pour l\'instant',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Appuie sur J\'AI VENDU ou J\'AI DÉPENSÉ',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionCard(
                        _recentTransactions[index]),
                    childCount: _recentTransactions.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String emoji, String label, String valeur, Color couleur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valeur,
            style: TextStyle(
              color: couleur,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekChart() {
    final theme = Theme.of(context);

    if (_weekData.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Text('📊 Aucune donnée cette semaine',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final maxValue = _weekData.fold<double>(0, (max, day) {
      final r = day['recettes'] as double;
      final d = day['depenses'] as double;
      return r > max ? r : (d > max ? d : max);
    });

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _weekData.map((day) {
          final recettes = day['recettes'] as double;
          final depenses = day['depenses'] as double;
          final hR = maxValue > 0 ? (recettes / maxValue) * 100 : 0.0;
          final hD = maxValue > 0 ? (depenses / maxValue) * 100 : 0.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 14,
                    height: hR.clamp(3.0, 100.0),
                    decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 14,
                    height: hD.clamp(3.0, 100.0),
                    decoration: BoxDecoration(
                        color: AppColors.expenseRed,
                        borderRadius: BorderRadius.circular(4)),
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

  Widget _buildTransactionCard(TransactionModel transaction) {
    final theme = Theme.of(context);
    final timeStr =
        DateFormat('HH:mm').format(transaction.dateCreation);
    final dateStr =
        DateFormat('dd/MM/yyyy').format(transaction.date);
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
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: transaction.estRecette
                ? AppColors.primaryGreen
                : AppColors.expenseRed,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Icône catégorie
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: transaction.estRecette
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(_getCategoryIcon(transaction.categorie),
                  style: const TextStyle(fontSize: 24)),
            ),
          ),

          const SizedBox(width: 12),

          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? transaction.categorie,
                  style: const TextStyle(
                      fontSize: 15,
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

          // Montant — grand et coloré
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${transaction.estRecette ? '+' : '-'}${_formatAmount(transaction.montant)} F',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: transaction.estRecette
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Bouton supprimer compact
              GestureDetector(
                onTap: () => _supprimerTransaction(transaction),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '🗑 Supprimer',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
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