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
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;

  late bool _isHomework;
  late bool _isRepeating;
  late List<bool> _selectedDays;
  final List<String> _weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

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
    _isRepeating = widget.item['is_repeating'] ?? false;

    _selectedDays = List.generate(7, (index) {
      if (widget.item['repeat_days'] != null) {
        final List<dynamic> days = widget.item['repeat_days'];
        return days.contains(index + 1);
      }
      return false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateSchedule() async {
    try {
      final originalStart = DateTime.parse(widget.item['start_time']).toLocal();
      final DateTime finalDate = _selectedDate ?? originalStart;
      final TimeOfDay startT = _startTime ?? TimeOfDay.fromDateTime(originalStart);
      final DateTime finalStartDateTime = DateTime(finalDate.year, finalDate.month, finalDate.day, startT.hour, startT.minute);

      DateTime? finalEndDateTime;

      // If it's NOT homework, we handle the end time as usual
      if (!_isHomework) {
        if (_endTime != null) {
          finalEndDateTime = DateTime(finalDate.year, finalDate.month, finalDate.day, _endTime!.hour, _endTime!.minute);
        } else if (widget.item['end_time'] != null) {
          final DateTime originalEnd = DateTime.parse(widget.item['end_time']).toLocal();
          finalEndDateTime = DateTime(finalDate.year, finalDate.month, finalDate.day, originalEnd.hour, originalEnd.minute);
        }
      }
      // If it IS homework, finalEndDateTime stays null unless you explicitly want one.

      List<int>? finalRepeatDays;
      if (_isRepeating && !_isHomework) {
        finalRepeatDays = [];
        for (int i = 0; i < _selectedDays.length; i++) {
          if (_selectedDays[i]) finalRepeatDays.add(i + 1);
        }
      }

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
        isRepeating: _isHomework ? false : _isRepeating,
        repeatDays: finalRepeatDays,
      );

      await ScheduleService().updateSchedule(updatedSchedule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated successfully")));
        Navigator.pop(context, true);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Schedule"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTextField(_titleController, "Title", Icons.title),
            const SizedBox(height: 15),
            _buildTextField(_locationController, "Location", Icons.location_on_outlined),
            const SizedBox(height: 15),
            _buildTextField(_descriptionController, "Description", Icons.description_outlined, maxLines: 3),

            const Divider(height: 30),

            // Homework Toggle
            SwitchListTile(
              title: const Text("Is this Homework?", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Deadlines and one-time tasks"),
              value: _isHomework,
              onChanged: (val) => setState(() {
                _isHomework = val;
                if (val) _isRepeating = false;
              }),
              activeColor: const Color(0xFF6A1B9A),
            ),

            // Weekly Repeating Section (Hides if Homework is selected)
            if (!_isHomework) ...[
              const Divider(),
              SwitchListTile(
                title: const Text("Weekly Repeating?", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_isRepeating ? "Recurs every week" : "One-time class/event"),
                value: _isRepeating,
                onChanged: (val) => setState(() {
                  _isRepeating = val;
                  if (val && !_selectedDays.contains(true)) {
                    _selectedDays[DateTime.now().weekday - 1] = true;
                  }
                }),
                activeColor: const Color(0xFF6A1B9A),
              ),

              if (_isRepeating) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ToggleButtons(
                    isSelected: _selectedDays,
                    onPressed: (index) => setState(() => _selectedDays[index] = !_selectedDays[index]),
                    borderRadius: BorderRadius.circular(10),
                    selectedColor: Colors.white,
                    fillColor: const Color(0xFF6A1B9A),
                    constraints: const BoxConstraints(minWidth: 45, minHeight: 40),
                    children: _weekDays.map((day) => Text(day, style: const TextStyle(fontSize: 12))).toList(),
                  ),
                ),
              ],
            ],

            const Divider(height: 40),

            if (!_isRepeating) ...[
              _buildPickerTile(
                icon: Icons.calendar_today,
                title: "Date",
                subtitle: DateFormat('EEEE, MMM d, yyyy').format(_selectedDate ?? originalStart),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? originalStart,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: _buildPickerTile(
                    icon: Icons.access_time,
                    title: _isHomework ? "Due Time" : "Starts",
                    subtitle: _startTime?.format(context) ?? DateFormat('h:mm a').format(originalStart),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.fromDateTime(originalStart));
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                ),
                // Only show "Ends" if it's NOT homework
                if (!_isHomework) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPickerTile(
                      icon: Icons.timer_off_outlined,
                      title: "Ends",
                      subtitle: _endTime?.format(context) ?? (originalEnd != null ? DateFormat('h:mm a').format(originalEnd) : "Not set"),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay.fromDateTime(originalEnd ?? originalStart.add(const Duration(hours: 1))));
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 40),
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
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildPickerTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1A237E), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}