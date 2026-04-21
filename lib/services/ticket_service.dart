import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ticket_model.dart';

class TicketService {
  final _supabase = Supabase.instance.client;

  /// Book a ticket for an event. Returns the new ticket's ID for linking to a payment.
  Future<int> bookTicket(TicketModel ticket) async {
    try {
      final response = await _supabase
          .from('tickets')
          .insert(ticket.toMap())
          .select('id')
          .single();
      final newId = response['id'] as int;
      log('Ticket booked for event: ${ticket.eventId}, ticket ID: $newId');
      return newId;
    } catch (e) {
      log('Error booking ticket: $e');
      rethrow;
    }
  }

  /// Get all tickets for the currently logged-in student (light, for join-check).
  Future<List<TicketModel>> getMyTickets() async {
    try {
      final response = await _supabase
          .from('tickets')
          .select('id, event_id, status, pass_code');
      return (response as List).map((json) => TicketModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching my tickets: $e');
      return [];
    }
  }

  /// Get all tickets for the student with full event details (for My Tickets screen).
  Future<List<Map<String, dynamic>>> getMyTicketsWithEvents() async {
    try {
      final response = await _supabase
          .from('tickets')
          .select('''
            id,
            event_id,
            status,
            pass_code,
            created_at,
            events (
              id,
              title,
              location_name,
              fees,
              event_poster_url,
              payment_qr_url,
              latitude,
              longitude,
              status,
              created_by,
              created_at,
              note,
              description,
              capacity,
              event_times ( id, event_id, start_date_time, end_date_time )
            )
          ''')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      log('Error fetching my tickets with events: $e');
      return [];
    }
  }


  /// For Society Leaders: See who has booked tickets for their event.
  Future<List<TicketModel>> getEventAttendees(int eventId) async {
    try {
      final response = await _supabase
          .from('tickets')
          .select()
          .eq('event_id', eventId);
      return (response as List).map((json) => TicketModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching event attendees: $e');
      return [];
    }
  }

  /// The "Scanner" function: Find a ticket by its UUID pass code.
  Future<TicketModel?> verifyTicketByCode(String passCode) async {
    try {
      final data = await _supabase
          .from('tickets')
          .select()
          .eq('pass_code', passCode)
          .single();
      return TicketModel.fromJson(data);
    } catch (e) {
      log('Invalid ticket code: $e');
      return null;
    }
  }

  /// Update ticket status (e.g., mark as 'used' after scanning, or 'active' after payment approval).
  Future<void> updateTicketStatus(int ticketId, String newStatus) async {
    try {
      await _supabase
          .from('tickets')
          .update({'status': newStatus})
          .eq('id', ticketId);
    } catch (e) {
      log('Error updating ticket status: $e');
      rethrow;
    }
  }
}