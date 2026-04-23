import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/event_time_model.dart';
import '../../services/payment_service.dart';
import '../../services/ticket_service.dart';
import '../../services/user_service.dart';
import 'event_details.dart';
import 'payment_receipt.dart';
import 'update_payment.dart';
import 'ticket_key_code.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final TicketService _ticketService = TicketService();

  List<Map<String, dynamic>> _allTickets = [];
  String _activeFilter = 'active';
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['active', 'used', 'pending', 'rejected', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final tickets = await _ticketService.getMyTicketsWithEvents();
    if (mounted) {
      setState(() {
        _allTickets = tickets;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _allTickets.where((t) {
      if (t['status'] != _activeFilter) return false;
      if (query.isNotEmpty) {
        final title = ((t['events'] as Map?)?['title'] ?? '').toString().toLowerCase();
        if (!title.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  int _countByStatus(String status) =>
      _allTickets.where((t) => t['status'] == status).length;

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Search by event title...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
              )
            : const Text('My Tickets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Filter Row ───────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) => _FilterChip(
                  label: f[0].toUpperCase() + f.substring(1),
                  status: f,
                  isActive: _activeFilter == f,
                  badgeCount: (f == 'active' || f == 'pending' || f == 'rejected')
                      ? _countByStatus(f)
                      : null,
                  onTap: () => setState(() => _activeFilter = f),
                )).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Content ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                : filteredTickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_num_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No ${_activeFilter} tickets',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTickets,
                        color: const Color(0xFF6A1B9A),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTickets.length,
                          itemBuilder: (context, index) {
                            return _TicketCard(
                              ticketData: filteredTickets[index],
                              onRefresh: _loadTickets,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chip Widget ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String status;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.status,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
  });

  Color get _statusColor {
    switch (status) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      case 'used': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _statusColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _statusColor : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withValues(alpha: 0.35) : _statusColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Ticket Card ─────────────────────────────────────────────────────────────

class _TicketCard extends StatefulWidget {
  final Map<String, dynamic> ticketData;
  final VoidCallback onRefresh;

  const _TicketCard({required this.ticketData, required this.onRefresh});

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  final PaymentService _paymentService = PaymentService();
  final TicketService _ticketService = TicketService();
  final UserService _userService = UserService();

  Future<void> _handleCancel(EventModel event, int ticketId) async {
    String creatorEmail = 'the organizer';
    try {
      final creator = await _userService.getUserById(event.createdBy);
      if (creator != null) creatorEmail = creator.email;
    } catch (_) {}
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Cancel Ticket'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this ticket?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'For refund inquiries or further assistance, please contact the organizer at:\n\n$creatorEmail',
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      final payments = await _paymentService.getPaymentsForTicket(ticketId);
      if (payments.isNotEmpty) {
        await _paymentService.updatePaymentStatus(payments.first.id!, 'cancelled');
      }
      await _ticketService.updateTicketStatus(ticketId, 'cancelled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket cancelled.'), backgroundColor: Colors.grey),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
    }
  }

  Future<void> _handleResubmit(EventModel event, int ticketId) async {
    try {
      final payments = await _paymentService.getPaymentsForTicket(ticketId);
      if (payments.isEmpty || !mounted) return;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => UpdatePaymentScreen(
            event: event,
            ticketId: ticketId,
            currentPayment: payments.first,
          ),
        ),
      );
      if (result == true) widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketData = widget.ticketData;
    final status = ticketData['status'] as String;
    final eventJson = ticketData['events'] as Map<String, dynamic>?;

    if (eventJson == null) {
      return const SizedBox.shrink();
    }

    // Parse event
    final eventTimesJson = eventJson['event_times'] as List? ?? [];
    final eventTimes = eventTimesJson.map((t) => EventTimeModel.fromJson(t)).toList();
    final event = EventModel(
      id: eventJson['id'],
      title: eventJson['title'] ?? '',
      description: eventJson['description'],
      locationName: eventJson['location_name'],
      latitude: eventJson['latitude']?.toDouble(),
      longitude: eventJson['longitude']?.toDouble(),
      status: eventJson['status'] ?? 'published',
      createdBy: eventJson['created_by'] ?? '',
      fees: eventJson['fees']?.toDouble(),
      capacity: eventJson['capacity'],
      eventPosterUrl: eventJson['event_poster_url'],
      note: eventJson['note'],
      paymentQrUrl: eventJson['payment_qr_url'],
      eventTimes: eventTimes,
      createdAt: eventJson['created_at'] != null
          ? DateTime.parse(eventJson['created_at'])
          : DateTime.now(),
    );

    // Format schedules
    final formattedSchedules = eventTimes.map((t) {
      final startFmt = DateFormat('dd MMM yyyy, hh:mm a');
      final sameDayEnd = t.startDateTime.year == t.endDateTime.year &&
          t.startDateTime.month == t.endDateTime.month &&
          t.startDateTime.day == t.endDateTime.day;
      final endFmt = sameDayEnd ? DateFormat('hh:mm a') : DateFormat('dd MMM yyyy, hh:mm a');
      return '${startFmt.format(t.startDateTime)} ~ ${endFmt.format(t.endDateTime)}';
    }).toList();

    // Status display
    final bool isActive = status == 'active';
    final bool isUsed = status == 'used';
    final bool isPending = status == 'pending';
    final bool isRejected = status == 'rejected';

    final bool showTicketEnabled = isActive || isUsed;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusLabel = 'Active';
        break;
      case 'used':
        statusColor = Colors.blue;
        statusLabel = 'Used';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Pending Approval';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'Cancelled';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Upper: Event info (tappable → EventDetailScreen) ────
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge + title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Schedules
                  if (formattedSchedules.isEmpty)
                    Text('No schedule set', style: TextStyle(color: Colors.grey[500], fontSize: 13))
                  else
                    ...formattedSchedules.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Color(0xFF6A1B9A)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(s, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                            ],
                          ),
                        )),

                  // Location
                  if (event.locationName != null && event.locationName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF6A1B9A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.locationName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Divider ──────────────────────────────────────────────
          const Divider(height: 1, thickness: 1),

          // ── Lower: Action buttons ─────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: isRejected
                // Rejected: Show Cancel + Resubmit side by side
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final ticketId = ticketData['id'] as int?;
                            if (ticketId == null) return;
                            _handleCancel(event, ticketId);
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final ticketId = ticketData['id'] as int?;
                            if (ticketId == null) return;
                            _handleResubmit(event, ticketId);
                          },
                          icon: const Icon(Icons.upload_file, size: 16, color: Colors.white),
                          label: const Text('Resubmit', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  )
                // Others: Show Ticket button
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: showTicketEnabled ? () {
                         final passCode = ticketData['pass_code'] as String?;
                         if (passCode == null) return;
                         
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => TicketKeyCodeScreen(
                               event: event,
                               passCode: passCode,
                               formattedSchedules: formattedSchedules,
                             ),
                           ),
                         );
                      } : null,
                      icon: Icon(
                        Icons.qr_code_2,
                        size: 18,
                        color: showTicketEnabled ? Colors.white : Colors.grey[400],
                      ),
                      label: Text(
                        'Show Ticket',
                        style: TextStyle(
                          color: showTicketEnabled ? Colors.white : Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: showTicketEnabled ? const Color(0xFF6A1B9A) : Colors.grey[200],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: showTicketEnabled ? 1 : 0,
                      ),
                    ),
                  ),
          ),

          // ── Receipt button (full-width, bottom) ────────────────────────
          InkWell(
            onTap: () {
            final ticketId = ticketData['id'] as int?;
            if (ticketId == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentReceiptScreen(
                  ticketId: ticketId,
                  eventTitle: event.title,
                ),
              ),
            );
          },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Receipt',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


