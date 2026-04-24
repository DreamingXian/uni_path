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
    // Explicitly set to Malaysia time to match your location
    tz.setLocalLocation(tz.getLocation('Asia/Kuala Lumpur'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: androidInit),
    );
    debugPrint("🚀 Notification Service Initialized");
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required DateTime startTime,
  }) async {
    debugPrint("🔔 ATTEMPTING TO SCHEDULE: $title at $startTime");

    // 1. Calculate 10 minutes before
    final reminderTime = startTime.subtract(const Duration(minutes: 10));

    // 2. Check if the time has already passed
    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint("❌ SKIPPED: $reminderTime is in the past compared to ${DateTime.now()}");
      return;
    }

    // 3. Request Exact Alarm Permission (Android 12+ Fix)
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestExactAlarmsPermission();

    // 4. Actually tell Android to show the notification
    await _notifications.zonedSchedule(
      id,
      "Upcoming Class",
      "Your class '$title' starts in 10 minutes!",
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'uni_path_reminders',
          'Academic Reminders',
          channelDescription: 'Reminders for your classes and homework',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint("✅ SUCCESS: Notification registered for $reminderTime");
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint("🗑️ Notification $id cancelled");
  }
}