import 'package:flutter/material.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
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
  void dispose() {
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
              onChanged: (val) {
                // TODO: trigger search query update
              },
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
                // TODO: clear search query
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
                setState(() => _selectedFilter = filter);
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
              setState(() => _sortNearestFirst = !_sortNearestFirst);
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _EventCardDummy(
                  title: "Google Developer Tech Talk",
                  location: "DKB, FTMK Building",
                  schedules: ["12 Apr 2026, 2:00 PM ~ 4:00 PM"],
                  fees: 0,
                  currentEnrollment: 45,
                  capacity: 50,
                  imageUrl: "https://images.unsplash.com/photo-1540317580384-e5d43867caa6?auto=format&fit=crop&w=600&q=80",
                ),
                _EventCardDummy(
                  title: "Annual Hackathon 2026",
                  location: "Main Hall, Library",
                  schedules: [
                    "20 May 2026, 8:00 AM ~ 10:00 PM",
                    "21 May 2026, 8:00 AM ~ 5:00 PM"
                  ],
                  fees: 15.00,
                  currentEnrollment: 120,
                  capacity: 200,
                  imageUrl: "https://images.unsplash.com/photo-1504384308090-c894fdcc538d?auto=format&fit=crop&w=600&q=80",
                ),
                _EventCardDummy(
                  title: "Web3 & Blockchain Workshop",
                  location: "Lab C, Engineering Block",
                  schedules: ["15 Jun 2026, 9:00 AM ~ 12:00 PM"],
                  fees: 5.50,
                  currentEnrollment: 10,
                  capacity: 30,
                  imageUrl: "https://images.unsplash.com/photo-1639762681485-074b7f4ec651?auto=format&fit=crop&w=600&q=80",
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DUMMY EVENT CARD TEMPLATE
// ---------------------------------------------------------------------------

class _EventCardDummy extends StatelessWidget {
  final String title;
  final String location;
  final List<String> schedules;
  final double fees;
  final int currentEnrollment;
  final int capacity;
  final String imageUrl;

  const _EventCardDummy({
    required this.title,
    required this.location,
    required this.schedules,
    required this.fees,
    required this.currentEnrollment,
    required this.capacity,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate progress fraction
    final double fraction = capacity > 0 ? (currentEnrollment / capacity).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // TODO: Navigate to event details
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- TOP: Poster Image & Fees Tag ---
            Stack(
              children: [
                Image.network(
                  imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 160,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                  ),
                ),
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
                  ...schedules.map((time) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            time,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    title,
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
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Progress Status Bar
                  Row(
                    children: [
                      // The Progress Bar itself
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
                      
                      // Progress Text
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
                      
                      // Capacity max text
                      Text(
                        "Max $capacity",
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
}
