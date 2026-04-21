import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import 'update_event.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  final EventService _eventService = EventService();
  ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  List<EventModel> _allEvents = [];
  List<EventModel> _filteredEvents = [];
  int _displayLimit = 3;

  // --- UI State Variables ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Filters
  final List<String> _filters = ['Draft', 'Published', 'Ongoing', 'Ended'];
  String _selectedFilter = 'Published'; // Default filter

  // Sorting and Pricing
  bool _sortNearestFirst = true; // true = Nearest to Oldest, false = Oldest to Nearest
  bool _showFreeOnly = false; // false = Show all, true = Free only

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchMyEvents();
  }

  Future<void> _fetchMyEvents() async {
    setState(() => _isLoading = true);

    final user = Provider.of<UserProvider>(context, listen: false).currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final events = await _eventService.getEventsByCreator(user.id);
    if (!mounted) return;

    setState(() {
      _allEvents = events;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (_displayLimit < _filteredEvents.length) {
        setState(() {
          _displayLimit += 3;
        });
      }
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();

    List<EventModel> results = _allEvents.where((e) {
      // 1. Search Query
      if (_isSearching && query.isNotEmpty) {
        bool matchesTitle = e.title.toLowerCase().contains(query);
        bool matchesLoc = e.locationName?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesLoc) return false;
      }

      // 2. Free Only
      if (_showFreeOnly && (e.fees ?? 0) > 0) return false;

      // 3. Status Definitions
      final isDraft = e.status == 'draft';
      final isCancelled = e.status == 'cancelled';
      final isPublished = e.status == 'published';

      final times = e.eventTimes ?? [];
      bool hasStarted = times.any((t) => t.startDateTime.isBefore(now));
      bool hasEnded = times.isNotEmpty && times.every((t) => t.endDateTime.isBefore(now));
      bool isOngoing = hasStarted && !hasEnded;
      bool isNotStarted = !hasStarted && !hasEnded;

      if (_selectedFilter == 'Draft') {
        if (!isDraft) return false;
      } else if (_selectedFilter == 'Published') {
        if (!isPublished || !isNotStarted) return false;
      } else if (_selectedFilter == 'Ongoing') {
        if (!isPublished || !isOngoing) return false;
      } else if (_selectedFilter == 'Ended') {
        if (!isCancelled && !(isPublished && hasEnded)) return false;
      }

      return true;
    }).toList();

    // 4. Sort (Nearest to Oldest -> Start date ascending towards future)
    DateTime getMinStart(EventModel ev) {
      if (ev.eventTimes == null || ev.eventTimes!.isEmpty) return DateTime(2100); 
      return ev.eventTimes!.map((t) => t.startDateTime).reduce((a, b) => a.isBefore(b) ? a : b);
    }

    results.sort((a, b) {
      final tA = getMinStart(a);
      final tB = getMinStart(b);
      return _sortNearestFirst ? tA.compareTo(tB) : tB.compareTo(tA);
    });

    setState(() {
      _filteredEvents = results;
      // Reset limits when filters change to avoid showing suddenly 9 loaded items.
      _displayLimit = 3;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- AppBar Widget ---
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF6A1B9A),
      foregroundColor: Colors.white,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search your events...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (val) => _applyFilters(),
            )
          : const Text('Manage Events', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _isSearching = false;
                _searchController.clear();
                _applyFilters();
              } else {
                _isSearching = true;
              }
            });
          },
        )
      ],
    );
  }

  // --- Filter Row ---
  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
                _applyFilters();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Sort & Pricing Controls ---
  Widget _buildSortAndUtilityRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sort Toggle
          TextButton.icon(
            onPressed: () {
              setState(() {
                _sortNearestFirst = !_sortNearestFirst;
              });
              _applyFilters();
            },
            icon: const Icon(Icons.sort, size: 18, color: Color(0xFF6A1B9A)),
            label: Text(
              _sortNearestFirst ? "Nearest Event" : "Oldest Event",
              style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          
          // Pricing Toggle
          FilterChip(
            label: const Text("Free Only"),
            selected: _showFreeOnly,
            selectedColor: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
            checkmarkColor: const Color(0xFF6A1B9A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: _showFreeOnly ? const Color(0xFF6A1B9A) : Colors.grey[300]!,
              ),
            ),
            onSelected: (bool selected) {
              setState(() => _showFreeOnly = selected);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterRow(),
          const Divider(height: 1),
          _buildSortAndUtilityRow(),
          const Divider(height: 1),
          
          // Events List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                : _filteredEvents.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_note, size: 60, color: Colors.grey),
                            SizedBox(height: 15),
                            Text(
                              "No events matched your filters.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _displayLimit < _filteredEvents.length ? _displayLimit + 1 : _filteredEvents.length,
                        itemBuilder: (context, index) {
                          if (index == _displayLimit) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
                            );
                          }
                          return _EventCard(
                            event: _filteredEvents[index],
                            onRefresh: _fetchMyEvents,
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ACTUAL EVENT CARD
// ---------------------------------------------------------------------------

class _EventCard extends StatefulWidget {
  final EventModel event;
  final VoidCallback onRefresh;

  const _EventCard({required this.event, required this.onRefresh});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  final EventService _eventService = EventService();
  int _enrolledCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCount();
  }

  Future<void> _loadEnrolledCount() async {
    if (widget.event.id == null) return;
    final count = await _eventService.getEnrolledCount(widget.event.id!);
    if (mounted) setState(() => _enrolledCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    // 1. Calculations
    final currentEnrollment = _enrolledCount;
    final capacity = event.capacity ?? 0;
    final fraction = capacity > 0 ? (currentEnrollment / capacity).clamp(0.0, 1.0) : 0.0;
    final fees = event.fees ?? 0;
    
    // Formatting date times
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

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UpdateEventScreen(event: event),
            ),
          );
          widget.onRefresh();
          _loadEnrolledCount(); // Refresh count on return
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- TOP: Poster Image & Fees Tag ---
            Stack(
              children: [
                if (event.eventPosterUrl != null && event.eventPosterUrl!.isNotEmpty)
                  Image.network(
                    event.eventPosterUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackImage(),
                  )
                else
                  _buildFallbackImage(),
                  
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fees == 0 ? "Free" : "RM ${fees.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // --- BOTTOM: Info Content ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Schedules
                  ...formattedSchedules.map((timeStr) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            timeStr,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Location
                  if (event.locationName != null && event.locationName!.isNotEmpty)...[
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6A1B9A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.locationName!,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 14),
                  ],

                  // Progress Status Bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 12,
                            backgroundColor: Colors.grey[200],
                            color: const Color(0xFF6A1B9A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          children: [
                            TextSpan(
                              text: "$currentEnrollment ",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                            ),
                            const TextSpan(text: "Enrolled"),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        capacity > 0 ? "Max $capacity" : "Unlimited",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Icon(Icons.event_note, color: Colors.grey, size: 50),
    );
  }
}
