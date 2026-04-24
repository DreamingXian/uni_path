import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Lock to Malaysia time to prevent offset errors
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: androidInit),
    );
    debugPrint("🚀 Notification Service Ready (KL Time)");
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required DateTime startTime,
    bool isHomework = false,
  }) async {
    // 1. Internal logic: 24h for homework, 10 mins for classes
    final reminderTime = isHomework
        ? startTime.subtract(const Duration(days: 1))
        : startTime.subtract(const Duration(minutes: 10));

    // 2. Prevent scheduling if the time has passed
    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint("❌ SKIPPED: $title - Time already passed.");
      return;
    }

    // 3. Request Permission for Android 12+
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestExactAlarmsPermission();

    // 4. Schedule the notification
    await _notifications.zonedSchedule(
      id,
      isHomework ? "Homework Due Tomorrow" : "Upcoming Class",
      isHomework ? "Finish: $title" : "Starts in 10 mins: $title",
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'uni_path_academic',
          'Academic Alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint("✅ NOTIFICATION SET: $title for $reminderTime");
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint("🗑️ Notification $id removed from system.");
  }
}