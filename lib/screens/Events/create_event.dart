import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../models/tag_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event_model.dart';
import '../../models/event_time_model.dart';
import '../../services/event_service.dart';
import 'location_picker_screen.dart';
import 'package:intl/intl.dart';

class _TimeSlot {
  DateTime? start;
  DateTime? end;
  _TimeSlot({this.start, this.end});
}

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // --- Form controllers ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isFree = false;
  bool _isSubmitting = false;

  final List<TagModel> _selectedTags = []; // holds chosen TagModel objects
  final List<_TimeSlot> _eventTimes = [_TimeSlot()]; // Start with one time slot field

  // --- Picked map coordinates ---
  LatLng? _pinnedLocation;
  String? _pinnedAddress;

  // --- Poster image state ---
  File? _posterImage;
  File? _paymentQrImage;
  final ImagePicker _picker = ImagePicker();
  final EventService _eventService = EventService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _feeController.dispose();
    _capacityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initialDate, {DateTime? minDateTime}) async {
    final firstDate = minDateTime != null 
        ? DateTime(minDateTime.year, minDateTime.month, minDateTime.day) 
        : DateTime.now();

    DateTime? initial = initialDate ?? DateTime.now();
    if (initial.isBefore(firstDate)) {
      initial = firstDate;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6A1B9A)),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return null;

    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6A1B9A)),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return null;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (minDateTime != null && selected.isBefore(minDateTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time cannot be earlier than start time.')),
        );
      }
      return null;
    }

    return selected;
  }

  // Opens bottom sheet to pick source; replaces current poster if confirmed
  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
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

  Future<void> _pickPaymentQrFromSource(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _paymentQrImage = File(picked.path));
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

  Future<void> _handleAction(String status) async {
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event title is required.')));
      return;
    }

    if (_paymentQrImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment QR Code is required for all events.')));
      return;
    }

    final validTimes = _eventTimes.where((t) => t.start != null).toList();

    if (status == 'published') {
      if (_descriptionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Description is required for publishing.')));
        return;
      }
      if (validTimes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one event schedule is required for publishing.')));
        return;
      }
      if (_capacityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capacity is required for publishing.')));
        return;
      }
      if (!_isFree && _feeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fees amount is required for publishing paid events.')));
        return;
      }
    }

    List<String> emptyFields = [];
    if (_posterImage == null) emptyFields.add('Event Poster');
    
    if (status == 'draft') {
      if (_descriptionController.text.trim().isEmpty) emptyFields.add('Description');
      if (validTimes.isEmpty) emptyFields.add('Event Schedule');
      if (_capacityController.text.trim().isEmpty) emptyFields.add('Capacity');
      if (!_isFree && _feeController.text.trim().isEmpty) emptyFields.add('Fees');
    }

    if (_locationNameController.text.trim().isEmpty) emptyFields.add('Location Name');
    if (_pinnedLocation == null) emptyFields.add('Map Location');
    if (_noteController.text.trim().isEmpty) emptyFields.add('Additional Notes');

    String promptMsg = status == 'draft' 
        ? "Are you sure you want to save this event as a draft?"
        : "Are you sure you want to publish this event?";

    if (emptyFields.isNotEmpty) {
      promptMsg += "\n\nThe following optional fields are currently empty:\n" + 
                   emptyFields.map((e) => "- $e").join("\n") +
                   "\n\nDo you still want to proceed?";
    }

    final String titleStr = status == 'draft' ? "Save as Draft" : "Publish Event";

    _showConfirmationPrompt(titleStr, promptMsg, () => _submitEvent(status));
  }

  Future<void> _submitEvent(String status) async {
    final validTimes = _eventTimes.where((t) => t.start != null).toList();

    setState(() => _isSubmitting = true);
    try {
      String? posterUrl;
      if (_posterImage != null) {
        posterUrl = await _eventService.uploadPoster(_posterImage!);
      }

      String? paymentQrUrl;
      if (_paymentQrImage != null) {
        paymentQrUrl = await _eventService.uploadPaymentQR(_paymentQrImage!);
      }

      final feesVal = _isFree ? 0.0 : double.tryParse(_feeController.text.trim());
      final capacityVal = int.tryParse(_capacityController.text.trim());
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) throw Exception("User is not logged in");

      final event = EventModel(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        locationName: _locationNameController.text.trim(),
        latitude: _pinnedLocation?.latitude,
        longitude: _pinnedLocation?.longitude,
        status: status,
        createdBy: user.id,
        fees: feesVal,
        capacity: capacityVal,
        eventPosterUrl: posterUrl,
        note: _noteController.text.trim(),
        paymentQrUrl: paymentQrUrl,
        createdAt: DateTime.now(),
      );

      final eventId = await _eventService.insertEvent(event);
      if (eventId != null) {
        final timeModels = validTimes.map((t) => EventTimeModel(
          eventId: eventId,
          startDateTime: t.start!,
          endDateTime: t.end ?? t.start!, // If end time is missing, default to start time
        )).toList();
        await _eventService.insertEventTimes(timeModels);

        if (_selectedTags.isNotEmpty) {
          await _eventService.addTagsToEvent(eventId, _selectedTags.map((t) => t.id!).toList());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(status == 'published' ? 'Event Published!' : 'Saved as Draft!')),
          );
          Navigator.pop(context, true); // true implies success
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showConfirmationPrompt(String title, String message, VoidCallback onConfirm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
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
              maxLength: 30,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
              decoration: const InputDecoration(
                hintText: "Event Title",
                hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
                border: InputBorder.none,
                counterText: '', // Hide default counter text if preferred, removing this line shows it
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
                    FocusScope.of(context).unfocus();
                    final result = await showDialog<List<TagModel>>(
                      context: context,
                      builder: (_) => _TagPickerDialog(
                        eventService: _eventService,
                        initialSelected: List.from(_selectedTags),
                      ),
                    );
                    if (!mounted) return;
                    FocusScope.of(context).unfocus();
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
            TextField(
              controller: _locationNameController,
              maxLength: 30,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on, color: Color(0xFF6A1B9A)),
                hintText: "Venue name (e.g. DKB, Room A101)",
              ),
            ),
            const SizedBox(height: 10),

            // Pinned coordinates preview
            if (_pinnedLocation != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6A1B9A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop, color: Color(0xFF6A1B9A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pinnedAddress ??
                            '${_pinnedLocation!.latitude.toStringAsFixed(5)}, '
                            '${_pinnedLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF4A148C)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () => setState(() {
                        _pinnedLocation = null;
                        _pinnedAddress = null;
                      }),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

            // Mini map preview
            if (_pinnedLocation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 160,
                    child: FlutterMap(
                      // Key forces a full widget rebuild when location changes,
                      // so initialCenter always reflects the new coordinates.
                      key: ValueKey(
                        '${_pinnedLocation!.latitude},${_pinnedLocation!.longitude}',
                      ),
                      options: MapOptions(
                        initialCenter: _pinnedLocation!,
                        initialZoom: 15.5,
                        // Disable all interaction — this is a read-only preview
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.uni_path.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pinnedLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Color(0xFF6A1B9A),
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // MAP BUTTON
            OutlinedButton.icon(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final result = await Navigator.push<LocationResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                      initialPosition: _pinnedLocation,
                    ),
                  ),
                );
                if (!mounted) return;
                FocusScope.of(context).unfocus();
                if (result != null && mounted) {
                  setState(() {
                    _pinnedLocation = LatLng(result.latitude, result.longitude);
                    _pinnedAddress = result.displayName;
                  });
                }
              },
              icon: Icon(
                _pinnedLocation != null ? Icons.edit_location_alt : Icons.map_outlined,
                color: const Color(0xFF6A1B9A),
              ),
              label: Text(
                _pinnedLocation != null ? 'Change Map Location' : 'Select Location on Map',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                side: const BorderSide(color: Color(0xFF6A1B9A)),
                foregroundColor: const Color(0xFF6A1B9A),
              ),
            ),
            const SizedBox(height: 25),

            // 6. EVENT TIMES
            const Text("Event Schedule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _eventTimes.length,
              itemBuilder: (context, index) {
                final slot = _eventTimes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      // Start Date Time
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            final dt = await _pickDateTime(slot.start);
                            if (!mounted) return;
                            FocusScope.of(context).unfocus();
                            if (dt != null) {
                              setState(() => slot.start = dt);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              slot.start != null 
                                  ? DateFormat('d MMM yyy, h:mm a').format(slot.start!) 
                                  : "Start Time",
                              style: TextStyle(
                                color: slot.start != null ? Colors.black87 : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: slot.start != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text("~", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      // End Date Time
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            if (slot.start == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a start time first.')),
                              );
                              return;
                            }
                            final dt = await _pickDateTime(
                              slot.end ?? slot.start, 
                              minDateTime: slot.start,
                            );
                            if (!mounted) return;
                            FocusScope.of(context).unfocus();
                            if (dt != null) {
                              setState(() => slot.end = dt);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              slot.end != null 
                                  ? DateFormat('d MMM yyy, h:mm a').format(slot.end!) 
                                  : "End Time",
                              style: TextStyle(
                                color: slot.end != null ? Colors.black87 : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: slot.end != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      // Remove button
                      if (_eventTimes.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          onPressed: () => setState(() => _eventTimes.removeAt(index)),
                          padding: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        )
                      else
                        const SizedBox(width: 28), // Placeholder for alignment when no cross
                    ],
                  ),
                );
              },
            ),
            if (_eventTimes.length < 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _eventTimes.add(_TimeSlot()));
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add Another Time", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6A1B9A),
                  ),
                ),
              ),
            const SizedBox(height: 15),

            // 7. CAPACITY
            const Text("Capacity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (val) {
                if (val.isNotEmpty) {
                  final intVal = int.tryParse(val) ?? 0;
                  if (intVal <= 0) {
                    _capacityController.clear();
                  } else if (val.startsWith('0')) {
                    _capacityController.text = intVal.toString();
                    _capacityController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _capacityController.text.length),
                    );
                  }
                }
              },
              decoration: const InputDecoration(
                hintText: "Maximum participants (e.g. 50)",
                prefixIcon: Icon(Icons.people_outline, color: Color(0xFF6A1B9A)),
              ),
            ),
            const SizedBox(height: 25),

            // 8. FEES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Fees (RM)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text("Free Event", style: TextStyle(fontSize: 14)),
                    Checkbox(
                      value: _isFree,
                      onChanged: (val) {
                        setState(() {
                          _isFree = val!;
                          if (_isFree) {
                            _feeController.text = "0";
                          } else {
                            _feeController.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            TextField(
              controller: _feeController,
              enabled: !_isFree,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (val) {
                if (!_isFree && val.isNotEmpty) {
                  final intVal = int.tryParse(val) ?? 0;
                  if (intVal <= 0) {
                    _feeController.clear();
                  } else if (val.startsWith('0')) {
                    // Prevent leading zeros for valid numbers
                    _feeController.text = intVal.toString();
                    _feeController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _feeController.text.length),
                    );
                  }
                }
              },
              decoration: InputDecoration(
                hintText: _isFree ? "0" : "Enter Amount (e.g. 10)",
                filled: _isFree,
                fillColor: _isFree ? Colors.grey[100] : null,
                prefixText: _isFree ? null : 'RM ',
              ),
            ),
            const SizedBox(height: 15),

            // 9. NOTE
            const Text("Additional Notes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "E.g. Dress code, things to bring...",
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 35), // Align icon with top of hint text
                  child: Icon(Icons.note_alt_outlined, color: Color(0xFF6A1B9A)),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 10. PAYMENT QR UPLOAD
            const Text("Payment QR Code", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: () async {
                FocusScope.of(context).unfocus();
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Upload Society Payment QR',
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
                            await _pickPaymentQrFromSource(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                ),
                child: _paymentQrImage != null
                    ? Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_paymentQrImage!, width: double.infinity, height: 150, fit: BoxFit.contain), // Not cropped
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => setState(() => _paymentQrImage = null),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, size: 40, color: Color(0xFF6A1B9A)),
                          SizedBox(height: 10),
                          Text("Tap to upload Payment QR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 50),

            // 10. ACTION BUTTONS
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleAction('draft'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(color: Color(0xFF6A1B9A)),
                            foregroundColor: const Color(0xFF6A1B9A),
                          ),
                          child: const Text("Save as Draft"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleAction('published'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text("Publish Event"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _showConfirmationPrompt(
                          "Cancel",
                          "Are you sure you want to cancel event creation? All your progress will be lost.",
                          () => Navigator.pop(context),
                        );
                      },
                      child: const Text("Cancel", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      )
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
