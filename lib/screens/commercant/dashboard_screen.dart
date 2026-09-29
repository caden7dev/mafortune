import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/custom_bottom_nav.dart';
import 'saisie_rapide_screen.dart';
import 'modifier_transaction_screen.dart';
import 'bilans_screen.dart';
import 'rapports_screen.dart';
import 'notifications_screen.dart';
import 'profil_screen.dart';
import 'messages_screen.dart';
import 'historique_screen.dart';
// ✅ SUPPRIMÉ : import '../../services/tts_service.dart';
import '../../services/bilan_notification_service.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre (Sécurité, Structure)
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite (Chaleur, Action principale)
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux (Dépenses, Alertes)

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UtilisateurModel? _currentUser;
  List<TransactionModel> _recentTransactions = [];
  Map<String, dynamic> _quickStats = {};
  List<Map<String, dynamic>> _weekData = [];
  bool _isLoading = true;

  int _unreadMessagesCount = 0;
  Map<String, dynamic>? _latestAdminMessage;
  int _currentIndex = 0;

  // ✅ CORRECTION : Le compteur doit être À L'INTÉRIEUR de la classe State
  int _refreshTrigger = 0;
  bool _isInitialLoad = true;
  bool _showAdminMessage = true;
  bool _isBalanceVisible = true;

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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _recentTransactions = [];
        _weekData = [];
        _quickStats = {};
      });
    }

    try {
      _currentUser = await _authService.getCurrentUserData(forceRefresh: forceRefresh);
      if (_currentUser == null) return;

      // ✅ RECALCUL AUTOMATIQUE : Garantit que le solde est cohérent avec les transactions
      if (forceRefresh) {
        await _transactionService.recalculerSolde(_currentUser!.id);
        // Recharger l'utilisateur pour récupérer le nouveau solde
        _currentUser = await _authService.getCurrentUserData(forceRefresh: true);
      }

      await Future.wait([
        _loadStatsAndTransactions(forceRefresh),
        _loadMessagesPreview(),
      ]);

      // ✅ SUPPRIMÉ : Le bloc qui déclenchait la voix (TtsService) a été retiré.
      // On garde juste la réinitialisation du flag au cas où il serait utilisé ailleurs.
      if (BilanNotificationService.launchedFromBilan) {
        BilanNotificationService.launchedFromBilan = false;
      }

    } catch (e) {
      debugPrint('Erreur chargement: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false; // ✅ Le premier chargement est fini
          _refreshTrigger++;
        });
      }
    }
  }

  Future<void> _loadStatsAndTransactions(bool forceRefresh) async {
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
        _recentTransactions = allTransactions.take(10).toList();
      });
    }
    await _loadWeekData(allTransactions);
  }

  Future<void> _loadMessagesPreview() async {
    if (_currentUser == null || !mounted) return;
    try {
      final unreadSnap = await _db.collection('messages')
          .where('commercantId', isEqualTo: _currentUser!.id)
          .where('expediteur', isEqualTo: 'admin')
          .where('lu', isEqualTo: false)
          .count()
          .get();

      if (!mounted) return;
      _unreadMessagesCount = unreadSnap.count ?? 0;

      final latestSnap = await _db.collection('messages')
          .where('commercantId', isEqualTo: _currentUser!.id)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (latestSnap.docs.isNotEmpty && mounted) {
        final data = latestSnap.docs.first.data();
        setState(() {
          _latestAdminMessage = {
            'message': data['message'] ?? 'Aucun message',
            'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'isFromAdmin': data['expediteur'] == 'admin',
          };
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement preview messages: $e');
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

  void _openMessagesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MessagesScreen()),
    ).then((_) {
      if (mounted) _loadMessagesPreview();
    });
  }

  Future<void> _ouvrirSaisie({required bool isVente}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaisieRapideScreen(isVenteInitial: isVente),
    );
    if (result == true) {
      _transactionService.invalidateCache(_currentUser!.id);
      await _loadData(forceRefresh: true);
    }
    _loadMessagesPreview();
  }

  Future<void> _modifierTransaction(TransactionModel transaction) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModifierTransactionSheet(transaction: transaction),
    );
    if (result == true) await _loadData(forceRefresh: true);
  }

  Future<void> _supprimerTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Supprimer cette transaction de ${_formatAmount(transaction.montant)} FCFA ?', style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: brickRed, foregroundColor: Colors.white),
            child: const Text('Oui, supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _transactionService.deleteTransaction(transaction.id, transaction.commercantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Transaction supprimée'), backgroundColor: emeraldDark));
          await _loadData(forceRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: brickRed));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // ✅ AJOUTÉ : bottom sheet Modifier/Supprimer, ouvert au tap sur une transaction
  void _afficherOptionsTransaction(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              transaction.description ?? transaction.categorie,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
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
              ],
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _modifierTransaction(transaction);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Modifier l'opération",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.blue, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _supprimerTransaction(transaction);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: brickRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: brickRed.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: brickRed.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline_rounded, color: brickRed, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Supprimer l'opération",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: brickRed),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: brickRed, size: 22),
                  ],
                ),
              ),
            ),
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
        title: Text(_getTitle(), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentIndex == 0)
           // 🔔 NOTIFICATIONS
            StreamBuilder<QuerySnapshot>(
              stream: _currentUser != null
                  ? FirebaseFirestore.instance.collection('notifications')
                      .where('commercantId', isEqualTo: _currentUser!.id)
                      .where('lu', isEqualTo: false)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData && snapshot.data != null) {
                  unreadCount = snapshot.data!.docs.length;
                }
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        setState(() => _currentIndex = 3); // bascule vers l'onglet Notifications
                      },
                      tooltip: 'Notifications',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: terracotta, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _currentUser != null
                  ? FirebaseFirestore.instance.collection('messages')
                      .where('commercantId', isEqualTo: _currentUser!.id)
                      .where('expediteur', isEqualTo: 'admin')
                      .where('lu', isEqualTo: false)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData && snapshot.data != null) {
                  unreadCount = snapshot.data!.docs.length;
                }
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.message_outlined),
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
                        if (mounted) _loadMessagesPreview();
                      },
                      tooltip: 'Messages',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: terracotta, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _ouvrirSaisie(isVente: true),
              backgroundColor: emeraldDark,
              icon: const Icon(Icons.add, color: Colors.white, size: 26),
              label: const Text('Saisie simple', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              elevation: 4,
            )
          : null,
    );
  }

  // ✅ CORRECTION : Passage du trigger aux écrans enfants
  Widget _buildCurrentTab() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _buildDashboardContent(),
        BilansScreen(refreshTrigger: _refreshTrigger),
        RapportsScreen(refreshTrigger: _refreshTrigger),
        const NotificationsScreen(),
        ProfilScreen(preloadedUser: _currentUser),
      ],
    );
  }

  Widget _buildDashboardContent() {
    if (_isLoading && _isInitialLoad) {
      return const Center(child: CircularProgressIndicator(color: emeraldDark));
    }

    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('❌ Utilisateur non connecté', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadData, child: const Text('Réessayer'), style: ElevatedButton.styleFrom(backgroundColor: emeraldDark, foregroundColor: Colors.white)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      color: emeraldDark,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(color: emeraldDark),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: Center(child: Text(_getInitial(), style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bonjour ${_getPrenom()} 👋', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(_currentUser!.typeActivite ?? 'Commerçant(e)', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Ligne du titre avec l'icône œil à droite
                        Row(
                          children: [
                            const Text('Solde total', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const Spacer(), // Pousse l'icône tout à droite
                            IconButton(
                              icon: Icon(
                                _isBalanceVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: Colors.white70,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isBalanceVisible = !_isBalanceVisible; // Bascule l'affichage
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: _isBalanceVisible ? 'Masquer le solde' : 'Afficher le solde',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ✅ Le montant qui change selon l'état
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isBalanceVisible
                                ? '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA'
                                : '•••••• FCFA', // Texte masqué
                            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildMiniStat('📈', 'Recettes du jour', '+${_formatAmount(_quickStats['todayIncome'] ?? 0)} F', Colors.white)),
                            Container(width: 1, height: 40, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 12)),
                            Expanded(child: _buildMiniStat('📉', 'Dépense du jour', '-${_formatAmount(_quickStats['todayExpense'] ?? 0)} F', Colors.white.withOpacity(0.9))),
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _ouvrirSaisie(isVente: true),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: terracotta,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: terracotta.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payments_rounded, color: Colors.white, size: 38),
                            SizedBox(height: 8),
                            Text("J'AI VENDU", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _ouvrirSaisie(isVente: false),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: brickRed,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: brickRed.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 38),
                            SizedBox(height: 8),
                            Text("J'AI DÉPENSÉ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_latestAdminMessage != null &&
              _latestAdminMessage!['isFromAdmin'] == true &&
              _showAdminMessage) // ✅ Condition pour l'afficher ou non
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _openMessagesScreen,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
                                child: const Icon(Icons.admin_panel_settings, color: Colors.blue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Message de l\'admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                        if (_unreadMessagesCount > 0) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: terracotta, borderRadius: BorderRadius.circular(8)),
                                            child: const Text('Nouveau', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_latestAdminMessage!['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3)),
                                    const SizedBox(height: 4),
                                    Text(DateFormat('dd/MM à HH:mm').format(_latestAdminMessage!['date']), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                      // ✅ Petit bouton pour fermer le message localement
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _showAdminMessage = false),
                        tooltip: 'Masquer ce message',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cette semaine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 10),
                  _buildWeekChart(),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Dernières opérations (${_recentTransactions.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
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
                          Text('Aucune opération pour l\'instant', style: TextStyle(color: Colors.grey, fontSize: 15), textAlign: TextAlign.center),
                          SizedBox(height: 8),
                          Text('Appuie sur J\'AI VENDU ou J\'AI DÉPENSÉ', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionCard(_recentTransactions[index]),
                    childCount: _recentTransactions.length,
                  ),
                ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HistoriqueScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Voir tout l\'historique',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: emeraldDark,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: emeraldDark),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String label, String valeur, Color couleur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text(emoji, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6), Text(label, style: TextStyle(color: couleur.withOpacity(0.9), fontSize: 12))]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(valeur, style: TextStyle(color: couleur, fontSize: 17, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildWeekChart() {
    final theme = Theme.of(context);
    if (_weekData.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('📊 Aucune donnée cette semaine', style: TextStyle(color: Colors.grey))),
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
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
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
                  Container(width: 14, height: hR.clamp(3.0, 100.0), decoration: BoxDecoration(color: emeraldDark, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 3),
                  Container(width: 14, height: hD.clamp(3.0, 100.0), decoration: BoxDecoration(color: brickRed, borderRadius: BorderRadius.circular(4))),
                ],
              ),
              const SizedBox(height: 6),
              Text(day['jour'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.7))),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ✅ MODIFIÉ : toute la carte est maintenant cliquable et ouvre le bottom sheet
  Widget _buildTransactionCard(TransactionModel transaction) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('HH:mm').format(transaction.dateCreation);
    final dateStr = DateFormat('dd/MM/yyyy').format(transaction.date);
    final now = DateTime.now();
    final isToday = transaction.dateCreation.year == now.year && transaction.dateCreation.month == now.month && transaction.dateCreation.day == now.day;
    final isYesterday = transaction.dateCreation.day == now.day - 1 && transaction.dateCreation.month == now.month && transaction.dateCreation.year == now.year;

    final displayDate = isToday ? 'Aujourd\'hui, $timeStr' : (isYesterday ? 'Hier, $timeStr' : dateStr);

    String displayDescription = transaction.description ?? transaction.categorie;
    if (displayDescription == 'Vente rapide') displayDescription = 'Vente';
    if (displayDescription == 'Dépense rapide') displayDescription = 'Dépense';

    return GestureDetector(
      onTap: () => _afficherOptionsTransaction(transaction),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: transaction.estRecette ? emeraldDark : brickRed, width: 4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: transaction.estRecette ? emeraldDark.withOpacity(0.1) : brickRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(_getCategoryIcon(transaction.categorie), style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayDescription, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(displayDate, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${transaction.estRecette ? '+' : '-'}${_formatAmount(transaction.montant)} F',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: transaction.estRecette ? emeraldDark : brickRed),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}