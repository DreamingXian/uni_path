import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  bool _isFree = false;
  final List<String> _selectedTags = [];
  final List<String> _eventTimes = [""]; // Start with one time slot field

  // --- Poster image state ---
  File? _posterImage;
  final ImagePicker _picker = ImagePicker();

  // Opens bottom sheet to pick source; replaces current poster if confirmed
  Future<void> _pickImage() async {
    // If a poster already exists, ask first
    if (_posterImage != null) {
      final action = await _showChangeImageDialog();
      if (action == _PosterAction.keep) return;
      if (action == _PosterAction.remove) {
        setState(() => _posterImage = null);
        return;
      }
      // action == _PosterAction.change → fall through to picker
    }

    await _showImageSourceSheet();
  }

  // Bottom sheet: Gallery or Camera
  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Event Poster',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE7F6),
                  child: Icon(Icons.photo_library_outlined, color: Color(0xFF6A1B9A)),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE7F6),
                  child: Icon(Icons.camera_alt_outlined, color: Color(0xFF6A1B9A)),
                ),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85, // Compress slightly to keep upload size reasonable
    );
    if (picked != null && mounted) {
      setState(() => _posterImage = File(picked.path));
    }
  }

  // Dialog shown when user taps an already-set poster
  Future<_PosterAction?> _showChangeImageDialog() async {
    return await showDialog<_PosterAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Event Poster'),
        content: const Text('What would you like to do with the current poster?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PosterAction.keep),
            child: const Text('Keep It'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, _PosterAction.remove),
            child: const Text('Remove'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, _PosterAction.change),
            child: const Text('Change Photo'),
          ),
        ],
      ),
    );
  }

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
            // 1. IMAGE PICKER / PREVIEW
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _posterImage != null ? const Color(0xFF6A1B9A) : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: _posterImage != null
                    // --- Preview mode ---
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_posterImage!, fit: BoxFit.cover),
                          // Subtle overlay hint
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Tap to change', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    // --- Empty state ---
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Color(0xFF6A1B9A)),
                          SizedBox(height: 8),
                          Text("Add Event Poster",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Tap to upload from gallery or camera",
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
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

/// Actions the user can choose when tapping an existing poster image.
enum _PosterAction { keep, change, remove }