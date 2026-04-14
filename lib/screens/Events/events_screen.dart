import 'package:flutter/material.dart';

import 'event_details.dart';

class EventTime {
  final String date;
  final String startTime;
  final String endTime;

  EventTime({required this.date, required this.startTime, required this.endTime});
}

class DummyEvent {
  final String title;
  final String description;
  final String location;
  final List<EventTime> timings; // Updated to hold start and end times
  final List<String> tags;
  final double fees;
  final String imageUrl;

  DummyEvent({
    required this.title,
    required this.description,
    required this.location,
    required this.timings,
    required this.tags,
    required this.fees,
    required this.imageUrl,
  });
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool isFreeOnly = false;

  @override
  Widget build(BuildContext context) {
    // 1. Expanded Dummy Data
    final List<DummyEvent> dummyEvents = [
      DummyEvent(
        title: "TARUMT Tech Hackathon 2026",
        description: "Join the ultimate 48-hour coding challenge! Build innovative solutions for campus life.",
        location: "DKB, TARUMT Main Campus",
        timings: [
          EventTime(date: "20 May", startTime: "09:00 AM", endTime: "05:00 PM"),
          EventTime(date: "21 May", startTime: "09:00 AM", endTime: "09:00 PM"),
        ],
        tags: ["Workshop", "Hackathon"],
        fees: 0.0,
        imageUrl: "https://picsum.photos/seed/tech/600/300",
      ),
      DummyEvent(
        title: "Career Fair: Future Leaders",
        description: "Connect with over 50 top companies looking for fresh graduates.",
        location: "Main Hall, Block A",
        timings: [
          EventTime(date: "02 June", startTime: "10:00 AM", endTime: "04:00 PM"),
          EventTime(date: "03 June", startTime: "10:00 AM", endTime: "04:00 PM"),
        ],
        tags: ["Career", "Networking"],
        fees: 5.0,
        imageUrl: "https://picsum.photos/seed/career/600/300",
      ),
    ];

    return Column(
      children: [
        // --- FILTERING ROW ---
        _buildFilterRow(),

        // --- EVENT LIST ---
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: dummyEvents.length,
            itemBuilder: (context, index) => _buildEventCard(context, dummyEvents[index]),
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
          // Date Filter (Left)
          _buildFilterButton(Icons.calendar_month, "Date"),
          const Spacer(),
          // Tag Filter (Middle-Right)
          _buildFilterButton(Icons.local_offer, "Tags"),
          const SizedBox(width: 12),
          // Free Only Toggle (Most Right)
          Row(
            children: [
              const Text("Free", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Transform.scale(
                scale: 0.8,
                child: Checkbox(
                  value: isFreeOnly,
                  activeColor: const Color(0xFF6A1B9A),
                  onChanged: (val) => setState(() => isFreeOnly = val!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16, color: const Color(0xFF1A237E)),
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E))),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  // 3. Updated Event Card
  Widget _buildEventCard(BuildContext context, DummyEvent event) {
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
              child: Image.network(event.imageUrl, fit: BoxFit.cover),
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
                      _buildFeeTag(event.fees),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: event.tags.map((tag) => Text("#$tag", style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.bold))).toList(),
                  ),
                  const SizedBox(height: 12),

                  // --- LOCATION ---
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 4),
                      Text(event.location, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Divider(height: 20),

                  // --- SHOW ALL TIME SLOTS ---
                  const Text("Schedules:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  ...event.timings.map((time) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          "${time.date}: ",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          "${time.startTime} - ${time.endTime}",
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
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