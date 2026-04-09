import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/event_time_model.dart';

class EventService {
  final _supabase = Supabase.instance.client;

  // --- EVENT OPERATIONS ---

  /// Creates a new event. The 'created_by' is handled by the database default auth.uid().
  Future<int?> insertEvent(EventModel event) async {
    try {
      final response = await _supabase
          .from('events')
          .insert(event.toMap())
          .select()
          .single();
      log('Event created with ID: ${response['id']}');
      return response['id'] as int; // Return ID so we can link event_times immediately
    } catch (e) {
      log('Error creating event: $e');
      rethrow;
    }
  }

  /// Fetch all published events for the student home feed.
  Future<List<EventModel>> getAllPublishedEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return (response as List).map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching events: $e');
      return [];
    }
  }

  /// Fetch a single event by its ID.
  Future<EventModel?> getEventById(int id) async {
    try {
      final data = await _supabase.from('events').select().eq('id', id).single();
      return EventModel.fromJson(data);
    } catch (e) {
      log('Error fetching event $id: $e');
      return null;
    }
  }

  /// Fetch events created by a specific Society (Admin).
  Future<List<EventModel>> getEventsBySociety(String societyId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('created_by', societyId);
      return (response as List).map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching society events: $e');
      return [];
    }
  }

  /// Search events by title or location.
  Future<List<EventModel>> searchEvents(String query) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .or('title.ilike.%$query%,location_name.ilike.%$query%');
      return (response as List).map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      log('Error searching events: $e');
      return [];
    }
  }

  Future<void> updateEvent(EventModel event) async {
    try {
      await _supabase.from('events').update(event.toMap()).eq('id', event.id!);
    } catch (e) {
      log('Error updating event: $e');
      rethrow;
    }
  }

  // --- EVENT TIME OPERATIONS ---

  /// Adds multiple time slots to an event.
  Future<void> insertEventTimes(List<EventTimeModel> times) async {
    try {
      final List<Map<String, dynamic>> data = times.map((t) => t.toMap()).toList();
      await _supabase.from('event_times').insert(data);
    } catch (e) {
      log('Error inserting event times: $e');
      rethrow;
    }
  }

  Future<List<EventTimeModel>> getTimesByEventId(int eventId) async {
    try {
      final response = await _supabase
          .from('event_times')
          .select()
          .eq('event_id', eventId);
      return (response as List).map((json) => EventTimeModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching event times: $e');
      return [];
    }
  }

  // --- ADDITIONAL EVENT TIME OPERATIONS ---

  /// Updates a single time slot.
  Future<void> updateEventTime(EventTimeModel time) async {
    try {
      await _supabase
          .from('event_times')
          .update(time.toMap())
          .eq('id', time.id!);
      log('Event time ${time.id} updated.');
    } catch (e) {
      log('Error updating event time: $e');
      rethrow;
    }
  }

  /// Deletes a specific time slot by its ID.
  Future<void> deleteEventTime(int id) async {
    try {
      await _supabase
          .from('event_times')
          .delete()
          .eq('id', id);
      log('Event time $id deleted.');
    } catch (e) {
      log('Error deleting event time: $e');
      rethrow;
    }
  }

  /// Deletes ALL time slots for a specific event.
  /// Useful if a Society wants to "Reset" or "Clear" the schedule.
  Future<void> deleteAllTimesForEvent(int eventId) async {
    try {
      await _supabase
          .from('event_times')
          .delete()
          .eq('event_id', eventId);
      log('All times for event $eventId deleted.');
    } catch (e) {
      log('Error clearing event times: $e');
      rethrow;
    }
  }
}

