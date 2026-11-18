import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'messages_screen.dart';

// CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite (Actions, Alertes douces)
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique (Suppression, Erreurs)
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

typedef _NotifDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AuthService _authService = AuthService();

  // Stream créé UNE SEULE fois (plus de réabonnement à chaque setState)
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  String? _uid;
  late DateTime _since;// date de création du compte (avec marge)

  bool _isMarkingAll = false;
  bool _isFirstLoad = true;

  List<_NotifDoc> _cachedNotifications = [];
  final Set<String> _optimisticReadIds = {};
  final Set<String> _hiddenIds = {};

  @override
  void initState() {
    super.initState();
    _stream = NotificationService.streamBroadcast();
    _loadUser();
  }

    Future<void> _loadUser() async {
    final user = await _authService.getCurrentUserData();
    if (!mounted) return;
    setState(() {
      _uid = user?.id ?? _authService.currentUser?.uid;
      // Comme sinceFor retourne maintenant un DateTime (non null), ça matche parfaitement avec 'late DateTime _since'
      _since = NotificationService.sinceFor(user?.dateCreation); 
    });
  }

  // ─── NOTIFICATIONS VISIBLES POUR CET UTILISATEUR ───────────────────────
  List<_NotifDoc> _visible(QuerySnapshot<Map<String, dynamic>> snap) {
    final uid = _uid!;
    final list = snap.docs
        .where((d) =>
            !_hiddenIds.contains(d.id) &&
            NotificationService.isVisible(d.data(), uid, _since))
        .toList();

    list.sort((a, b) {
      final ta = a.data()['dateCreation'];
      final tb = b.data()['dateCreation'];
      final da = ta is Timestamp ? ta.toDate() : DateTime.now();
      final db = tb is Timestamp ? tb.toDate() : DateTime.now();
      return db.compareTo(da);
    });
    return list;
  }

  bool _isRead(_NotifDoc doc) {
    if (_optimisticReadIds.contains(doc.id)) return true;
    return NotificationService.isRead(doc.data(), _uid ?? '');
  }

  void _showError(Object e) {
    if (!mounted) return;
    final denied = e is FirebaseException && e.code == 'permission-denied';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          denied
              ? 'Action refusée par le serveur. Vérifie les règles Firestore de la collection notifications.'
              : 'Erreur : $e',
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: brickRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── MARQUER UNE NOTIFICATION COMME LUE (pour cet utilisateur) ─────────
  Future<void> _markAsRead(String id) async {
    final uid = _uid;
    if (uid == null || _optimisticReadIds.contains(id)) return;

    setState(() => _optimisticReadIds.add(id));
    HapticFeedback.lightImpact();

    try {
      await NotificationService.markRead(id, uid);
    } catch (e) {
      debugPrint('❌ Erreur marquage lu: $e');
      if (mounted) setState(() => _optimisticReadIds.remove(id));
      _showError(e);
    }
  }

  // ─── MARQUER TOUTES LES NOTIFICATIONS COMME LUES ───────────────────────
  Future<void> _markAllAsRead() async {
    final uid = _uid;
    if (uid == null || _isMarkingAll) return;

    final unread = _cachedNotifications.where((d) => !_isRead(d)).toList();

    if (unread.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Aucune notification à marquer'),
          backgroundColor: emeraldDark,
        ),
      );
      return;
    }

    final ids = unread.map((d) => d.id).toList();
    setState(() {
      _isMarkingAll = true;
      _optimisticReadIds.addAll(ids); // affichage immédiat
    });

    try {
      // Sans réseau, l'écriture reste en attente : on ne bloque pas l'écran
      await NotificationService.markManyRead(
        unread.map((d) => d.reference).toList(),
        uid,
      ).timeout(const Duration(seconds: 8), onTimeout: () {});

      if (mounted) {
        HapticFeedback.mediumImpact();
        final count = ids.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $count notification${count > 1 ? 's' : ''} marquée${count > 1 ? 's' : ''} comme lue${count > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 15),
            ),
            backgroundColor: emeraldDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage tout lu: $e');
      if (mounted) setState(() => _optimisticReadIds.removeAll(ids));
      _showError(e);
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  // ─── TEMPS RELATIF ─────────────────────────────────────────────────────
  String _getRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) {
      final weeks = diff.inDays ~/ 7;
      return 'Il y a $weeks semaine${weeks > 1 ? 's' : ''}';
    } else if (diff.inDays > 0) {
      return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    } else if (diff.inHours > 0) {
      return 'Il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    } else if (diff.inMinutes > 0) {
      return 'Il y a ${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  // ─── EMOJI SELON LE TITRE ──────────────────────────────────────────────
  String _getNotifEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('budget') || t.contains('argent') || t.contains('solde')) return '💰';
    if (t.contains('alerte') || t.contains('attention')) return '⚠️';
    if (t.contains('bienvenu') || t.contains('félicitation')) return '🎉';
    if (t.contains('mise à jour') || t.contains('nouveau')) return '🆕';
    if (t.contains('sécurité') || t.contains('pin') || t.contains('mot de passe')) return '🔐';
    if (t.contains('transaction') || t.contains('dépense') || t.contains('recette')) return '📊';
    if (t.contains('bilan')) return '📈';
    if (t.contains('maintenance') || t.contains('problème')) return '🔧';
    return '🔔';
  }

  // ─── COULEUR DE FOND SELON LE TYPE (Règle des 10% d'opacité) ──────────
  Color _getEmojiBgColor(String emoji) {
    switch (emoji) {
      case '💰':
      case '📊':
      case '📈':
      case '🔐':
        return emeraldDark.withOpacity(0.1);
      case '⚠️':
        return brickRed.withOpacity(0.1);
      case '🎉':
      case '🆕':
        return terracotta.withOpacity(0.1);
      case '🔧':
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isMarkingAll ? null : _markAllAsRead,
            child: _isMarkingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Tout lire',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _uid == null
          ? const Center(child: CircularProgressIndicator(color: emeraldDark))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError && _cachedNotifications.isEmpty) {
                  return _buildErrorView(
                    'Impossible de charger les notifications',
                    'Vérifiez votre connexion internet.',
                  );
                }

                // Évite d'afficher la vue "Vide" pendant le tout premier chargement
                if (_isFirstLoad && !snapshot.hasData && _cachedNotifications.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: emeraldDark),
                  );
                }

                List<_NotifDoc> notifications;
                if (snapshot.hasData) {
                  _isFirstLoad = false;
                  notifications = _visible(snapshot.data!);
                  _cachedNotifications = notifications;
                } else {
                  notifications = _cachedNotifications;
                }

                if (notifications.isEmpty) {
                  return _buildEmptyView();
                }

                final unreadCount = notifications.where((d) => !_isRead(d)).length;

                return RefreshIndicator(
                  // Le flux est en direct : le geste sert seulement de confirmation visuelle
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  color: emeraldDark,
                  child: Column(
                    children: [
                      if (unreadCount > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: terracotta.withOpacity(0.1),
                            border: Border(bottom: BorderSide(color: terracotta.withOpacity(0.2))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: terracotta, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$unreadCount message${unreadCount > 1 ? 's' : ''} non lu${unreadCount > 1 ? 's' : ''}',
                                  style: const TextStyle(color: terracotta, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: _isMarkingAll ? null : _markAllAsRead,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: const Size(0, 32),
                                  foregroundColor: terracotta,
                                ),
                                child: const Text(
                                  'Tout lire',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationTile(notifications[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ─── TILE DE NOTIFICATION ──────────────────────────────────────────────
  Widget _buildNotificationTile(_NotifDoc doc) {
    final data = doc.data();
    final ts = data['dateCreation'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();
    final title = (data['title'] ?? 'Notification').toString();
    final message = (data['message'] ?? '').toString();
    final isRead = _isRead(doc);
    final emoji = _getNotifEmoji(title);

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: brickRed, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _confirmHide(doc.id);
        return false; // la liste se met à jour toute seule via _hiddenIds
      },
      child: GestureDetector(
        onTap: () {
          // Sans await : l'ouverture d'un écran ne dépend pas du réseau
          _markAsRead(doc.id);

          final titleLower = title.toLowerCase();
          if (titleLower.contains('message') || titleLower.contains('support') || titleLower.contains('💬')) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? Colors.grey.withOpacity(0.3) : emeraldDark.withOpacity(0.4),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isRead ? Colors.grey.withOpacity(0.1) : _getEmojiBgColor(emoji),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 16,
                                color: isRead ? Colors.grey[700] : textDark,
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(color: terracotta, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 14,
                          color: isRead ? Colors.grey[600] : textDark.withOpacity(0.8),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(_getRelativeTime(date), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: terracotta.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Nouveau',
                                style: TextStyle(fontSize: 10, color: terracotta, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── MASQUER (pour cet utilisateur seulement, sans supprimer le document) ──
  Future<void> _confirmHide(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        content: const Text(
          'Cette notification ne s\'affichera plus pour vous.',
          style: TextStyle(fontSize: 15, color: textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: brickRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    setState(() => _hiddenIds.add(notificationId));
    try {
      await NotificationService.hideForUser(notificationId, uid)
          .timeout(const Duration(seconds: 8), onTimeout: () {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Notification supprimée'),
            backgroundColor: brickRed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur masquage: $e');
      if (mounted) setState(() => _hiddenIds.remove(notificationId));
      _showError(e);
    }
  }

  // ─── VUE ERREUR ────────────────────────────────────────────────────────
  Widget _buildErrorView(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.grey[600]), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: emeraldDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── VUE VIDE ──────────────────────────────────────────────────────────
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text('Pas de notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Les messages importants apparaîtront ici.\nVous serez tenu au courant !',
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}