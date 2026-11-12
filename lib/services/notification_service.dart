import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Instance unique du plugin
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialisation (à appeler dans main.dart)
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  // Méthode pour afficher la fausse notification SMS
  static Future<void> showSmsNotification(String code) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sms_channel',
      'Messages SMS',
      channelDescription: 'Notifications de messages SMS',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      'MaFortune', // Nom de l'expéditeur
      'Votre code de vérification est : $code', // Le message avec le code
      platformChannelSpecifics,
    );
  }
}