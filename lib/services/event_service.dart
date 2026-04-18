import 'dart:developer';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/event_time_model.dart';
import '../models/tag_model.dart';

class EventService {
  final _supabase = Supabase.instance.client;

  // --- EVENT OPERATIONS ---

  /// Upload poster image to supabase storage and return the public URL
  Future<String?> uploadPoster(File imageFile) async {
    try {
      final fileExtension = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_poster.$fileExtension';
      await _supabase.storage.from('posters').upload(fileName, imageFile);
      final publicUrl = _supabase.storage.from('posters').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      log('Error uploading poster: $e');
      return null;
    }
  }

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
          .select('*, event_times(*), event_tags(tags(*))')
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

  /// Fetch deeply nested events (with times and tags) created by a specific User
  Future<List<EventModel>> getEventsByCreator(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*, event_times(*), event_tags(tags(*))')
          .eq('created_by', userId)
          .order('created_at', ascending: false);
          
      return (response as List).map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching user events: $e');
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
      await _supabase.from('events').update({
        'title': event.title,
        'description': event.description,
        'location_name': event.locationName,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'capacity': event.capacity,
        'note': event.note,
        'status': event.status,
        // fees is intentionally omitted to restrict overriding later on!
      }).eq('id', event.id!);
      log('Event updated successfully: ${event.id}');
    } catch (e) {
      log('Error updating event data: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(int eventId) async {
    try {
      await _supabase.from('events').delete().eq('id', eventId);
      log('Event deleted successfully: $eventId');
    } catch (e) {
      log('Error deleting event: $e');
      rethrow;
    }
  }

  /// Extracts the direct Email addresses of any user currently holding an active 
  /// ticket to the specified Event mapping through the synced users table.
  Future<List<String>> getParticipantEmails(int eventId) async {
    try {
      final response = await _supabase
          .from('tickets')
          .select('users!inner(email)')
          .eq('event_id', eventId)
          .eq('status', 'active'); // only active participants

      List<String> emails = [];
      for (var row in response as List) {
        if (row['users'] != null && row['users']['email'] != null) {
          emails.add(row['users']['email'].toString());
        }
      }
      return emails.toSet().toList();
    } catch (e) {
      log('Error fetching participant emails: $e');
      return [];
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

  // --- TAG OPERATIONS ---
  /// Fetches all available tags from the master table for the filter menu.
  Future<List<TagModel>> getAllTags() async {
    try {
      final response = await _supabase.from('tags').select().order('name');
      return (response as List).map((json) => TagModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching all tags: $e');
      return [];
    }
  }

  /// Links multiple tags to an event in the junction table.
  Future<void> addTagsToEvent(int eventId, List<int> tagIds) async {
    try {
      final List<Map<String, dynamic>> data = tagIds.map((tId) => {
        'event_id': eventId,
        'tag_id': tId,
      }).toList();

      await _supabase.from('event_tags').insert(data);
      log('Tags linked to event $eventId');
    } catch (e) {
      log('Error linking tags to event: $e');
      rethrow;
    }
  }

  /// Replaces all tags for a specific event by clearing and re-inserting
  Future<void> replaceEventTags(int eventId, List<int> tagIds) async {
    try {
      await _supabase.from('event_tags').delete().eq('event_id', eventId);
      if (tagIds.isNotEmpty) {
        await addTagsToEvent(eventId, tagIds);
      }
    } catch (e) {
      log('Error replacing tags for event: $e');
      rethrow;
    }
  }

  /// Fetches all published events including their associated tags.
  Future<List<Map<String, dynamic>>> getAllEventsWithTags() async {
    try {
      // We select all event columns and join the tags table through event_tags
      final response = await _supabase
          .from('events')
          .select('*, tags(*)')
          .eq('status', 'published')
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      log('Error fetching events with tags: $e');
      return [];
    }
  }

  /// Filters events by a specific tag name (e.g., 'Sport').
  Future<List<Map<String, dynamic>>> getEventsByTagName(String tagName) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*, tags!inner(*)') // !inner ensures we only get events WITH this tag
          .eq('tags.name', tagName)
          .eq('status', 'published');

      return response;
    } catch (e) {
      log('Error filtering events by tag: $e');
      return [];
    }
  }
}

