import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_init.initializeTimeZones();
    // Lock to Malaysia time to prevent offset errors
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: androidInit),
    );
    debugPrint("🚀 Notification Service Ready (KL Time)");

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // FORCE CREATE THE CHANNEL MANUALLY
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'uni_path_academic_v5',
        'Academic Alerts',
        description: 'Important reminders for classes and deadlines',
        importance: Importance.max,
        playSound: true, // Fixed: Standard property for playing sound
        showBadge: true,
        enableVibration: true,
      ),
    );

    debugPrint("🚀 Notification Channel v5 Created");
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required DateTime startTime,
    bool isHomework = false,
  }) async {
    // 1. Logic: 24h for homework, 10 mins for classes
    final reminderTime = isHomework
        ? startTime.subtract(const Duration(days: 1))
        : startTime.subtract(const Duration(minutes: 10));

    // 2. Prevent scheduling if the time has passed
    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint("❌ SKIPPED: $title - Time already passed.");
      return;
    }

    // 3. Request Permission (Crucial for Android 13/14)
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestExactAlarmsPermission();

    // 4. THE UPDATED SCHEDULE BLOCK
    await _notifications.zonedSchedule(
      id,
      isHomework ? "Homework Due Tomorrow" : "Upcoming Class",
      isHomework ? "Finish: $title" : "Starts in 10 mins: $title",
      tz.TZDateTime.from(reminderTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'uni_path_academic_v5',
          'Academic Alerts',
          channelDescription: 'Important reminders for classes and deadlines',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // Wakes up the screen
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public, // Shows content on lock screen
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'academic_reminder',
    );

    debugPrint("✅ NOTIFICATION SET: $title for $reminderTime");
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint("🗑️ Notification $id removed from system.");
  }
}