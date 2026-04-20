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

  /// Get all tickets for the currently logged-in student.
  Future<List<TicketModel>> getMyTickets() async {
    try {
      final response = await _supabase
          .from('tickets')
          .select('*, events(*)'); // Join with events to show event names in the UI
      return (response as List).map((json) => TicketModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching my tickets: $e');
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