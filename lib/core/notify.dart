import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Lembretes locais (cofre cheio, baú grátis, roleta). Sem servidor.
class Notify {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ok = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      await _p.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      await _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      _ok = true;
    } catch (_) {}
  }

  /// Agenda (id, título, texto, daqui a quanto tempo). Cancela os anteriores.
  static Future<void> schedule(List<(int, String, String, Duration)> items) async {
    if (!_ok) return;
    try {
      await _p.cancelAll();
      const det = NotificationDetails(
        android: AndroidNotificationDetails('skyport', 'SkyPort', channelDescription: 'Lembretes do aeroporto', importance: Importance.defaultImportance),
        iOS: DarwinNotificationDetails(),
      );
      for (final it in items) {
        if (it.$4.inSeconds < 60) continue;
        await _p.zonedSchedule(it.$1, it.$2, it.$3, tz.TZDateTime.now(tz.UTC).add(it.$4), det,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      }
    } catch (_) {}
  }

  static Future<void> cancel() async {
    if (!_ok) return;
    try { await _p.cancelAll(); } catch (_) {}
  }
}
