import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_model.dart';
import '../models/reminder_model.dart';

class ScheduleService {
  final _supabase = Supabase.instance.client;

  // --- SCHEDULE OPERATIONS ---

  /// Creates a new schedule entry and returns its ID.
  Future<int?> insertSchedule(ScheduleModel schedule) async {
    try {
      final response = await _supabase
          .from('schedules')
          .insert(schedule.toMap())
          .select()
          .single();
      log('Schedule created: ${response['id']}');
      return response['id'] as int;
    } catch (e) {
      log('Error creating schedule: $e');
      rethrow;
    }
  }

  /// Fetches all schedules for the currently logged-in user.
  Future<List<ScheduleModel>> getMySchedules() async {
    try {
      final response = await _supabase
          .from('schedules')
          .select()
          .order('start_time', ascending: true);
      return (response as List).map((json) => ScheduleModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching schedules: $e');
      return [];
    }
  }

  /// Fetches schedules for a specific day. Useful for a Calendar UI.
  Future<List<ScheduleModel>> getSchedulesByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

      final response = await _supabase
          .from('schedules')
          .select()
          .gte('start_time', startOfDay)
          .lte('start_time', endOfDay)
          .order('start_time', ascending: true);

      return (response as List).map((json) => ScheduleModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching schedules for date: $e');
      return [];
    }
  }

  /// Fetches a schedule with all its reminders in one single call.
  Future<Map<String, dynamic>?> getScheduleWithReminders(int scheduleId) async {
    try {
      final data = await _supabase
          .from('schedules')
          .select('*, reminders(*)')
          .eq('id', scheduleId)
          .single();
      return data;
    } catch (e) {
      log('Error fetching schedule details: $e');
      return null;
    }
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    try {
      await _supabase.from('schedules').update(schedule.toMap()).eq('id', schedule.id!);
      log('Schedule ${schedule.id} updated.');
    } catch (e) {
      log('Error updating schedule: $e');
      rethrow;
    }
  }

  Future<void> deleteSchedule(int scheduleId) async {
    try {
      // Database CASCADE handles the deletion of linked reminders.
      await _supabase.from('schedules').delete().eq('id', scheduleId);
      log('Schedule $scheduleId deleted.');
    } catch (e) {
      log('Error deleting schedule: $e');
      rethrow;
    }
  }

  // --- REMINDER OPERATIONS ---

  /// Batch inserts reminders for a schedule.
  Future<void> insertReminders(List<ReminderModel> reminders) async {
    try {
      final data = reminders.map((r) => r.toMap()).toList();
      await _supabase.from('reminders').insert(data);
      log('Reminders inserted.');
    } catch (e) {
      log('Error inserting reminders: $e');
      rethrow;
    }
  }

  /// Fetches all reminders for a specific schedule.
  Future<List<ReminderModel>> getRemindersForSchedule(int scheduleId) async {
    try {
      final response = await _supabase
          .from('reminders')
          .select()
          .eq('schedule_id', scheduleId)
          .order('remind_at', ascending: true);
      return (response as List).map((json) => ReminderModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching reminders: $e');
      return [];
    }
  }

  /// Updates a single specific reminder time.
  Future<void> updateReminder(int reminderId, DateTime newTime) async {
    try {
      await _supabase
          .from('reminders')
          .update({'remind_at': newTime.toIso8601String()})
          .eq('id', reminderId);
      log('Reminder $reminderId updated.');
    } catch (e) {
      log('Error updating reminder: $e');
      rethrow;
    }
  }

  /// Deletes a single specific reminder.
  Future<void> deleteReminder(int reminderId) async {
    try {
      await _supabase.from('reminders').delete().eq('id', reminderId);
      log('Reminder $reminderId deleted.');
    } catch (e) {
      log('Error deleting reminder: $e');
      rethrow;
    }
  }

  /// Fetches all schedules that match a specific label (e.g., 'Study' or 'Work').
  Future<List<ScheduleModel>> getSchedulesByLabel(String labelName) async {
    try {
      final response = await _supabase
          .from('schedules')
          .select()
          .eq('label_name', labelName)
          .order('start_time', ascending: true);

      return (response as List).map((json) => ScheduleModel.fromJson(json)).toList();
    } catch (e) {
      log('Error filtering schedules by label: $e');
      return [];
    }
  }

  /// Fetches a list of all unique labels the user has created.
  /// Useful for building a "Filter by Category" chip menu in the UI.
  Future<List<String>> getMyUniqueLabels() async {
    try {
      // We use a select with 'label_name' to get only that column
      final response = await _supabase
          .from('schedules')
          .select('label_name')
          .not('label_name', 'is', null);

      // Convert to a Set to remove duplicates, then back to a List
      final Set<String> labels = (response as List)
          .map((item) => item['label_name'] as String)
          .toSet();

      return labels.toList();
    } catch (e) {
      log('Error fetching unique labels: $e');
      return [];
    }
  }
}