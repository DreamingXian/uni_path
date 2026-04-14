import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/tag_model.dart';
import '../../services/event_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // --- Form controllers ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isFree = false;

  final List<TagModel> _selectedTags = []; // holds chosen TagModel objects
  final List<String> _eventTimes = [""]; // Start with one time slot field

  // --- Poster image state ---
  File? _posterImage;
  final ImagePicker _picker = ImagePicker();
  final EventService _eventService = EventService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
              decoration: const InputDecoration(
                hintText: "Event Title",
                hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
                border: InputBorder.none,
              ),
            ),

            // 3. DESCRIPTION
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
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
                  onPressed: () async {
                    final result = await showDialog<List<TagModel>>(
                      context: context,
                      builder: (_) => _TagPickerDialog(
                        eventService: _eventService,
                        initialSelected: List.from(_selectedTags),
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() => _selectedTags
                        ..clear()
                        ..addAll(result));
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add"),
                ),
              ],
            ),
            // Selected tags preview chips
            if (_selectedTags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedTags.map((tag) => Chip(
                  label: Text('#${tag.name}',
                      style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFFEDE7F6),
                  side: const BorderSide(color: Color(0xFF6A1B9A)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFF6A1B9A)),
                  onDeleted: () => setState(() => _selectedTags.remove(tag)),
                )).toList(),
              )
            else
              const Text('No tags selected',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
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

// ---------------------------------------------------------------------------
// TAG PICKER DIALOG
// ---------------------------------------------------------------------------

class _TagPickerDialog extends StatefulWidget {
  final EventService eventService;
  final List<TagModel> initialSelected;

  const _TagPickerDialog({
    required this.eventService,
    required this.initialSelected,
  });

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<TagModel> _allTags = [];
  List<TagModel> _filtered = [];
  late List<TagModel> _selected;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _loadTags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final tags = await widget.eventService.getAllTags();
    if (mounted) {
      setState(() {
        _allTags = tags;
        _filtered = tags;
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _allTags
          : _allTags
              .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  bool _isSelected(TagModel tag) => _selected.any((t) => t.id == tag.id);

  void _toggleTag(TagModel tag) {
    setState(() {
      if (_isSelected(tag)) {
        _selected.removeWhere((t) => t.id == tag.id);
      } else if (_selected.length < 3) {
        _selected.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tags not yet selected shown in the grid (exclude already chosen)
    final available = _filtered.where((t) => !_isSelected(t)).toList();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    // Max dialog height = visible screen area minus insetPadding (40 top + 40 bottom)
    final maxDialogHeight = screenHeight - keyboardHeight - 80;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ---- Header ----
            Row(
              children: [
                const Expanded(
                  child: Text('Choose Tags',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                ),
                Text('${_selected.length}/3',
                    style: TextStyle(
                        color: _selected.length == 3 ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),

            // ---- Search bar ----
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search tags...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6A1B9A)),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Selected chips row ----
            if (_selected.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _selected.map((tag) => GestureDetector(
                  onTap: () => _toggleTag(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#${tag.name}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                )).toList(),
              ),
              const Divider(height: 20),
            ],

            // ---- Available tags grid ----
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No more tags found',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final tag = available[i];
                    final atLimit = _selected.length >= 3;
                    return GestureDetector(
                      onTap: atLimit ? null : () => _toggleTag(tag),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: atLimit ? Colors.grey[100] : const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: atLimit ? Colors.grey[300]! : const Color(0xFF6A1B9A),
                          ),
                        ),
                        child: Text(
                          '#${tag.name}',
                          style: TextStyle(
                            color: atLimit ? Colors.grey : const Color(0xFF6A1B9A),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // ---- Action buttons ----
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, widget.initialSelected),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
            ],
            ),    // end Column
          ),      // end SingleChildScrollView
        ),        // end Padding
      ),          // end ConstrainedBox
    );            // end Dialog
  }
}
