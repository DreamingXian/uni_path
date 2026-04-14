import 'package:flutter/material.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  bool _isFree = false;
  final List<String> _selectedTags = [];
  final List<String> _eventTimes = [""]; // Start with one time slot field

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create New Event", style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE PLACEHOLDER
            GestureDetector(
              onTap: () => print("Pick Image Action"),
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 40, color: Color(0xFF6A1B9A)),
                    SizedBox(height: 8),
                    Text("Add Event Poster", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 2. TITLE
            const TextField(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
              decoration: InputDecoration(
                hintText: "Event Title",
                hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
                border: InputBorder.none,
              ),
            ),

            // 3. DESCRIPTION
            const TextField(
              maxLines: 4,
              style: TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: "Tell students what this event is about...",
                border: InputBorder.none,
              ),
            ),
            const Divider(height: 40),

            // 4. TAGS (Max 3)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tags (Max 3)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _selectedTags.length < 3 ? () {} : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add"),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _selectedTags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
            const SizedBox(height: 20),

            // 5. LOCATION
            const Text("Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.location_on, color: Color(0xFF6A1B9A)),
                hintText: "Enter Venue Name (e.g. DKB)",
              ),
            ),
            const SizedBox(height: 10),
            // MAP BUTTON
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.map_outlined),
              label: const Text("Select Location on Map"),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
            ),
            const SizedBox(height: 25),

            // 6. EVENT TIMES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Event Schedule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => setState(() => _eventTimes.add("")),
                  icon: const Icon(Icons.more_time, size: 18),
                  label: const Text("Add Time"),
                ),
              ],
            ),
            ..._eventTimes.map((_) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: TextField(
                readOnly: true, // Typically opened via a DateTime picker
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.access_time),
                  hintText: "Pick Date & Time",
                ),
              ),
            )),
            const SizedBox(height: 25),

            // 7. FEES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Fees (RM)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text("Free Event", style: TextStyle(fontSize: 14)),
                    Checkbox(
                      value: _isFree,
                      onChanged: (val) => setState(() => _isFree = val!),
                    ),
                  ],
                ),
              ],
            ),
            TextField(
              enabled: !_isFree,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: _isFree ? "0.00" : "Enter Amount",
                filled: _isFree,
                fillColor: _isFree ? Colors.grey[100] : null,
              ),
            ),
            const SizedBox(height: 50),

            // 8. ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("Save as Draft"),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("Create Event"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}