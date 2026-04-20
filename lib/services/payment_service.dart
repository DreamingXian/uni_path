import 'dart:developer';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_model.dart';
import 'package:path/path.dart' as path;

class PaymentService {
  final _supabase = Supabase.instance.client;

  /// Uploads the payment receipt to the "payment_proofs" bucket.
  Future<String> uploadPaymentProof(File file) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User must be logged in to upload proof.");

      final fileExt = path.extension(file.path);
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = fileName;

      await _supabase.storage.from('payment_proofs').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _supabase.storage.from('payment_proofs').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      log('Error uploading payment proof: $e');
      rethrow;
    }
  }

  /// Submits a new payment record into the "payments" database table.
  Future<int?> submitPayment(PaymentModel payment) async {
    try {
      final response = await _supabase
          .from('payments')
          .insert(payment.toMap())
          .select('id')
          .single();
      
      return response['id'] as int;
    } catch (e) {
      log('Error submitting payment: $e');
      rethrow;
    }
  }

  /// Fetches all payments linked to a specific ticket (for Society review)
  Future<List<PaymentModel>> getPaymentsForTicket(int ticketId) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching payments for ticket: $e');
      return [];
    }
  }

  /// Fetches all payments for all tickets of a specific event (for Society dashboard)
  Future<List<PaymentModel>> getPaymentsForEvent(int eventId) async {
    try {
      // Join payments -> tickets to filter by event_id
      final response = await _supabase
          .from('payments')
          .select('*, tickets!inner(event_id)')
          .eq('tickets.event_id', eventId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching payments for event: $e');
      return [];
    }
  }

  /// Updates the status of a specific payment (e.g. 'approved', 'rejected') and records the timestamp/note
  Future<void> updatePaymentStatus(int paymentId, String status, {String? adminNote}) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (adminNote != null) {
        updateData['admin_note'] = adminNote;
      }

      await _supabase
          .from('payments')
          .update(updateData)
          .eq('id', paymentId);
          
      log('Payment $paymentId status updated to $status');
    } catch (e) {
      log('Error updating payment status: $e');
      rethrow;
    }
  }
}
