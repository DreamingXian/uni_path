import 'package:flutter/material.dart';

import 'event_details.dart';

import '../../services/event_service.dart';
import '../../models/event_model.dart';
import 'package:intl/intl.dart';

class EventsScreen extends StatefulWidget {
  final String searchQuery;
  
  const EventsScreen({super.key, this.searchQuery = ''});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventService _eventService = EventService();
  bool _isLoading = true;
  List<EventModel> _allEvents = [];
  List<EventModel> _filteredEvents = [];

  // Filters and Sorting
  bool isFreeOnly = false;
  int _timeSortType = 0; // 0: Recent Created, 1: Nearest Event, 2: Farthest Event

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  @override
  void didUpdateWidget(EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _applyFilters();
    }
  }

  Future<void> _fetchEvents() async {
    try {
      final events = await _eventService.getAllPublishedEvents();
      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint("Error fetching events: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredEvents = _allEvents.where((e) {
        // Exclude Ongoing and Ended events (only show those that have not started)
        if (e.eventTimes != null && e.eventTimes!.isNotEmpty) {
          final now = DateTime.now();
          bool hasStarted = e.eventTimes!.any((t) => t.startDateTime.isBefore(now));
          if (hasStarted) return false;
        }

        // Global Search filter (Title + Tags)
        if (widget.searchQuery.isNotEmpty) {
          final query = widget.searchQuery.toLowerCase();
          bool matchesTitle = e.title.toLowerCase().contains(query);
          bool matchesTag = false;
          if (e.tags != null) {
            matchesTag = e.tags!.any((tag) => tag.name.toLowerCase().contains(query));
          }
          if (!matchesTitle && !matchesTag) return false;
        }

        // Free filter
        if (isFreeOnly && (e.fees ?? 0) > 0) return false;

        return true;
      }).toList();

      // Deep Sorting Logic
      _filteredEvents.sort((a, b) {
        if (_timeSortType == 0) {
          // 0: Most recent created (Desc)
          return b.createdAt.compareTo(a.createdAt);
        } else {
          // 1: Nearest Event, 2: Farthest Event
          DateTime getStart(EventModel event) {
             if (event.eventTimes == null || event.eventTimes!.isEmpty) {
                 // Push events with no times to the rear of the respective lists
                 return _timeSortType == 1 ? DateTime(3000) : DateTime(1970);
             }
             List<DateTime> starts = event.eventTimes!.map((t) => t.startDateTime).toList();
             starts.sort(); // earliest first
             return starts.first; 
          }
          DateTime startA = getStart(a);
          DateTime startB = getStart(b);
          if (_timeSortType == 1) {
             return startA.compareTo(startB); // Asc
          } else {
             return startB.compareTo(startA); // Desc
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- FILTERING ROW ---
        _buildFilterRow(),

        // --- EVENT LIST ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
              : _filteredEvents.isEmpty
                  ? const Center(child: Text("No events found.", style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _fetchEvents,
                      color: const Color(0xFF6A1B9A),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        physics: const AlwaysScrollableScrollPhysics(), // Ensures it can be pulled even if list is short
                        itemCount: _filteredEvents.length,
                        itemBuilder: (context, index) => _buildEventCard(context, _filteredEvents[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  // 2. Filter Row Design
  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Time Sorting Toggle
          _buildTimeSortButton(),
          const Spacer(),
          // Free Only Toggle (Most Right)
          Row(
            children: [
              const Text("Free", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Transform.scale(
                scale: 0.8,
                child: Checkbox(
                  value: isFreeOnly,
                  activeColor: const Color(0xFF6A1B9A),
                  onChanged: (val) {
                    setState(() => isFreeOnly = val!);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSortButton() {
    IconData icon;
    String label;
    if (_timeSortType == 0) {
      icon = Icons.access_time;
      label = "Most Recent";
    } else if (_timeSortType == 1) {
      icon = Icons.arrow_downward;
      label = "Nearest Event";
    } else {
      icon = Icons.arrow_upward;
      label = "Farthest Event";
    }

    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _timeSortType = (_timeSortType + 1) % 3;
          _applyFilters();
        });
      },
      icon: Icon(icon, size: 16, color: const Color(0xFF1A237E)),
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E))),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  // 3. Updated Event Card
  Widget _buildEventCard(BuildContext context, EventModel event) {
    // Format times
    List<String> formattedSchedules = [];
    if (event.eventTimes != null) {
      formattedSchedules = event.eventTimes!.map((time) {
        final startFormat = DateFormat('dd MMM yyyy, hh:mm a');
        final endFormat = (time.startDateTime.year == time.endDateTime.year && 
                           time.startDateTime.month == time.endDateTime.month && 
                           time.startDateTime.day == time.endDateTime.day) 
                           ? DateFormat('hh:mm a') 
                           : DateFormat('dd MMM yyyy, hh:mm a');
        final start = startFormat.format(time.startDateTime);
        final end = endFormat.format(time.endDateTime);
        return "$start ~ $end"; 
      }).toList();
    }

    return InkWell(
      onTap: (){
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => EventDetailScreen(event: event),
            ),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: (event.eventPosterUrl != null && event.eventPosterUrl!.isNotEmpty)
                  ? Image.network(event.eventPosterUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                  : _buildPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                        ),
                      ),
                      _buildFeeTag(event.fees ?? 0.0),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (event.tags != null && event.tags!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: event.tags!.map((tag) => Text("#${tag.name}", style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.bold))).toList(),
                    ),
                  const SizedBox(height: 12),

                  // --- LOCATION ---
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 4),
                      Text(event.locationName ?? 'No location provided', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Divider(height: 20),

                  // --- SHOW ALL TIME SLOTS ---
                  const Text("Schedules:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  if (formattedSchedules.isEmpty)
                    const Text("No specific times.", style: TextStyle(fontSize: 12, color: Colors.black54))
                  else
                    ...formattedSchedules.map((timeStr) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              timeStr,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );

  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
    );
  }

  Widget _buildFeeTag(double fee) {
    bool isFree = fee == 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFree ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isFree ? Colors.green : Colors.blue),
      ),
      child: Text(
        isFree ? "FREE" : "RM ${fee.toStringAsFixed(2)}",
        style: TextStyle(color: isFree ? Colors.green[700] : Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}