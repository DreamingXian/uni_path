import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_model.dart';
import 'local_db_service.dart';
import 'notification_service.dart';

class ScheduleService {
  final _supabase = Supabase.instance.client;
  final _localDB = LocalDBService();
  final _notifications = NotificationService();

  // --- 1. INSERT OPERATION ---

  /// Creates a schedule, handles specific Homework/Class rules, and syncs data.
  Future<int?> insertSchedule(ScheduleModel schedule) async {
    try {
      // Step A: Prepare data and apply Homework rules
      final Map<String, dynamic> dataToInsert = schedule.toMap();

      if (schedule.isHomework == true) {
        // Feature: Disable location for homework
        dataToInsert['location_name'] = "";
      }

      // Step B: Save to Supabase
      final response = await _supabase
          .from('schedules')
          .insert(dataToInsert)
          .select()
          .single();

      final int newId = response['id'];

      // Step C: Sync to SQLite (Offline Access)
      await _localDB.saveLocally({
        'id': newId.toString(),
        'title': response['title'] ?? "Untitled",
        'location_name': response['location_name'] ?? "",
        'start_time': response['start_time'],
        'is_homework': response['is_homework'] == true ? 1 : 0,
      });

      // Step D: Trigger Notifications (Non-blocking fix for "cannot add" bug)
      _handleNotificationLogic(newId, response);

      log('Schedule $newId created and synced.');
      return newId;
    } catch (e) {
      log('Error inserting schedule: $e');
      rethrow;
    }
  }

  // --- 2. NOTIFICATION LOGIC (PRIVATE) ---

  void _handleNotificationLogic(int id, Map<String, dynamic> data) {
    if (data['start_time'] == null) return;

    final DateTime startTime = DateTime.parse(data['start_time']);
    final bool isHomework = data['is_homework'] == true;

    if (isHomework) {
      // Rule: Set notification 1 day (24 hours) before
      _notifications.scheduleReminder(
        id: id,
        title: "Homework Due Soon: ${data['title']}",
        startTime: startTime.subtract(const Duration(days: 1)),
      );
    } else {
      // Rule: Set notification 10 minutes before
      _notifications.scheduleReminder(
        id: id,
        title: "Class Starting: ${data['title']}",
        startTime: startTime.subtract(const Duration(minutes: 10)),
      );
    }
  }

  // --- 3. FETCH OPERATIONS ---

  /// Fetches schedules from Cloud; falls back to SQLite if offline.
  Future<List<ScheduleModel>> getMySchedules() async {
    try {
      final response = await _supabase
          .from('schedules')
          .select()
          .order('start_time', ascending: true);

      final list = (response as List).map((json) => ScheduleModel.fromJson(json)).toList();

      // Refresh local cache
      await _localDB.cacheData(response.cast<Map<String, dynamic>>());

      return list;
    } catch (e) {
      log('Offline mode: Fetching from local SQLite.');
      final localData = await _localDB.fetchOfflineSchedules();
      return localData.map((json) => ScheduleModel.fromJson(json)).toList();
    }
  }

  /// Filter specifically for Homework Reminders
  Future<List<ScheduleModel>> getHomeworkReminders() async {
    try {
      final response = await _supabase
          .from('schedules')
          .select()
          .eq('is_homework', true)
          .order('start_time', ascending: true);
      return (response as List).map((json) => ScheduleModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching homework: $e');
      return [];
    }
  }

  // --- 4. UPDATE & DELETE ---

  Future<void> updateSchedule(ScheduleModel schedule) async {
    try {
      await _supabase.from('schedules').update(schedule.toMap()).eq('id', schedule.id!);
      await _localDB.saveLocally(schedule.toMap());

      // Refresh notification
      if (schedule.startTime != null) {
        _handleNotificationLogic(schedule.id!, schedule.toMap());
      }
    } catch (e) {
      log('Error updating: $e');
      rethrow;
    }
  }

  Future<void> deleteSchedule(int scheduleId) async {
    try {
      await _supabase.from('schedules').delete().eq('id', scheduleId);
      await _localDB.deleteLocally(scheduleId.toString());

      // Cancel the notification timer
      await _notifications.cancelNotification(scheduleId);

      log('Schedule $scheduleId removed.');
    } catch (e) {
      log('Error deleting: $e');
      rethrow;
    }
  }

  // --- 5. LABEL HELPERS ---

  Future<List<String>> getMyUniqueLabels() async {
    try {
      final response = await _supabase
          .from('schedules')
          .select('label_name')
          .not('label_name', 'is', null);

      final Set<String> labels = (response as List)
          .map((item) => item['label_name'] as String)
          .toSet();

      return labels.toList();
    } catch (e) {
      log('Error fetching labels: $e');
      return [];
    }
  }
}