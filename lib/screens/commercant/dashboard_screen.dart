import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../core/utils/global_nav.dart';
import 'saisie_rapide_screen.dart';
import 'modifier_transaction_screen.dart';
import 'bilans_screen.dart';
import 'rapports_screen.dart';
import 'notifications_screen.dart';
import 'profil_screen.dart';
import 'messages_screen.dart';
import 'historique_screen.dart';
import 'compte_en_suppression_screen.dart';
import '../../services/bilan_notification_service.dart';
import 'package:flutter/services.dart';

// CHARTE GRAPHIQUE MA FORTUNE (Mobile)
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

  bool _isLoading = true;     // true tant que le profil n'est pas lu
  bool _dataLoaded = false;   // true quand stats + operations sont chargees

  int _unreadMessagesCount = 0;
  Map<String, dynamic>? _latestAdminMessage;

  int _refreshTrigger = 0;
  bool _showAdminMessage = true;
  bool _isBalanceVisible = true;

  // Onglets construits (les autres ne se chargent pas au demarrage)
  final Set<int> _openedTabs = {0};
  bool _tabsPreloaded = false;

  // Streams crees UNE SEULE fois
  Stream<QuerySnapshot>? _notifStream;
  Stream<QuerySnapshot>? _msgStream;

  String _getTitle(int index) {
    switch (index) {
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

  // Initiale affichee quand il n'y a pas de photo (ou si l'URL echoue)
  Widget _avatarInitial() {
    return Center(
      child: Text(
        _getInitial(),
        style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    globalNavIndex.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    globalNavIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  // Ouvre l'onglet demande s'il n'est pas encore construit.
  // Pas de lecture Firestore ici : le profil previent l'accueil via onUserChanged.
  void _onTabChanged() {
    final i = globalNavIndex.value;
    if (!_openedTabs.contains(i)) {
      setState(() => _openedTabs.add(i));
    }
  }

  void _initStreams() {
    if (_currentUser == null || _notifStream != null) return;
    _notifStream = _db
        .collection('notifications')
        .where('commercantId', isEqualTo: _currentUser!.id)
        .where('lu', isEqualTo: false)
        .snapshots();
    _msgStream = _db
        .collection('messages')
        .where('commercantId', isEqualTo: _currentUser!.id)
        .where('expediteur', isEqualTo: 'admin')
        .where('lu', isEqualTo: false)
        .snapshots();
  }

  // Precharge les autres onglets UN PAR UN, apres la fin du chargement de l'accueil
  void _preloadOtherTabs() {
    if (_tabsPreloaded) return;
    _tabsPreloaded = true;
    _staggerTabs();
  }

  Future<void> _staggerTabs() async {
    for (final i in const [4, 1, 2, 3]) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() => _openedTabs.add(i));
    }
  }

  // Le profil s'affiche depuis le cache ; on recupere la version a jour ensuite
  Future<void> _syncUserInBackground() async {
    try {
      final fresh = await _authService.getCurrentUserData(forceRefresh: true);
      if (mounted && fresh != null) setState(() => _currentUser = fresh);
    } catch (_) {}
  }

  // ETAPE 1 : la page s'affiche des que le profil est lu (cache local en priorite)
  // ETAPE 2 : operations, stats et graphique arrivent ensuite (squelettes en attendant)
  Future<void> _loadData({bool forceRefresh = false}) async {
    try {
      final fetched = await _authService.getCurrentUserData(forceRefresh: forceRefresh);
      if (!mounted) return;

      if (fetched == null) {
        setState(() {
          _isLoading = false;
          _dataLoaded = true;
        });
        return;
      }

      UtilisateurModel user = fetched;

      if (user.suppressionDemandee) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CompteEnSuppressionScreen(user: user)),
        );
        return;
      }

            // 1) Charge la photo en mémoire (max 600 ms), puis on affiche la page
      final photoUrl = user.photo;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(photoUrl), context)
              .timeout(const Duration(milliseconds: 600));
        } catch (_) {}
        if (!mounted) return;
      }

      // Affichage immediat : en-tete, photo, solde, boutons
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
      _initStreams();
      SaisieRapideScreen.prefetchProduits();
      _loadMessagesPreview(); // arriere-plan, non bloquant
      if (!forceRefresh) _syncUserInBackground(); // profil a jour, sans bloquer

      // Pull-to-refresh : on recalcule le solde (la page reste affichee)
      if (forceRefresh) {
        await _transactionService.recalculerSolde(user.id);
        final refreshed = await _authService.getCurrentUserData(forceRefresh: true);
        if (!mounted) return;
        if (refreshed != null) {
          user = refreshed;
          setState(() => _currentUser = refreshed);
        }
      }

      // Operations + stats + graphique
      // Si forceRefresh : recalculerSolde vient deja de recharger depuis le serveur
      final all = await _transactionService.getTransactionsByCommercant(user.id);
      all.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      final now = DateTime.now();
      double income = 0, expense = 0;
      for (final t in all) {
        if (t.date.year == now.year && t.date.month == now.month && t.date.day == now.day) {
          if (t.estRecette) {
            income += t.montant;
          } else {
            expense += t.montant;
          }
        }
      }
      final week = _computeWeekData(all);

      if (!mounted) return;
      setState(() {
        _quickStats = {'todayIncome': income, 'todayExpense': expense};
        _recentTransactions = all.take(10).toList();
        _weekData = week;
        _dataLoaded = true;
        _refreshTrigger++;
      });

      // Une fois l'accueil complet, on prepare les autres onglets en douceur
      _preloadOtherTabs();

      if (BilanNotificationService.launchedFromBilan) {
        BilanNotificationService.launchedFromBilan = false;
      }
    } catch (e) {
      debugPrint('Erreur chargement: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _dataLoaded = true;
        });
      }
    }
  }

  List<Map<String, dynamic>> _computeWeekData(List<TransactionModel> all) {
    final now = DateTime.now();
    final weekData = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      double recettes = 0, depenses = 0;
      for (var t in all) {
        if (t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay)) {
          if (t.estRecette) {
            recettes += t.montant;
          } else {
            depenses += t.montant;
          }
        }
      }
      weekData.add({
        'jour': DateFormat('EEE', 'fr_FR').format(date).substring(0, 3).toUpperCase(),
        'recettes': recettes,
        'depenses': depenses,
        'date': date,
      });
    }
    return weekData;
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
      if (_currentUser != null) {
        _transactionService.invalidateCache(_currentUser!.id);
      }
      setState(() => _refreshTrigger++);
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
      try {
        await _transactionService.deleteTransaction(transaction.id, transaction.commercantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Transaction supprimée'), backgroundColor: emeraldDark));
          await _loadData(forceRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: brickRed));
        }
      }
    }
  }

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
    // ✅ Le gardien du geste retour : géré au-dessus de l'IndexedStack,
    // donc ça s'applique à TOUS les onglets automatiquement.
    return PopScope(
      canPop: false, // On empêche Flutter de gérer le retour lui-même
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (globalNavIndex.value != 0) {
          // Onglet autre qu'Accueil → on y retourne
          globalNavIndex.value = 0;
        } else {
          // Accueil déjà affiché → on quitte l'app (retour écran d'accueil du téléphone)
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<int>(
        valueListenable: globalNavIndex,
        builder: (context, currentIndex, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              automaticallyImplyLeading: false, // ✅ Déjà OK, garde-le
              title: Text(_getTitle(currentIndex),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              // ... le reste de ton AppBar inchangé ...
            backgroundColor: emeraldDark,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (currentIndex == 0)
                StreamBuilder<QuerySnapshot>(
                  stream: _notifStream ?? const Stream.empty(),
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
                            globalNavIndex.value = 3;
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
                stream: _msgStream ?? const Stream.empty(),
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

          // Seuls les onglets deja ouverts (ou precharges) sont construits
          body: IndexedStack(
            index: currentIndex,
            children: [
              _buildDashboardContent(),
              _openedTabs.contains(1)
                  ? BilansScreen(refreshTrigger: _refreshTrigger)
                  : const SizedBox.shrink(),
              _openedTabs.contains(2)
                  ? RapportsScreen(refreshTrigger: _refreshTrigger)
                  : const SizedBox.shrink(),
              _openedTabs.contains(3)
                  ? const NotificationsScreen()
                  : const SizedBox.shrink(),
              _openedTabs.contains(4)
                  ? ProfilScreen(
                      preloadedUser: _currentUser,
                      // Le profil previent l'accueil quand la photo ou les infos changent
                      onUserChanged: (u) {
                        if (u != null && mounted) setState(() => _currentUser = u);
                      },
                    )
                  : const SizedBox.shrink(),
            ],
          ),

          bottomNavigationBar: CustomBottomNav(
            currentIndex: currentIndex,
            onTap: (index) {
              globalNavIndex.value = index;
            },
          ),
        );
      },
    ),
    );
  }

  Widget _buildDashboardContent() {
    // Tant que le profil n'est pas lu : squelette qui ressemble au dashboard
    if (_currentUser == null) {
      if (_isLoading) return _buildDashboardSkeleton();
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
                      // Avatar en cache, apparition immediate (la photo ne bloque plus la page)
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: (_currentUser!.photo != null && _currentUser!.photo!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: _currentUser!.photo!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (_, __) => const SizedBox.shrink(),
                                  errorWidget: (_, __, ___) => _avatarInitial(),
                                )
                              : _avatarInitial(),
                        ),
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
                        Row(
                          children: [
                            const Text('Solde total', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _isBalanceVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: Colors.white70,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isBalanceVisible = !_isBalanceVisible;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: _isBalanceVisible ? 'Masquer le solde' : 'Afficher le solde',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isBalanceVisible
                                ? '${_formatAmount(_currentUser!.soldeActuel ?? 0)} FCFA'
                                : '•••••• FCFA',
                            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildMiniStat('📈', 'Recettes du jour', _dataLoaded ? '+${_formatAmount((_quickStats['todayIncome'] ?? 0).toDouble())} F' : '...', Colors.white)),
                            Container(width: 1, height: 40, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 12)),
                            Expanded(child: _buildMiniStat('📉', 'Dépense du jour', _dataLoaded ? '-${_formatAmount((_quickStats['todayExpense'] ?? 0).toDouble())} F' : '...', Colors.white.withOpacity(0.9))),
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
              _showAdminMessage)
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
              child: Text(
                _dataLoaded ? 'Dernières opérations (${_recentTransactions.length})' : 'Dernières opérations',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          !_dataLoaded
              ? SliverToBoxAdapter(child: _buildTransactionsSkeleton())
              : _recentTransactions.isEmpty
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

  // Squelette de chargement (forme du dashboard)
  Widget _buildDashboardSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(height: 220, color: Colors.white),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
                  const SizedBox(width: 14),
                  Expanded(child: Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: Container(height: 74, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Squelette de la liste des operations
  Widget _buildTransactionsSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            height: 74,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          ),
        ),
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

    // Pendant le chargement : espace reserve, sans message trompeur
    if (!_dataLoaded) return const SizedBox(height: 160);

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