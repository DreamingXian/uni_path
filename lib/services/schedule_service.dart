import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_model.dart';
import 'local_db_service.dart';
import 'notification_service.dart';

class ScheduleService {
  final _supabase = Supabase.instance.client;
  final _localDB = LocalDBService();
  final _notifications = NotificationService();

  // --- UI HELPERS ---
  static String formatTimeRange(DateTime start, DateTime? end) {
    final DateFormat formatter = DateFormat('h:mm a');
    String startStr = formatter.format(start).toLowerCase().replaceAll(' ', '');
    if (end == null) return startStr;
    String endStr = formatter.format(end).toLowerCase().replaceAll(' ', '');
    return "$startStr - $endStr";
  }

  // --- FETCH OPERATIONS ---
  Future<List<ScheduleModel>> getMySchedules() async {
    try {
      final response = await _supabase
          .from('schedules')
          .select()
          .order('start_time', ascending: true);

      final list = (response as List).map((json) => ScheduleModel.fromJson(json)).toList();

      // Refresh local cache with latest data
      await _localDB.cacheData(response.cast<Map<String, dynamic>>());

      return list;
    } catch (e) {
      log('⚠️ Offline mode: Fetching from local SQLite.');
      final localData = await _localDB.fetchOfflineSchedules();
      return localData.map((json) => ScheduleModel.fromJson(json)).toList();
    }
  }

  // --- INSERT OPERATION ---
  Future<int?> insertSchedule(ScheduleModel schedule) async {
    try {
      final Map<String, dynamic> data = schedule.toMap();
      final response = await _supabase.from('schedules').insert(data).select().single();
      final int newId = response['id'];

      // 1. Save to local SQLite
      await _localDB.saveLocally({
        'id': newId.toString(),
        'user_id': schedule.userId,
        'title': schedule.title,
        'description': schedule.description,
        'location_name': schedule.locationName,
        'start_time': schedule.startTime.toIso8601String(),
        'end_time': schedule.endTime?.toIso8601String(),
        'label_name': schedule.labelName,
        'is_homework': schedule.isHomework ? 1 : 0,
      });

      // 2. NEW: Calculate and insert the database reminder record
      final reminderTime = schedule.isHomework
          ? schedule.startTime.subtract(const Duration(days: 1))
          : schedule.startTime.subtract(const Duration(minutes: 10));

      await insertReminder(newId, reminderTime); // <--- ADD THIS LINE

      // 3. Handle physical phone notification
      _handleNotificationLogic(newId, response);

      return newId;
    } catch (e) {
      log('❌ Error inserting: $e');
      rethrow;
    }
  }

  // --- UPDATE OPERATION ---
  Future<void> updateSchedule(ScheduleModel schedule) async {
    try {
      if (schedule.id == null) return;

      final Map<String, dynamic> updateData = schedule.toMap();
      await _supabase.from('schedules').update(updateData).eq('id', schedule.id!);

      // 1. Calculate the new reminder time
      final reminderTime = schedule.isHomework
          ? schedule.startTime.subtract(const Duration(days: 1))
          : schedule.startTime.subtract(const Duration(minutes: 10));

      // 2. Update the reminders table in Supabase
      await _supabase
          .from('reminders')
          .update({'remind_at': reminderTime.toIso8601String()})
          .eq('schedule_id', schedule.id!);

      // 3. Update the local SQLite cache
      await _localDB.saveLocally({
        'id': schedule.id.toString(),
        // ... rest of your mapping logic ...
      });

      // 4. Update the physical phone alarm (this overwrites the old one)
      _handleNotificationLogic(schedule.id!, updateData);

    } catch (e) {
      log('❌ Update error: $e');
      rethrow;
    }
  }

  Future<void> deleteSchedule(int scheduleId) async {
    try {
      await _supabase.from('schedules').delete().eq('id', scheduleId);
      await _localDB.deleteLocally(scheduleId.toString());
      await _notifications.cancelNotification(scheduleId);
    } catch (e) {
      log('❌ Delete error: $e');
      rethrow;
    }
  }

  Future<void> insertReminder(int scheduleId, DateTime remindAt) async {
    try {
      await _supabase.from('reminders').insert({
        'schedule_id': scheduleId,
        'remind_at': remindAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint("Database Reminder Error: $e");
    }
  }

  void _handleNotificationLogic(int id, Map<String, dynamic> data) {
    if (data['start_time'] == null) return;

    // Use a strict parser to ensure the notification doesn't fire 8 hours late/early
    DateTime startTime;
    String rawDate = data['start_time'].toString();

    // Force UTC if the indicator is missing
    if (!rawDate.endsWith('Z') && !rawDate.contains('+')) {
      rawDate = "${rawDate.replaceFirst(' ', 'T')}Z";
    }

    startTime = DateTime.parse(rawDate).toLocal();

    _notifications.scheduleReminder(
      id: id,
      title: data['title'] ?? "Untitled",
      startTime: startTime,
      isHomework: data['is_homework'] == true || data['is_homework'] == 1,
    );
  }
}