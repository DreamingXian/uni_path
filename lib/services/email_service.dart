import 'dart:developer';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  /// Sends an email notification to affected event participants.
  static Future<void> sendEventUpdateNotification({
    required List<String> bccEmails,
    required String eventTitle,
    required String changesDesc,
  }) async {
    final email = dotenv.env['SMTP_EMAIL'];
    final password = dotenv.env['SMTP_APP_PASSWORD'];

    if (email == null || password == null || email.isEmpty || password.isEmpty) {
      log('Email service failed: SMTP Credentials are not configured in .env!');
      return;
    }

    if (bccEmails.isEmpty) {
      log('Email service bypassed: No participants to notify found.');
      return;
    }

    // Gmail configured SMTP server
    final smtpServer = gmail(email, password);

    // Bcc prevents exposing participant emails to everyone else!
    final message = Message()
      ..from = Address(email, 'UniPath Event Updates')
      ..bccRecipients.addAll(bccEmails)
      ..subject = 'Important Update: $eventTitle'
      ..html = '''
        <div style="font-family: sans-serif; color: #333; line-height: 1.6;">
          <h2 style="color: #6A1B9A;">Event Update Notification</h2>
          <p>Dear Participant,</p>
          <p>Please note that there have been important changes regarding the schedule or location for <b>$eventTitle</b>.</p>
          <p><b>What Changed:</b> <br> $changesDesc</p>
          <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
          <p>We highly recommend launching the UniPath app to review the newly updated event itinerary to ensure you don't miss out on anything important!</p>
          <br>
          <p>Best Regards,</p>
          <p><b>Your Society via UniPath</b></p>
        </div>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      log('Update email successfully dispatched to ${bccEmails.length} participants!');
      log('Report: ' + sendReport.toString());
    } on MailerException catch (e) {
      log('Email dispatch failed: \n' + e.toString());
      for (var p in e.problems) {
        log('SMTP Problem [${p.code}]: ${p.msg}');
      }
    }
  }

  /// Sends a cancellation email notification to all active participants.
  static Future<void> sendEventCancellationNotification({
    required List<String> bccEmails,
    required String eventTitle,
  }) async {
    final email = dotenv.env['SMTP_EMAIL'];
    final password = dotenv.env['SMTP_APP_PASSWORD'];

    if (email == null || password == null || email.isEmpty || password.isEmpty) return;
    if (bccEmails.isEmpty) return;

    final smtpServer = gmail(email, password);

    final message = Message()
      ..from = Address(email, 'UniPath Event Updates')
      ..bccRecipients.addAll(bccEmails)
      ..subject = 'Event Cancelled: $eventTitle'
      ..html = '''
        <div style="font-family: sans-serif; color: #333; line-height: 1.6;">
          <h2 style="color: #D32F2F;">Event Cancellation Notice</h2>
          <p>Dear Participant,</p>
          <p>We regret to inform you that the event <b>$eventTitle</b> has been cancelled by the organizer.</p>
          <p>We sincerely apologize for any inconvenience this late cancellation may have caused.</p>
          <br>
          <p>Best Regards,</p>
          <p><b>Your Society via UniPath</b></p>
        </div>
      ''';

    try {
      await send(message, smtpServer);
      log('Cancellation email successfully dispatched!');
    } catch (e) {
      log('Email dispatch failed: $e');
    }
  }
}
