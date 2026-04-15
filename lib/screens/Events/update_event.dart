import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateEventScreen extends StatelessWidget {
  final EventModel event;

  const UpdateEventScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    // Formatting schedules
    List<String> formattedSchedules = [];
    if (event.eventTimes != null) {
      formattedSchedules = event.eventTimes!.map((t) {
        final start = DateFormat('dd MMM yyyy, hh:mm a').format(t.startDateTime);
        final end = DateFormat('hh:mm a').format(t.endDateTime);
        return "$start ~ $end";
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Event Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
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

            const SizedBox(height: 40),

            // 9. Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement Cancel logic
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text("Cancel Event"),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement Update flow logic
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("Update"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
}
