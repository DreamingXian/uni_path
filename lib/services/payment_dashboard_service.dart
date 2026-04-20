import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_model.dart';
import '../services/ticket_service.dart';

/// A rich data holder combining payment + ticket + event + user info
/// for the Society payment approval dashboard.
class PaymentDashboardItem {
  final PaymentModel payment;
  final int ticketId;
  final int eventId;
  final String eventTitle;
  final String payerName;
  final String payerUserId;

  PaymentDashboardItem({
    required this.payment,
    required this.ticketId,
    required this.eventId,
    required this.eventTitle,
    required this.payerName,
    required this.payerUserId,
  });
}

class PaymentDashboardService {
  final _supabase = Supabase.instance.client;
  final _ticketService = TicketService();

  /// Fetches all payments for tickets belonging to events created by the current society.
  /// Joins: payments → tickets → events, and payments → users
  Future<List<PaymentDashboardItem>> getPaymentsForMyEvents() async {
    try {
      final response = await _supabase
          .from('payments')
          .select('''
            id,
            user_id,
            ticket_id,
            amount,
            proff_url,
            status,
            admin_note,
            updated_at,
            created_at,
            tickets!inner (
              id,
              event_id,
              events!inner (
                id,
                title,
                created_by
              )
            ),
            users!payments_user_id_fkey (
              id,
              full_name
            )
          ''')
          // Only show payments for events owned by the current society
          .eq('tickets.events.created_by', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final ticketJson = json['tickets'];
        final eventJson = ticketJson['events'];
        final userJson = json['users'];

        return PaymentDashboardItem(
          payment: PaymentModel.fromJson(json),
          ticketId: ticketJson['id'] as int,
          eventId: eventJson['id'] as int,
          eventTitle: eventJson['title'] as String,
          payerName: userJson['full_name'] as String? ?? 'Unknown',
          payerUserId: json['user_id'] as String,
        );
      }).toList();
    } catch (e) {
      log('Error fetching payment dashboard items: $e');
      return [];
    }
  }

  /// Returns just the count of 'pending' payments for the current society's events.
  Future<int> getPendingPaymentCount() async {
    try {
      final items = await getPaymentsForMyEvents();
      return items.where((i) => i.payment.status == 'pending').length;
    } catch (e) {
      return 0;
    }
  }

  /// Approves a payment: sets payment status → 'approved', ticket status → 'active'.
  Future<void> approvePayment(int paymentId, int ticketId) async {
    // Update payment
    await _supabase
        .from('payments')
        .update({'status': 'approved', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', paymentId);

    // Update ticket
    await _ticketService.updateTicketStatus(ticketId, 'active');
    log('Payment $paymentId approved. Ticket $ticketId set to active.');
  }

  /// Rejects a payment: sets payment status → 'rejected' with admin note, ticket → 'rejected'.
  Future<void> rejectPayment(int paymentId, int ticketId, String adminNote) async {
    await _supabase
        .from('payments')
        .update({
          'status': 'rejected',
          'admin_note': adminNote,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', paymentId);

    await _ticketService.updateTicketStatus(ticketId, 'rejected');
    log('Payment $paymentId rejected. Ticket $ticketId set to rejected.');
  }
}
