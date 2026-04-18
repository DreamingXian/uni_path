import 'package:flutter/material.dart';
import 'events_screen.dart'; // To access DummyEvent and EventTime classes

import '../../models/event_model.dart';

class EventDetailScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    bool isFree = (event.fees ?? 0.0) == 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Details", style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FULL POSTER
            if (event.eventPosterUrl != null && event.eventPosterUrl!.isNotEmpty)
              Image.network(
                event.eventPosterUrl!,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                   width: double.infinity, height: 250, color: Colors.grey[300], child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                ),
              )
            else
              Container(width: double.infinity, height: 250, color: Colors.grey[300], child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. TITLE
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                  ),
                  const SizedBox(height: 10),

                  // 3. DESCRIPTION
                  if (event.description != null)
                    Text(
                      event.description!,
                      style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                    ),
                  const Divider(height: 40),

                  // 4. LOCATION NAME
                  const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 8),
                      Text(event.locationName ?? 'No location provided', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 5. MAP WITH POINTER (Mockup)
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.room, size: 40, color: Colors.red),
                        SizedBox(height: 8),
                        Text("Interactive Map Placeholder", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // 6. EVENT TIMES
                  const Text("Event Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (event.eventTimes != null)
                    ...event.eventTimes!.map((time) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 20, color: Color(0xFF6A1B9A)),
                          const SizedBox(width: 12),
                          Text(
                            "${time.startDateTime.day}/${time.startDateTime.month}/${time.startDateTime.year}: ${time.startDateTime.hour}:${time.startDateTime.minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )),
                  const SizedBox(height: 20),

                  // 7. FEES
                  const Text("Entry Fees", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    isFree ? "Complimentary (FREE)" : "RM ${(event.fees ?? 0).toStringAsFixed(2)} per person",
                    style: TextStyle(
                      fontSize: 16,
                      color: isFree ? Colors.green[700] : const Color(0xFF1A237E),
                      fontWeight: FontWeight.w600,
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
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isFree ? Colors.green : const Color(0xFF6A1B9A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // Action logic will be added later
            },
            child: Text(
              isFree ? "JOIN FREE" : "BUY TICKET",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}