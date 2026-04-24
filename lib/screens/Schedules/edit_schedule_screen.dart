import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EditScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditScheduleScreen({super.key, required this.item});

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  late bool _isHomework;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime; // Added End Time variable

  @override
  void initState() {
    super.initState();
    _isHomework = widget.item['is_homework'] ?? false;
  }

  Future<void> _pickDate() async {
    final DateTime originalDate = DateTime.parse(widget.item['start_time']).toLocal();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? originalDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final DateTime originalDate = DateTime.parse(widget.item['start_time']).toLocal();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.fromDateTime(originalDate),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  // --- New Logic for Picking End Time ---
  Future<void> _pickEndTime() async {
    TimeOfDay initial;
    if (widget.item['end_time'] != null) {
      initial = TimeOfDay.fromDateTime(DateTime.parse(widget.item['end_time']).toLocal());
    } else {
      initial = TimeOfDay.fromDateTime(DateTime.parse(widget.item['start_time']).toLocal().add(const Duration(hours: 1)));
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? initial,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _updateSchedule() async {
    final originalStart = DateTime.parse(widget.item['start_time']).toLocal();

    // Resolve Date
    final DateTime finalDate = _selectedDate ?? originalStart;

    // Resolve Start Time
    final TimeOfDay startT = _startTime ?? TimeOfDay.fromDateTime(originalStart);
    final DateTime finalStartDateTime = DateTime(
      finalDate.year, finalDate.month, finalDate.day, startT.hour, startT.minute,
    );

    // Resolve End Time
    DateTime? finalEndDateTime;
    if (_endTime != null || widget.item['end_time'] != null) {
      final TimeOfDay endT = _endTime ?? TimeOfDay.fromDateTime(DateTime.parse(widget.item['end_time']).toLocal());
      finalEndDateTime = DateTime(
        finalDate.year, finalDate.month, finalDate.day, endT.hour, endT.minute,
      );
    }

    final String finalTitle = _titleController.text.trim().isEmpty ? widget.item['title'] : _titleController.text.trim();
    final String finalLocation = _locationController.text.trim().isEmpty ? (widget.item['location_name'] ?? "") : _locationController.text.trim();
    final String finalDescription = _descriptionController.text.trim().isEmpty ? (widget.item['description'] ?? "") : _descriptionController.text.trim();

    try {
      await Supabase.instance.client.from('schedules').update({
        'title': finalTitle,
        'location_name': finalLocation,
        'description': finalDescription,
        'is_homework': _isHomework,
        'start_time': finalStartDateTime.toIso8601String(),
        'end_time': finalEndDateTime?.toIso8601String(), // Updated End Time
      }).eq('id', widget.item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule Updated Successfully")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final originalStart = DateTime.parse(widget.item['start_time']).toLocal();
    final originalEnd = widget.item['end_time'] != null ? DateTime.parse(widget.item['end_time']).toLocal() : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Details"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text("Leave blank to keep original values.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(controller: _titleController, decoration: InputDecoration(labelText: "Title", border: const OutlineInputBorder())),
            const SizedBox(height: 20),
            TextField(controller: _locationController, decoration: InputDecoration(labelText: "Location", border: const OutlineInputBorder())),
            const SizedBox(height: 20),
            TextField(controller: _descriptionController, maxLines: 3, decoration: InputDecoration(labelText: "Description", border: const OutlineInputBorder())),
            const Divider(height: 40),

            // Date Picker
            _buildPickerTile(
              icon: Icons.calendar_today,
              title: "Change Date",
              subtitle: _selectedDate == null
                  ? "Original: ${DateFormat('yyyy-MM-dd').format(originalStart)}"
                  : "New: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),

            // Start Time Picker
            _buildPickerTile(
              icon: Icons.access_time,
              title: "Change Start Time",
              subtitle: _startTime == null
                  ? "Original: ${DateFormat('h:mm a').format(originalStart)}"
                  : "New: ${_startTime!.format(context)}",
              onTap: _pickStartTime,
            ),
            const SizedBox(height: 12),

            // End Time Picker
            _buildPickerTile(
              icon: Icons.timer_off_outlined,
              title: "Change End Time",
              subtitle: _endTime == null
                  ? (originalEnd != null ? "Original: ${DateFormat('h:mm a').format(originalEnd)}" : "No end time set")
                  : "New: ${_endTime!.format(context)}",
              onTap: _pickEndTime,
            ),

            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text("Categorize as Homework?"),
              value: _isHomework,
              activeColor: const Color(0xFF6A1B9A),
              onChanged: (val) => setState(() => _isHomework = val),
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _updateSchedule,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
                child: const Text("Update Schedule"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: onTap,
    );
  }
}