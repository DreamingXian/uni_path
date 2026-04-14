import 'package:flutter/material.dart';

// Simple dummy class to hold our event data
class DummyEvent {
  final String title;
  final String description;
  final String location;
  final String date;
  final String time;
  final double fees;
  final String imageUrl;

  DummyEvent({
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.time,
    required this.fees,
    required this.imageUrl,
  });
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Define dummy data
    final List<DummyEvent> dummyEvents = [
      DummyEvent(
        title: "TARUMT Tech Hackathon 2026",
        description: "Join the ultimate 48-hour coding challenge! Build innovative solutions for campus life and win amazing prizes including gadgets and internships.",
        location: "DKB, TARUMT Main Campus",
        date: "20 May 2026",
        time: "09:00 AM",
        fees: 0.0,
        imageUrl: "https://picsum.photos/seed/tech/600/300",
      ),
      DummyEvent(
        title: "Campus Music Festival",
        description: "Enjoy a night of live music featuring local student bands and guest performers. Food trucks and games will be available throughout the night.",
        location: "The Arena, TARUMT",
        date: "25 May 2026",
        time: "07:00 PM",
        fees: 15.0,
        imageUrl: "https://picsum.photos/seed/music/600/300",
      ),
      DummyEvent(
        title: "Career Fair: Future Leaders",
        description: "Connect with over 50 top companies looking for fresh graduates and interns. Bring your CV and dress to impress! Seminars will be held throughout the day.",
        location: "Main Hall, Block A",
        date: "02 June 2026",
        time: "10:00 AM",
        fees: 5.0,
        imageUrl: "https://picsum.photos/seed/career/600/300",
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: dummyEvents.length,
      itemBuilder: (context, index) {
        return _buildEventCard(context, dummyEvents[index]);
      },
    );
  }

  // 2. The Universal Event Card Widget
  Widget _buildEventCard(BuildContext context, DummyEvent event) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias, // Ensures image corners follow the card's shape
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Poster Image (Rectangle Frame) ---
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              event.imageUrl,
              fit: BoxFit.cover,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Title & Fees ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                    _buildFeeTag(event.fees),
                  ],
                ),
                const SizedBox(height: 10),

                // --- Description (Limited to 3 lines) ---
                Text(
                  event.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(height: 15),

                // --- Location ---
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Color(0xFF6A1B9A)),
                    const SizedBox(width: 5),
                    Text(
                      event.location,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // --- Date & Time ---
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      "${event.date} • ${event.time}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Fee Tag Widget
  Widget _buildFeeTag(double fee) {
    bool isFree = fee == 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isFree ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFree ? Colors.green : Colors.blue),
      ),
      child: Text(
        isFree ? "FREE" : "RM ${fee.toStringAsFixed(2)}",
        style: TextStyle(
          color: isFree ? Colors.green[700] : Colors.blue[700],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}