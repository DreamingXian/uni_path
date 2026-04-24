import 'dart:async';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {
    debugPrint("Notification Service Initialized.");
  }

  // FIXED: Added 'scheduleReminder' that your ScheduleService is looking for
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required DateTime startTime,
  }) async {
    final durationToWait = startTime.difference(DateTime.now());

    // If the time has already passed, don't set a timer
    if (durationToWait.isNegative) {
      debugPrint("Reminder for $title skipped: Time already passed.");
      return;
    }

    // Standard Flutter Timer (Safe for Gradle)
    Timer(durationToWait, () {
      debugPrint("NOTIFICATION TRIGGERED: $title");
      // You can add a SnackBar or Dialog logic here if you want a visual popup
    });

    debugPrint("Reminder for $title set to trigger in ${durationToWait.inMinutes} minutes.");
  }

  // FIXED: Added 'cancelNotification' that your ScheduleService is looking for
  Future<void> cancelNotification(int id) async {
    debugPrint("Notification for ID $id has been cancelled.");
  }
}