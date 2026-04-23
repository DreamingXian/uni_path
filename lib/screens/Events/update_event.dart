import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import '../../models/event_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import '../../services/event_service.dart';
import '../../services/email_service.dart';
import 'edit_event_form.dart';
import 'validate_ticket.dart';

class UpdateEventScreen extends StatelessWidget {
  final EventModel event;

  const UpdateEventScreen({super.key, required this.event});

  String _getCalculatedStatus(EventModel event) {
    if (event.status == 'cancelled') return 'cancelled';
    if (event.status == 'draft') return 'draft';

    if (event.eventTimes == null || event.eventTimes!.isEmpty) return event.status;

    final now = DateTime.now();
    // RULE MODIFICATION: Events become 'Ongoing' 3 hours early for preemptive ticket scanning. Change 'hours: 3' below.
    DateTime minStart = event.eventTimes!.first.startDateTime.subtract(const Duration(hours: 3));
    DateTime maxEnd = event.eventTimes!.first.endDateTime;

    for (var t in event.eventTimes!) {
      final adjustedStart = t.startDateTime.subtract(const Duration(hours: 3));
      if (adjustedStart.isBefore(minStart)) minStart = adjustedStart;
      if (t.endDateTime.isAfter(maxEnd)) maxEnd = t.endDateTime;
    }

    if (now.isBefore(minStart)) return 'published';
    if (now.isAfter(maxEnd)) return 'ended';
    return 'ongoing';
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = _getCalculatedStatus(event);
    final bool canEdit = (currentStatus == 'draft' || currentStatus == 'published');

    // Formatting schedules
    List<String> formattedSchedules = [];
    if (event.eventTimes != null) {
      formattedSchedules = event.eventTimes!.map((t) {
        final startFormat = DateFormat('dd MMM yyyy, hh:mm a');
        final endFormat = (t.startDateTime.year == t.endDateTime.year && 
                           t.startDateTime.month == t.endDateTime.month && 
                           t.startDateTime.day == t.endDateTime.day) 
                           ? DateFormat('hh:mm a') 
                           : DateFormat('dd MMM yyyy, hh:mm a');
        final start = startFormat.format(t.startDateTime);
        final end = endFormat.format(t.endDateTime);
        return "$start ~ $end";
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Event Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          if (currentStatus != 'draft')
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () => _showShareDialog(context, event),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Poster Image (Full size, no crop)
            if (event.eventPosterUrl != null && event.eventPosterUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  event.eventPosterUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain, // Show entire image without cropping
                  errorBuilder: (_, __, ___) => _buildFallbackImage(),
                ),
              )
            else
              _buildFallbackImage(),

            const SizedBox(height: 25),

            // 2. Title
            Text(
              event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
            ),
            const SizedBox(height: 15),

            // 3. Description
            if (event.description != null && event.description!.isNotEmpty)...[
               Text(event.description!, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4)),
               const Divider(height: 40),
            ],

            // 4. Tags
            if (event.tags != null && event.tags!.isNotEmpty)...[
              const Text("Tags", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: event.tags!.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6A1B9A)),
                  ),
                  child: Text(tag.name, style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 13, fontWeight: FontWeight.bold)),
                )).toList(),
              ),
              const Divider(height: 40),
            ],

            // 5. Schedules
            const Text("Event Schedule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (formattedSchedules.isEmpty)
               const Text("No schedule provided.", style: TextStyle(color: Colors.grey))
            else
               ...formattedSchedules.map((timeStr) => Padding(
                 padding: const EdgeInsets.only(bottom: 8),
                 child: Row(
                   children: [
                     const Icon(Icons.access_time, color: Color(0xFF6A1B9A), size: 18),
                     const SizedBox(width: 8),
                     Expanded(child: Text(timeStr, style: const TextStyle(fontSize: 14))),
                   ],
                 ),
               )),
               
            const Divider(height: 40),

            // 6. Location
            const Text("Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
               children: [
                 const Icon(Icons.location_on, color: Color(0xFF6A1B9A), size: 18),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         (event.locationName != null && event.locationName!.isNotEmpty) ? event.locationName! : "No location provided.",
                         style: const TextStyle(fontSize: 14),
                       ),
                       if (event.latitude != null && event.longitude != null) ...[
                         const SizedBox(height: 4),
                         GestureDetector(
                           onTap: () async {
                             final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${event.latitude},${event.longitude}');
                             try {
                               await launchUrl(url, mode: LaunchMode.externalApplication);
                             } catch (e) {
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(content: Text('Could not launch maps. No compatible app found.')),
                                 );
                               }
                             }
                           },
                           child: const Text(
                             "View on Maps",
                             style: TextStyle(
                               fontSize: 13,
                               color: Colors.blue,
                               decoration: TextDecoration.underline,
                               decorationColor: Colors.blue,
                             ),
                           ),
                         ),
                       ]
                     ],
                   ),
                 ),
               ],
            ),
            const Divider(height: 40),
            
            // 7. Capacity & Fees
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Capacity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                        (event.capacity != null && event.capacity! > 0) ? "Max ${event.capacity}" : "Unlimited",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Fees", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                        (event.fees == null || event.fees == 0) ? "Free" : "RM ${event.fees!.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // 8. Note
            if (event.note != null && event.note!.isNotEmpty)...[
               const Divider(height: 40),
               const Text("Additional Notes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.yellow[50], // Lighter yellow background for note
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                 ),
                 child: Text(event.note!, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
               ),
            ],

            // 9. Payment QR
            if (event.paymentQrUrl != null && event.paymentQrUrl!.isNotEmpty)...[
               const SizedBox(height: 25),
               const Text("Payment QR Code", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               Container(
                 width: double.infinity,
                 height: 200,
                 decoration: BoxDecoration(
                   color: Colors.grey[100],
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.grey.shade300),
                 ),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(12),
                   child: Image.network(event.paymentQrUrl!, fit: BoxFit.contain),
                 ),
               ),
            ],

            const SizedBox(height: 40),

            // 10. Buttons
            if (canEdit)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => currentStatus == 'draft' ? _handleDeleteDraft(context) : _handleCancelEvent(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                          ),
                          child: Text(currentStatus == 'draft' ? "Delete" : "Cancel Event"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final bool? success = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => EditEventFormScreen(event: event),
                              ),
                            );
                            // If the edit form returned true (success), we drop back to automatically reload Manage Events.
                            if (success == true && context.mounted) {
                              Navigator.pop(context); 
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text("Update"),
                        ),
                      ),
                    ],
                  ),
                  if (currentStatus == 'draft') ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handlePublishDraft(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Visual distinction for positive completion action
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text("Publish Event", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]
                ],
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    "Event is currently $currentStatus.\nModifications are no longer allowed.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (currentStatus == 'ongoing') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // We push without needing to wait for a return to redraw, since it's just validation
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ValidateTicketScreen(event: event),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text('Validate Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancelEvent(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Cancel Event", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to cancel this event? This action cannot be undone and will automatically notify all active participants."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep Event", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cancel Event", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
    );

    final eventService = EventService();
    try {
      // Create new event payload with updated status
      final cancelledEvent = EventModel(
        id: event.id,
        title: event.title,
        description: event.description,
        locationName: event.locationName,
        latitude: event.latitude,
        longitude: event.longitude,
        status: 'cancelled',
        createdBy: event.createdBy,
        fees: event.fees,
        capacity: event.capacity,
        eventPosterUrl: event.eventPosterUrl,
        note: event.note,
        createdAt: event.createdAt,
      );
      await eventService.updateEvent(cancelledEvent);

      // Extract mappings and blast target emails natively
      final emails = await eventService.getParticipantEmails(event.id!);
      if (emails.isNotEmpty) {
         await EmailService.sendEventCancellationNotification(
           bccEmails: emails, 
           eventTitle: event.title, 
         );
      }

      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event has been cancelled successfully.')));
        Navigator.pop(context, true); // route backward reloading parent automatically
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel event: $e')));
      }
    }
  }

  Future<void> _handleDeleteDraft(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Delete Draft", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to permanently delete this drafted event?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep Draft", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
    );

    try {
      final eventService = EventService();
      await eventService.deleteEvent(event.id!); // Physically deletes item
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft successfully deleted.')));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete draft: $e')));
      }
    }
  }

  Future<void> _handlePublishDraft(BuildContext context) async {
    if (event.eventTimes == null || event.eventTimes!.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot publish without a valid schedule. Please save changes first.")));
       return;
    }

    DateTime maxEnd = event.eventTimes!.first.endDateTime;
    for (var t in event.eventTimes!) {
      if (t.endDateTime.isAfter(maxEnd)) maxEnd = t.endDateTime;
    }

    if (DateTime.now().isAfter(maxEnd)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Schedule Expired", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text("The scheduled time for this event has already passed. Please update the schedule time before publishing."),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx), 
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
              child: const Text("OK", style: TextStyle(color: Colors.white))
            ),
          ],
        )
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Publish Event", style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
        content: const Text("Are you ready to officially publish this event online?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Publish Now", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
    );

    try {
      final eventService = EventService();
      final publishedEvent = EventModel(
        id: event.id,
        title: event.title,
        description: event.description,
        locationName: event.locationName,
        latitude: event.latitude,
        longitude: event.longitude,
        status: 'published',
        createdBy: event.createdBy,
        fees: event.fees,
        capacity: event.capacity,
        eventPosterUrl: event.eventPosterUrl,
        note: event.note,
        createdAt: event.createdAt,
      );
      
      await eventService.updateEvent(publishedEvent);
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event successfully published!')));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish event: $e')));
      }
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            SizedBox(height: 10),
            Text("No Poster Available", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, EventModel event) {
    if (event.id == null) return;
    
    final String deepLinkUri = 'unipath://unipath.com/event/${event.id}';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ),
                const Text(
                  'Share Event',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan this QR code or write it to an NFC tag to instantly open this event!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: deepLinkUri,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _writeShareNfc(context, event.id!);
                    },
                    icon: const Icon(Icons.nfc, color: Colors.white),
                    label: const Text('Write NFC Tag', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _writeShareNfc(BuildContext context, int eventId) async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not supported or is disabled on this device.')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDetected = false;
        bool isWriting = false;
        NfcTag? detectedTag;
        StateSetter? dialogSetState;

        NfcManager.instance.startSession(
          pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
          onDiscovered: (NfcTag tag) async {
            if (dialogSetState != null) {
              dialogSetState!(() {
                detectedTag = tag;
              });
            }
          },
        );

        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;
            
            if (detectedTag != null && !isDetected) {
              isDetected = true;
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDetected ? Icons.nfc : Icons.contactless_outlined,
                      size: 64,
                      color: isDetected ? Colors.green : const Color(0xFF6A1B9A),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDetected ? 'NFC Detected' : 'NFC',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDetected ? Colors.green : Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDetected
                          ? 'Ready to write event link onto the tag?'
                          : 'Approach an NFC tag to write the Share deep-link.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    if (!isDetected)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            NfcManager.instance.stopSession();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Cancel'),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isWriting ? null : () {
                                NfcManager.instance.stopSession();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isWriting ? null : () async {
                                setDialogState(() => isWriting = true);
                                try {
                                  final ndef = Ndef.from(detectedTag!);
                                  if (ndef == null || !ndef.isWritable) {
                                    throw Exception('Tag is not NDEF writable');
                                  }
                                  
                                  // NDEF URI Payload encoding
                                  // 0x00 prefix corresponds to "(no prefix) raw string" for Custom Schemes
                                  final prefix = [0x00];
                                  final uriBytes = 'unipath://unipath.com/event/$eventId'.codeUnits;
                                  final payloadBytes = Uint8List.fromList([...prefix, ...uriBytes]);
                                  
                                  final record = NdefRecord(
                                    typeNameFormat: TypeNameFormat.wellKnown,
                                    type: Uint8List.fromList([0x55]), // 'U' for URI
                                    identifier: Uint8List(0),
                                    payload: payloadBytes,
                                  );

                                  final message = NdefMessage(records: [record]);
                                  await ndef.write(message: message);
                                  
                                  if (ctx.mounted) {
                                    NfcManager.instance.stopSession();
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Successfully wrote Event link to NFC tag!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed to write: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                  setDialogState(() => isWriting = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A1B9A),
                                foregroundColor: Colors.white,
                              ),
                              child: isWriting
                                  ? const SizedBox(
                                      height: 20, width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Write'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Ensure session is disabled even if they swipe the dialog away
      NfcManager.instance.stopSession();
    });
  }
}
