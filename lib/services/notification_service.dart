import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // =========================================================================
  // PARTIE 1 : NOTIFICATIONS LOCALES (Pour la simulation SMS du Reset PIN)
  // =========================================================================

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showSmsNotification(String code) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sms_channel',
      'Messages SMS',
      channelDescription: 'Notifications de messages SMS',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'notif_icon',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      'MaFortune',
      'Votre code de vérification est : $code',
      platformChannelSpecifics,
      payload: 'code_verification',
    );
  }

  // =========================================================================
  // PARTIE 2 : NOTIFICATIONS FIRESTORE (Pour l'écran NotificationsScreen et Dashboard)
  // =========================================================================

  // CORRIGÉ : requête filtrée (les règles Firestore refusent une lecture sans filtre)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamBroadcast() {
    return _db
        .collection('notifications')
        .where('audience', whereIn: ['Tous', 'Commerçants'])
        .snapshots();
  }

  /// Vérifie si la notification est visible pour cet utilisateur
   /// Vérifie si la notification est visible pour cet utilisateur
  static bool isVisible(Map<String, dynamic> data, String? uid, DateTime since) {
    if (uid == null) return false;

    final audience = data['audience'] ?? 'Tous';
    final userIds = List<String>.from(data['userIds'] ?? []);
    final hiddenBy = List<String>.from(data['hiddenBy'] ?? []);

    // 1. Si l'utilisateur a masqué cette notification, on ne l'affiche pas
    if (hiddenBy.contains(uid)) return false;

    // 1bis. NOUVEAU : notification adressée à UN commerçant précis
    // (ex : réponse du support) : visible uniquement pour lui
    final targetId = data['commercantId'];
    if (targetId is String && targetId.isNotEmpty && targetId != uid) {
      return false;
    }

    // 2. Vérification de la date
    final ts = data['dateCreation'];
    DateTime notifDate;

    if (ts is Timestamp) {
      notifDate = ts.toDate();
    } else if (ts is String) {
      try {
        notifDate = DateTime.parse(ts);
      } catch (e) {
        notifDate = DateTime(1970);
      }
    } else {
      notifDate = DateTime(1970);
    }

    // Notification plus ancienne que la création du compte : masquée
    if (notifDate.isBefore(since)) {
      return false;
    }

    // 3. Logique de ciblage
    final isBroadcast = audience == 'Tous' ||
        audience == 'Commerçants' ||
        audience == 'Commercants';
    if (isBroadcast || userIds.contains(uid)) return true;

    return false;
  }

  // CORRIGÉ : 'lu' ne compte que pour une notification adressée à cet utilisateur.
  // Sur une diffusion, 'lu' est partagé (l'admin peut le modifier) : on l'ignore.
  static bool isRead(Map<String, dynamic> data, String uid) {
    final readBy = List<String>.from(data['readBy'] ?? []);
    if (readBy.contains(uid)) return true;
    return data['commercantId'] == uid && data['lu'] == true;
  }

  static int unreadCount(QuerySnapshot<Map<String, dynamic>> snapshot, String uid, DateTime since) {
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return isVisible(data, uid, since) && !isRead(data, uid);
    }).length;
  }

  // CORRIGÉ : on n'écrit plus 'lu: true' (champ partagé, refusé par les règles)
  static Future<void> markRead(String id, String uid) async {
    final docRef = _db.collection('notifications').doc(id);
    await docRef.update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }

  // CORRIGÉ : idem
  static Future<void> markManyRead(List<DocumentReference> refs, String uid) async {
    final batch = _db.batch();
    for (final ref in refs) {
      batch.update(ref, {
        'readBy': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }

  static Future<void> hideForUser(String id, String uid) async {
    final docRef = _db.collection('notifications').doc(id);
    await docRef.update({
      'hiddenBy': FieldValue.arrayUnion([uid]),
    });
  }

  /// Date de référence du compte (ne retourne jamais null)
  static DateTime sinceFor(DateTime? dateCreation) {
    final baseDate = dateCreation ?? DateTime.now().subtract(const Duration(hours: 2));
    return baseDate.subtract(const Duration(hours: 1));
  }
}