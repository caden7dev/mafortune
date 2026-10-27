import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class BilanNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool launchedFromBilan = false;

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Lome'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'bilan_jour') {
          launchedFromBilan = true;
        }
      },
    );

    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload == 'bilan_jour') {
      launchedFromBilan = true;
    }

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation
           <AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  static Future<void> planifierBilanQuotidien() async {
    await _plugin.zonedSchedule(
      100,
      '💰 Ton bilan du jour',
      'Appuie pour écouter combien tu as gagné aujourd\'hui',
      _prochaine20h(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bilan_quotidien',
          'Bilan quotidien',
          channelDescription: 'Rappel du bilan financier du jour',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // ✅ Ajout du paramètre requis
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'bilan_jour',
    );
  }

  static tz.TZDateTime _prochaine20h() {
    final now = tz.TZDateTime.now(tz.local);
    var heure20 =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
    if (heure20.isBefore(now)) {
      heure20 = heure20.add(const Duration(days: 1));
    }
    return heure20;
  }

  static Future<void> annuler() async {
    await _plugin.cancel(100);
  }

  // 🧪 MÉTHODE DE TEST — à supprimer une fois que tout marche
static Future<void> testerNotificationImmediate() async {
  await _plugin.show(
    999,
    '✅ Test réussi !',
    'Si tu vois ceci, les notifications marchent',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'test_immediat',
        'Test immédiat',
        channelDescription: 'Canal de test',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}
}