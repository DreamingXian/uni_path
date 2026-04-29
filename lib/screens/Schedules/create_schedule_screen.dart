import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../services/schedule_service.dart';
import '../../models/schedule_model.dart';

class CreateScheduleScreen extends StatefulWidget {
  final DateTime? initialDate;
  const CreateScheduleScreen({super.key, this.initialDate});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController(); // Using this for description/category
  final _locController = TextEditingController();
  final _labelController = TextEditingController();
  final _scheduleService = ScheduleService();

  late DateTime _selectedDate = DateTime.now();
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  bool _isSaving = false;
  bool _isHomework = false;

  // Repeating Logic
  bool _isRepeating = false;
  final List<String> _weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  final List<bool> _selectedDays = List.generate(7, (_) => false);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    final now = DateTime.now();
    _startTime = TimeOfDay.fromDateTime(now);
    _endTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)));

    // Default select current day if initialDate is provided
    if (widget.initialDate != null) {
      _selectedDays[_selectedDate.weekday - 1] = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _saveSchedule() async {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session expired.")));
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title is required")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Prepare Data
      final startDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
      DateTime? endDT;
      if (!_isHomework) {
        endDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);
      }

      List<int>? repeatDays;
      if (_isRepeating) {
        repeatDays = [];
        for (int i = 0; i < _selectedDays.length; i++) {
          if (_selectedDays[i]) repeatDays.add(i + 1);
        }
      }

      final newSchedule = ScheduleModel(
        userId: user.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        locationName: _isHomework ? "N/A" : _locController.text.trim(),
        startTime: startDT,
        endTime: endDT,
        labelName: _labelController.text.isEmpty ? "General" : _labelController.text.trim(),
        isHomework: _isHomework,
        isRepeating: _isRepeating,
        repeatDays: repeatDays,
      );

      // 2. Insert Main Schedule (ONLY CALL THIS ONCE)
      final int? newId = await _scheduleService.insertSchedule(newSchedule);

      if (newId != null) {
        // 3. Calculate Reminder Timing
        DateTime reminderTime;
        if (_isHomework) {
          // Reminder at 8:00 AM on the due date
          reminderTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 8, 0);
        } else {
          // Reminder 10 minutes before class
          reminderTime = startDT.subtract(const Duration(minutes: 10));
        }

        // 4. Save to Database Reminders Table
        await _scheduleService.insertReminder(newId, reminderTime);

        // 5. Schedule Physical Phone Notification
        await NotificationService().scheduleReminder(
          id: newId.remainder(2147483647), // Stay in 32-bit range
          title: _titleController.text.trim(),
          startTime: startDT, // This is the original class/due time
          isHomework: _isHomework,
        );

        // 6. Success & UI Cleanup
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Schedule & Reminder saved!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add to Timetable", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _buildTextField(_titleController, "Subject / Task Title", Icons.edit_calendar),
          const SizedBox(height: 15),

          // CHANGED: From Category Filter to Description
          _buildTextField(
              _descController,
              "Description / Notes",
              Icons.description_outlined,
              maxLines: 3
          ),

          const SizedBox(height: 15),
          if (!_isHomework)
            _buildTextField(_locController, "Venue / Location", Icons.location_on),

          const Divider(height: 40),

          // --- REPEATING TOGGLE ---
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Weekly Repeating?", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Select days for recurring classes"),
            value: _isRepeating,
            onChanged: (val) => setState(() {
              _isRepeating = val;
              if (val) _isHomework = false;
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
                borderRadius: BorderRadius.circular(12),
                selectedColor: Colors.white,
                fillColor: const Color(0xFF6A1B9A),
                constraints: const BoxConstraints(minWidth: 45, minHeight: 40),
                children: _weekDays.map((day) => Text(day, style: const TextStyle(fontSize: 12))).toList(),
              ),
            ),
          ] else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Is this Homework?", style: TextStyle(fontWeight: FontWeight.bold)),
              value: _isHomework,
              onChanged: (val) => setState(() => _isHomework = val),
              activeColor: const Color(0xFF6A1B9A),
            ),
            _buildPickerTile(
              label: _isHomework ? "Due Date" : "Date",
              value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              icon: Icons.calendar_today,
              onTap: _pickDate,
            ),
          ],

          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildTimeTile("Starts", _startTime, true)),
              const SizedBox(width: 10),
              if (!_isHomework)
                Expanded(child: _buildTimeTile("Ends", _endTime, false)),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save to Timetable", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE HELPERS ---
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 40 : 0),
          child: Icon(icon, color: const Color(0xFF1A237E)),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // (Keeping other helpers like _pickDate, _buildPickerTile, _buildTimeTile same as your original)
  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildPickerTile({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Icon(icon, color: const Color(0xFF1A237E)),
      onTap: onTap,
    );
  }

  Widget _buildTimeTile(String label, TimeOfDay time, bool isStart) {
    return ListTile(
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
      },
    );
  }
}