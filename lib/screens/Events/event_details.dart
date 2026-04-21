import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../providers/user_provider.dart';
import 'buy_ticket.dart';
import '../../services/ticket_service.dart';
import '../../models/ticket_model.dart';
import '../auth_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  int _ticketsSold = 0;
  bool _isLoadingMetrics = true;

  bool _hasJoined = false;
  bool _isCheckingJoinStatus = true;

  @override
  void initState() {
    super.initState();
    _fetchTicketMetrics();
    _checkUserJoinStatus();
  }

  Future<void> _checkUserJoinStatus() async {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null || user.role != 'student') {
      if (mounted) setState(() => _isCheckingJoinStatus = false);
      return;
    }

    try {
      final hasTicket = await TicketService().hasActiveTicketForEvent(widget.event.id!);
      if (mounted) {
        setState(() {
          _hasJoined = hasTicket;
          _isCheckingJoinStatus = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingJoinStatus = false);
    }
  }

  Future<void> _fetchTicketMetrics() async {
    try {
      final count = await _eventService.getTicketCount(widget.event.id!);
      if (mounted) {
        setState(() {
          _ticketsSold = count;
          _isLoadingMetrics = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMetrics = false);
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Icon(Icons.event, size: 50, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).currentUser;
    bool isFree = (widget.event.fees ?? 0.0) == 0.0;
    
    // Formatting schedules
    List<String> formattedSchedules = [];
    if (widget.event.eventTimes != null) {
      formattedSchedules = widget.event.eventTimes!.map((t) {
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

    // Capacity Text
    String capacityText = "Loading...";
    if (!_isLoadingMetrics) {
      if (widget.event.capacity == null || widget.event.capacity! <= 0) {
        capacityText = "$_ticketsSold tickets claimed (Unlimited Capacity)";
      } else {
        final left = (widget.event.capacity! - _ticketsSold).clamp(0, widget.event.capacity!);
        capacityText = "$left tickets left (Max ${widget.event.capacity!})";
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Event Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FULL POSTER
            if (widget.event.eventPosterUrl != null && widget.event.eventPosterUrl!.isNotEmpty)
              ClipRRect(
                child: Image.network(
                  widget.event.eventPosterUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain, // Show entire image natively without cropping
                  errorBuilder: (_, __, ___) => _buildFallbackImage(),
                ),
              )
            else
              _buildFallbackImage(),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. TITLE
                  Text(
                    widget.event.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                  ),
                  const SizedBox(height: 15),

                  // 3. DESCRIPTION
                  if (widget.event.description != null && widget.event.description!.isNotEmpty)...[
                     Text(widget.event.description!, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4)),
                     const Divider(height: 40),
                  ],

                  // 4. TAGS
                  if (widget.event.tags != null && widget.event.tags!.isNotEmpty)...[
                    const Text("Tags", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.event.tags!.map((tag) => Container(
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

                  // 5. SCHEDULES
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

                  // 6. LOCATION & MAPS
                  const Text("Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                     children: [
                       const Icon(Icons.location_on, color: Color(0xFF6A1B9A), size: 18),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           (widget.event.locationName != null && widget.event.locationName!.isNotEmpty) ? widget.event.locationName! : "No location provided.",
                           style: const TextStyle(fontSize: 14),
                         ),
                       ),
                     ],
                  ),
                  if (widget.event.latitude != null && widget.event.longitude != null) ...[
                     const SizedBox(height: 15),
                     GestureDetector(
                       onTap: () async {
                         final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${widget.event.latitude},${widget.event.longitude}');
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
                       child: Container(
                         height: 180,
                         width: double.infinity,
                         decoration: BoxDecoration(
                           color: Colors.blue[50],
                           borderRadius: BorderRadius.circular(15),
                           border: Border.all(color: Colors.blue[300]!),
                         ),
                         child: const Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(Icons.location_on, size: 50, color: Colors.red),
                             SizedBox(height: 8),
                             Text("Tap to View on Google Maps", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                           ],
                         ),
                       ),
                     ),
                  ],
                  const Divider(height: 40),

                  // 7. CAPACITY & FEES
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Capacity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(
                              (widget.event.capacity != null && widget.event.capacity! > 0) ? "Max ${widget.event.capacity}" : "Unlimited",
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
                              isFree ? "Free" : "RM ${widget.event.fees!.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 8. TICKETS LEFT TRACKER


                  // 9. NOTE
                  if (widget.event.note != null && widget.event.note!.isNotEmpty)...[
                    const SizedBox(height: 25),
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
                       child: Text(widget.event.note!, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
                     ),
                  ],
                  const Divider(height: 40),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6A1B9A).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_num_outlined, color: Color(0xFF6A1B9A)),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Ticket Availability", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                              const SizedBox(height: 4),
                              Text(capacityText, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ],
        ),
      ),
      
      // --- STICKY BOTTOM BUTTON ---
      bottomSheet: (currentUser == null || currentUser.role == 'student') ? Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCheckingJoinStatus 
                  ? Colors.grey
                  : _hasJoined 
                      ? Colors.grey.shade400
                      : (isFree ? Colors.green : const Color(0xFF6A1B9A)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isCheckingJoinStatus || _hasJoined) ? null : () {
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to register for events.")));
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
                return;
              }

              if (isFree) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Join Event"),
                    content: const Text("Are you sure you want to officially register for this free event?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () async {
                          Navigator.pop(ctx); // Close dialog

                          // Display loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator()),
                          );

                          try {
                            final ticket = TicketModel(
                              userId: currentUser.id,
                              eventId: widget.event.id!,
                              status: 'active',
                              // pass_code is auto-generated by DB
                            );
                            await TicketService().bookTicket(ticket);

                            if (context.mounted) {
                              Navigator.pop(context); // Pop loading
                              setState(() => _hasJoined = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Successfully joined the event!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context); // Pop loading
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining event: $e')));
                            }
                          }
                        },
                        child: const Text("Confirm"),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => BuyTicketScreen(event: widget.event))).then((_) {
                  // After returning from buy screen, re-check join status to update UI if they submitted
                  if (mounted) {
                    setState(() => _isCheckingJoinStatus = true);
                    _checkUserJoinStatus();
                  }
                });
              }
            },
            child: _isCheckingJoinStatus 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _hasJoined 
                        ? "JOINED" 
                        : (isFree ? "JOIN FREE" : "BUY TICKET"),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
      ) : null,
    );
  }
}