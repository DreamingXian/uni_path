import 'dart:developer';
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
    String startStr = formatter.format(start.toLocal()).toLowerCase().replaceAll(' ', '');
    if (end == null) return startStr;
    String endStr = formatter.format(end.toLocal()).toLowerCase().replaceAll(' ', '');
    return "$startStr - $endStr";
  }

  // --- FETCH OPERATIONS (Fixes main.dart error) ---
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

      await _localDB.saveLocally({
        ...response,
        'id': newId.toString(),
        'is_homework': schedule.isHomework ? 1 : 0,
      });

      _handleNotificationLogic(newId, response);
      return newId;
    } catch (e) {
      log('❌ Error inserting: $e');
      rethrow;
    }
  }

  // --- UPDATE & DELETE ---
  Future<void> updateSchedule(ScheduleModel schedule) async {
    try {
      final Map<String, dynamic> updateData = schedule.toMap();
      await _supabase.from('schedules').update(updateData).eq('id', schedule.id!);
      await _localDB.saveLocally({...updateData, 'id': schedule.id.toString(), 'is_homework': schedule.isHomework ? 1 : 0});
      _handleNotificationLogic(schedule.id!, updateData);
    } catch (e) {
      log('❌ Update error: $e');
      rethrow;
    }
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await _supabase.from('schedules').delete().eq('id', scheduleId);
    await _localDB.deleteLocally(scheduleId.toString());
    await _notifications.cancelNotification(scheduleId);
  }

  void _handleNotificationLogic(int id, Map<String, dynamic> data) {
    if (data['start_time'] == null) return;
    final DateTime startTime = DateTime.parse(data['start_time']).toLocal();
    _notifications.scheduleReminder(
      id: id,
      title: data['title'] ?? "Untitled",
      startTime: startTime,
      isHomework: data['is_homework'] == true || data['is_homework'] == 1,
    );
  }
}