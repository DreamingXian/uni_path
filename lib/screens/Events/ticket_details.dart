import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../services/ticket_service.dart';

class TicketDetailsScreen extends StatefulWidget {
  final EventModel event;
  final Map<String, dynamic> ticketData;

  const TicketDetailsScreen({
    super.key,
    required this.event,
    required this.ticketData,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final TicketService _ticketService = TicketService();
  bool _isProcessing = false;

  Future<void> _markAsUsed() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as USED'),
        content: const Text('Are you sure you want to mark this ticket as used? This will check the student into the event.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      await _ticketService.updateTicketStatus(widget.ticketData['id'], 'used');
      
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 30,
                  child: Icon(Icons.check, color: Colors.white, size: 35),
                ),
                const SizedBox(height: 20),
                const Text('Success', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Ticket marked as USED successfully.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context); // Pop string back to validate_ticket.dart
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final ticket = widget.ticketData;
    final user = ticket['users'] as Map<String, dynamic>? ?? {};

    // Determine status UI
    final String status = ticket['status'] as String? ?? 'unknown';
    Color statusColor;
    String statusLabel;
    String? statusReason;

    if (status == 'active') {
      // Must also check if event ID matches, but we already filtered by event in validate_ticket
      statusColor = Colors.green;
      statusLabel = 'Valid';
    } else if (status == 'used') {
      statusColor = Colors.blue;
      statusLabel = 'Used';
    } else {
      statusColor = Colors.red;
      statusLabel = 'Invalid';
      statusReason = 'Ticket is $status';
    }

    // Formatting schedules
    List<String> formattedSchedules = [];
    if (event.eventTimes != null) {
      formattedSchedules = event.eventTimes!.map((t) {
        final startFormat = DateFormat('dd MMM yyyy, hh:mm a');
        final sameDayEnd = t.startDateTime.year == t.endDateTime.year &&
            t.startDateTime.month == t.endDateTime.month &&
            t.startDateTime.day == t.endDateTime.day;
        final endFormat = sameDayEnd ? DateFormat('hh:mm a') : DateFormat('dd MMM yyyy, hh:mm a');
        return "${startFormat.format(t.startDateTime)} ~ ${endFormat.format(t.endDateTime)}";
      }).toList();
    }

    // Code Extractor
    final passCode = ticket['pass_code'] as String? ?? '';
    final codeDisplay = passCode.contains('-') ? passCode.split('-').first : passCode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ticket Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Top Event Meta ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    event.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                  ),
                  const SizedBox(height: 12),
                  if (formattedSchedules.isNotEmpty)
                    ...formattedSchedules.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Color(0xFF6A1B9A)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(s, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              ),
                            ],
                          ),
                        )),
                  if (event.locationName != null && event.locationName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6A1B9A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(event.locationName!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // ── Big Status Banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    statusLabel == 'Valid' ? Icons.check_circle 
                    : statusLabel == 'Used' ? Icons.history
                    : Icons.cancel,
                    color: statusColor,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  if (statusReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      statusReason.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ── Separator ──
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('TICKET INFO', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1.5)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Ticket / User Meta ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Ticket Code', value: codeDisplay.toUpperCase(), isEmphasized: true),
                  const Divider(height: 24),
                  _InfoRow(label: 'Owner Name', value: user['full_name'] ?? 'Unknown'),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Student ID', value: user['student_id'] ?? 'Unknown'),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Email', value: user['email'] ?? 'Unknown'),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ── Actions ──
            if (_isProcessing)
              const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
            else if (statusLabel == 'Valid') ...[
               SizedBox(
                 width: double.infinity,
                 height: 55,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.green,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   onPressed: _markAsUsed,
                   child: const Text('MARK AS USED', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                 ),
               ),
            ] else if (statusLabel == 'Used') ...[
               SizedBox(
                 width: double.infinity,
                 height: 55,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.grey.shade300,
                     foregroundColor: Colors.black87,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   onPressed: () => Navigator.pop(context),
                   child: const Text('CONFIRM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 ),
               ),
            ] else ...[
               // Invalid status (Cancelled/Pending)
               SizedBox(
                 width: double.infinity,
                 height: 55,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.red,
                     foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   onPressed: () => Navigator.pop(context),
                   child: const Text('RETURN TO SCANNER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                 ),
               ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmphasized;

  const _InfoRow({required this.label, required this.value, this.isEmphasized = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isEmphasized ? FontWeight.bold : FontWeight.w600,
            fontSize: isEmphasized ? 16 : 14,
            color: isEmphasized ? const Color(0xFF1A237E) : Colors.black87,
            letterSpacing: isEmphasized ? 1.5 : 0,
          ),
        ),
      ],
    );
  }
}
