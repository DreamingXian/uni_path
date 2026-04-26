import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/schedule_service.dart';
import '../../models/schedule_model.dart';

class EditScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditScheduleScreen({super.key, required this.item});

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  // 1. Controllers initialized with existing data
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;

  late bool _isHomework;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item['title']);
    _locationController = TextEditingController(text: widget.item['location_name'] ?? "");
    _descriptionController = TextEditingController(text: widget.item['description'] ?? "");
    _isHomework = widget.item['is_homework'] ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- Date & Time Pickers ---

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

  Future<void> _pickEndTime() async {
    TimeOfDay initial;
    if (widget.item['end_time'] != null) {
      initial = TimeOfDay.fromDateTime(DateTime.parse(widget.item['end_time']).toLocal());
    } else {
      initial = TimeOfDay.fromDateTime(
          DateTime.parse(widget.item['start_time']).toLocal().add(const Duration(hours: 1))
      );
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? initial,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  // --- The Core Update Logic ---

  Future<void> _updateSchedule() async {
    try {
      final originalStart = DateTime.parse(widget.item['start_time']).toLocal();

      // Resolve Final Date/Times
      final DateTime finalDate = _selectedDate ?? originalStart;
      final TimeOfDay startT = _startTime ?? TimeOfDay.fromDateTime(originalStart);

      final DateTime finalStartDateTime = DateTime(
        finalDate.year, finalDate.month, finalDate.day, startT.hour, startT.minute,
      );

      // Validation: Classes require an End Time, Homework does not.
      if (!_isHomework && _endTime == null && widget.item['end_time'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Classes require an End Time"), backgroundColor: Colors.red),
        );
        return;
      }

      DateTime? finalEndDateTime;
      if (_endTime != null || widget.item['end_time'] != null) {
        final TimeOfDay endT = _endTime ?? TimeOfDay.fromDateTime(
            widget.item['end_time'] != null
                ? DateTime.parse(widget.item['end_time']).toLocal()
                : originalStart.add(const Duration(hours: 1))
        );
        finalEndDateTime = DateTime(
          finalDate.year, finalDate.month, finalDate.day, endT.hour, endT.minute,
        );
      }

      // Prepare Model
      final updatedSchedule = ScheduleModel(
        id: widget.item['id'] is int ? widget.item['id'] : int.parse(widget.item['id'].toString()),
        userId: widget.item['user_id'],
        title: _titleController.text.trim(),
        locationName: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        isHomework: _isHomework,
        startTime: finalStartDateTime,
        endTime: finalEndDateTime,
        labelName: widget.item['label_name'],
      );

      // Execute Sync via Service
      await ScheduleService().updateSchedule(updatedSchedule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Schedule updated and notification reset")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final originalStart = DateTime.parse(widget.item['start_time']).toLocal();
    final originalEnd = widget.item['end_time'] != null ? DateTime.parse(widget.item['end_time']).toLocal() : null;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Edit Schedule"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTextField(_titleController, "Title", Icons.title),
            const SizedBox(height: 20),
            _buildTextField(_locationController, "Location", Icons.location_on_outlined),
            const SizedBox(height: 20),
            _buildTextField(_descriptionController, "Description", Icons.description_outlined, maxLines: 3),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),

            _buildPickerTile(
              icon: Icons.calendar_today,
              title: "Date",
              subtitle: DateFormat('EEEE, MMM d, yyyy').format(_selectedDate ?? originalStart),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            _buildPickerTile(
              icon: Icons.access_time,
              title: "Start Time",
              subtitle: _startTime?.format(context) ?? DateFormat('h:mm a').format(originalStart),
              onTap: _pickStartTime,
            ),
            const SizedBox(height: 12),
            _buildPickerTile(
              icon: Icons.timer_off_outlined,
              title: _isHomework ? "End Time (Optional)" : "End Time (Required *)",
              subtitle: _endTime?.format(context) ?? (originalEnd != null ? DateFormat('h:mm a').format(originalEnd) : "Not set"),
              onTap: _pickEndTime,
            ),

            const SizedBox(height: 15),
            SwitchListTile(
              title: const Text("Categorize as Homework?", style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text("Sets reminder to 24h before"),
              value: _isHomework,
              activeColor: const Color(0xFF6A1B9A),
              onChanged: (val) => setState(() => _isHomework = val),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updateSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildPickerTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1A237E)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.edit, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}