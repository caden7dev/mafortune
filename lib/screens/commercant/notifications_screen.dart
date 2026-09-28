import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'messages_screen.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite (Actions, Alertes douces)
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique (Suppression, Erreurs)
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  bool _isMarkingAll = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Cache local pour éviter les rebuilds inutiles
  List<QueryDocumentSnapshot> _cachedNotifications = [];
  final Set<String> _optimisticReadIds = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final user = _authService.currentUser;
    if (mounted) {
      setState(() => _currentUserId = user?.uid);
    }
  }

  // ─── MARQUER UNE NOTIFICATION COMME LUE ────────────────────────────────
  Future<void> _markAsRead(String notificationId, {bool showFeedback = true}) async {
    if (_optimisticReadIds.contains(notificationId)) return;

    setState(() => _optimisticReadIds.add(notificationId));
    if (showFeedback) HapticFeedback.lightImpact();

    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'lu': true});
          
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _optimisticReadIds.remove(notificationId));
      debugPrint('❌ Erreur marquage lu: $e');
    }
  }

  // ─── MARQUER TOUTES LES NOTIFICATIONS COMME LUES ───────────────────────
  Future<void> _markAllAsRead() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('audience', whereIn: ['Tous', 'Commerçants'])
          .where('lu', isEqualTo: false)
          .get();

      final unreadDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final userIds = (data['userIds'] as List<dynamic>?) ?? [];
        final audience = data['audience'] as String? ?? '';

        if (audience == 'Tous' || audience == 'Commerçants') return true;
        return userIds.contains(_currentUserId);
      }).toList();

      if (unreadDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Aucune notification à marquer'),
              backgroundColor: emeraldDark, // ✅ Couleur harmonisée
            ),
          );
        }
        return;
      }

      setState(() => _isMarkingAll = true);

      final batch = _firestore.batch();
      int count = 0;
      for (var doc in unreadDocs) {
        if (count >= 450) break;
        batch.update(doc.reference, {'lu': true});
        _optimisticReadIds.add(doc.id);
        count++;
      }
      await batch.commit();

      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $count notification${count > 1 ? 's' : ''} marquée${count > 1 ? 's' : ''} comme lue${count > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 15),
            ),
            backgroundColor: emeraldDark, // ✅ Couleur harmonisée
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage tout lu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : ${e.toString()}', style: const TextStyle(fontSize: 15)),
            backgroundColor: brickRed, // ✅ Couleur harmonisée
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
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
        return emeraldDark.withOpacity(0.1); // ✅ Vert Émeraude à 10%
      case '⚠️':
        return brickRed.withOpacity(0.1);    // ✅ Rouge Brique à 10%
      case '🎉':
      case '🆕':
        return terracotta.withOpacity(0.1);  // ✅ Terre Cuite à 10%
      case '🔧':
      default:
        return Colors.grey.withOpacity(0.1); // ✅ Gris neutre à 10%
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // ✅ Fond gris très clair et doux
      appBar: AppBar(
        backgroundColor: emeraldDark, // ✅ Vert Émeraude Sombre
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('audience', whereIn: ['Tous', 'Commerçants'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _cachedNotifications.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: emeraldDark));
          }

          if (snapshot.hasError && _cachedNotifications.isEmpty) {
            return _buildErrorView('Impossible de charger les notifications', 'Vérifiez votre connexion internet.');
          }

          List<QueryDocumentSnapshot> notifications = [];
          if (snapshot.hasData) {
            notifications = List.from(snapshot.data!.docs);
            notifications.sort((a, b) {
              final dateA = (a.data() as Map<String, dynamic>)['dateCreation'] as Timestamp?;
              final dateB = (b.data() as Map<String, dynamic>)['dateCreation'] as Timestamp?;
              if (dateA == null || dateB == null) return 0;
              return dateB.compareTo(dateA);
            });
            _cachedNotifications = notifications;
          } else {
            notifications = _cachedNotifications;
          }

          if (notifications.isEmpty) {
            return _buildEmptyView();
          }

          final unreadCount = notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final isRead = (data['lu'] == true) || _optimisticReadIds.contains(doc.id);
            return !isRead;
          }).length;

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
              setState(() => _cachedNotifications = []);
            },
            color: emeraldDark,
            child: Column(
              children: [
                if (unreadCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: terracotta.withOpacity(0.1), // ✅ Fond Terre Cuite à 10%
                      border: Border(bottom: BorderSide(color: terracotta.withOpacity(0.2))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: terracotta, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$unreadCount message${unreadCount > 1 ? 's' : ''} non lu${unreadCount > 1 ? 's' : ''}',
                            style: TextStyle(color: terracotta, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: _markAllAsRead,
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final doc = notifications[index];
                      return _buildNotificationTile(doc);
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
  Widget _buildNotificationTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now();
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final isRead = (data['lu'] == true) || _optimisticReadIds.contains(doc.id);
    final emoji = _getNotifEmoji(title);

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: brickRed, borderRadius: BorderRadius.circular(16)), // ✅ Rouge Brique
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async => await _confirmDelete(doc.id),
      child: GestureDetector(
        onTap: () async {
          await _markAsRead(doc.id);
          
          final titleLower = title.toLowerCase();
          if (titleLower.contains('message') || titleLower.contains('support') || titleLower.contains('💬')) {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessagesScreen()),
              );
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? Colors.grey.withOpacity(0.3) : emeraldDark.withOpacity(0.4), // ✅ Bordure Émeraude
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
                    color: isRead ? Colors.grey.withOpacity(0.1) : _getEmojiBgColor(emoji), // ✅ Règle des 10%
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
                              decoration: const BoxDecoration(color: terracotta, shape: BoxShape.circle), // ✅ Point Terre Cuite
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
                                color: terracotta.withOpacity(0.1), // ✅ Fond Terre Cuite 10%
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

  // ─── CONFIRMATION SUPPRESSION ──────────────────────────────────────────
  Future<bool> _confirmDelete(String notificationId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        content: const Text('Voulez-vous supprimer cette notification ?', style: TextStyle(fontSize: 15, color: textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Annuler', style: TextStyle(color: textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: brickRed, // ✅ Rouge Brique
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _firestore.collection('notifications').doc(notificationId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Notification supprimée'), 
              backgroundColor: brickRed, // ✅ Rouge Brique
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur suppression: $e');
      }
    }
    return false;
  }

  // ─── VUE ERREUR ────────────────────────────────────────────────────────
  Widget _buildErrorView(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey[400]), // ✅ Icône système propre
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
              backgroundColor: emeraldDark, // ✅ Vert Émeraude
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
          Icon(Icons.notifications_off_rounded, size: 64, color: Colors.grey[400]), // ✅ Icône système propre
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