import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'lu': true});
    } catch (e) {
      debugPrint('Erreur marquage lu: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('audience', whereIn: ['Tous', 'Commerçants'])
          .where('lu', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'lu': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Toutes les notifications marquées comme lues',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur marquage tout lu: $e');
    }
  }

  String _getRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) {
      return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    } else if (diff.inHours > 0) {
      return 'Il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    } else if (diff.inMinutes > 0) {
      return 'Il y a ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  // Emoji selon le contenu du titre
  String _getNotifEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('budget') || t.contains('argent') || t.contains('solde')) return '💰';
    if (t.contains('alerte') || t.contains('attention')) return '⚠️';
    if (t.contains('bienvenu') || t.contains('félicitation')) return '🎉';
    if (t.contains('mise à jour') || t.contains('nouveau')) return '🆕';
    if (t.contains('sécurité') || t.contains('pin') || t.contains('mot de passe')) return '🔐';
    if (t.contains('transaction') || t.contains('dépense') || t.contains('recette')) return '📊';
    return '🔔';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '🔔 Notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Bouton "Tout lire" — grand et visible
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
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
            .orderBy('dateCreation', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          // Erreur
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('❌', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  const Text(
                    'Impossible de charger\nles notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vérifiez votre connexion internet.',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Vide
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔕', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 20),
                  const Text(
                    'Pas de notifications',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Les messages importants apparaîtront ici.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          final unreadCount =
              notifications.where((doc) => doc['lu'] == false).length;

          return Column(
            children: [
              // Bandeau non lues
              if (unreadCount > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: Colors.orange.withOpacity(0.12),
                  child: Row(
                    children: [
                      const Text('🔴', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Text(
                        '$unreadCount message${unreadCount > 1 ? 's' : ''} non lu${unreadCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Liste
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final date =
                        (data['dateCreation'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                    final title = data['title'] ?? 'Notification';
                    final message = data['message'] ?? '';
                    final isRead = data['lu'] == true;
                    final emoji = _getNotifEmoji(title);

                    return GestureDetector(
                      onTap: () => _markAsRead(doc.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.white
                              : AppColors.primaryGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRead
                                ? Colors.grey[200]!
                                : AppColors.primaryGreen.withOpacity(0.35),
                            width: isRead ? 1 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icône emoji dans cercle
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.grey[100]
                                      : AppColors.primaryGreen.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Contenu
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Titre + point non lu
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.bold,
                                              fontSize: 16,
                                              color: isRead
                                                  ? Colors.grey[700]
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (!isRead) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 10,
                                            height: 10,
                                            margin: const EdgeInsets.only(top: 4),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primaryGreen,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    // Message
                                    Text(
                                      message,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isRead
                                            ? Colors.grey[600]
                                            : Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // Heure relative
                                    Row(
                                      children: [
                                        Text(
                                          '🕐',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[400]),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getRelativeTime(date),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        if (!isRead) ...[
                                          const SizedBox(width: 12),
                                          Text(
                                            'Appuyez pour marquer comme lu',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primaryGreen
                                                  .withOpacity(0.8),
                                              fontStyle: FontStyle.italic,
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
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}