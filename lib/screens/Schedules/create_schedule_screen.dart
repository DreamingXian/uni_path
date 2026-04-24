import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/schedule_service.dart'; // USE THE SERVICE INSTEAD
import '../../models/schedule_model.dart'; // IMPORT THE MODEL

class CreateScheduleScreen extends StatefulWidget {
  const CreateScheduleScreen({super.key});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();
  final _labelController = TextEditingController();

  // Create an instance of the service
  final _scheduleService = ScheduleService();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

  bool _isSaving = false;
  bool _isHomework = false;

  Future<void> _saveSchedule() async {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;

    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session error. Please re-login.")));
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    setState(() => _isSaving = true);

    // Calculate actual DateTimes
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);

    try {
      // 1. Create a ScheduleModel object
      // This is much cleaner than raw Maps!
      final newSchedule = ScheduleModel(
        userId: user.id.toString(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        // LOGIC: If homework is selected, we pass empty string for location
        locationName: _isHomework ? "" : _locController.text.trim(),
        startTime: start,
        endTime: end,
        labelName: _labelController.text.isEmpty ? "General" : _labelController.text.trim(),
        labelColor: '#6A1B9A',
        isHomework: _isHomework,
      );

      // 2. Use your Service to handle Cloud, Local DB, AND Notifications
      // This solves the "cannot add" bug because the service handles it all!
      await _scheduleService.insertSchedule(newSchedule);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule saved successfully!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add to Timetable"),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
          : ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _buildTextField(_titleController, "Schedule Title", Icons.edit_calendar),
          const SizedBox(height: 15),

          // FEATURE: Only show location field if it is NOT homework
          if (!_isHomework) ...[
            _buildTextField(_locController, "Venue / Location", Icons.location_on),
            const SizedBox(height: 15),
          ],

          _buildTextField(_labelController, "Label (e.g., Exam, Class)", Icons.label_important),

          const Divider(height: 30),

          SwitchListTile(
            title: const Text("Homework Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Sets a reminder 1 day before due date"),
            value: _isHomework,
            activeColor: const Color(0xFF6A1B9A),
            onChanged: (bool value) => setState(() => _isHomework = value),
            secondary: Icon(Icons.assignment, color: _isHomework ? const Color(0xFF6A1B9A) : Colors.grey),
          ),

          const Divider(height: 30),

          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.grey)),
            title: Text(_isHomework ? "Due Date" : "Class Date"),
            subtitle: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
            trailing: const Icon(Icons.calendar_today, color: Color(0xFF6A1B9A)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2027),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),

          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildTimeTile("Start", _startTime, true)),
              const SizedBox(width: 10),
              Expanded(child: _buildTimeTile("End", _endTime, false)),
            ],
          ),

          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Confirm & Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // (Keeping your helper widgets exactly as they were...)
  Widget _buildTimeTile(String label, TimeOfDay time, bool isStart) {
    return ListTile(
      title: Text(label),
      subtitle: Text(time.format(context)),
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) {
          setState(() {
            if (isStart) _startTime = picked; else _endTime = picked;
          });
        }
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6A1B9A)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}