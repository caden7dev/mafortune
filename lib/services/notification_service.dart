import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Récupère le nombre de notifications non lues pour l'utilisateur actuel
  Future<int> getUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection('notifications')
          .where('audience', whereIn: ['Tous', 'Commerçants'])
          .where('lu', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Erreur getUnreadCount: $e');
      return 0;
    }
  }

  /// Stream du nombre de notifications non lues (temps réel)
  Stream<int> watchUnreadCount() {
    return _firestore
        .collection('notifications')
        .where('audience', whereIn: ['Tous', 'Commerçants'])
        .where('lu', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
          print('❌ Erreur watchUnreadCount: $error');
          return 0;
        });
  }

  /// Récupère toutes les notifications de l'utilisateur
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('audience', whereIn: ['Tous', 'Commerçants'])
          .orderBy('dateCreation', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur getAllNotifications: $e');
      return [];
    }
  }

  /// Stream de toutes les notifications (temps réel)
  Stream<QuerySnapshot> watchAllNotifications() {
    return _firestore
        .collection('notifications')
        .where('audience', whereIn: ['Tous', 'Commerçants'])
        .orderBy('dateCreation', descending: true)
        .snapshots();
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'lu': true,
        'dateLecture': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur markAsRead: $e');
      rethrow;
    }
  }

  /// Marque toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('audience', whereIn: ['Tous', 'Commerçants'])
          .where('lu', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'lu': true,
          'dateLecture': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('❌ Erreur markAllAsRead: $e');
      rethrow;
    }
  }

  /// Supprime une notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('❌ Erreur deleteNotification: $e');
      rethrow;
    }
  }

  /// Envoie une notification (pour admin uniquement)
  Future<void> sendNotification({
    required String title,
    required String message,
    required String audience, // 'Tous', 'Commerçants', 'Administrateurs'
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'message': message,
        'audience': audience,
        'type': type ?? 'info',
        'data': data ?? {},
        'lu': false,
        'dateCreation': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur sendNotification: $e');
      rethrow;
    }
  }
}