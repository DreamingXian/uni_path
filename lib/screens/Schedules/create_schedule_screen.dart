import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/schedule_service.dart';
import '../../models/schedule_model.dart';

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

  final _scheduleService = ScheduleService();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

  bool _isSaving = false;
  bool _isHomework = false;

  Future<void> _saveSchedule() async {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;

    // 1. Validation Checks
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User session not found.")));
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title is required")));
      return;
    }

    setState(() => _isSaving = true);

    // 2. Parse Times correctly
    final startDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);

    // For homework, we can set end time to null as allowed by your SQL schema
    DateTime? endDT;
    if (!_isHomework) {
      endDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);
    }

    try {
      // 3. Create Model (Ensure this matches your ScheduleModel constructor)
      final newSchedule = ScheduleModel(
        userId: user.id, // Pass the UUID directly
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        locationName: _isHomework ? "" : _locController.text.trim(),
        startTime: startDT,
        endTime: endDT,
        labelName: _labelController.text.isEmpty ? "General" : _labelController.text.trim(),
        isHomework: _isHomework,
      );

      // 4. Call Service (This handles Supabase + SQLite + Notifications)
      final int? newId = await _scheduleService.insertSchedule(newSchedule);

      if (mounted && newId != null) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully added to your timetable!")),
        );
      }
    } catch (e) {
      if (mounted) {
        // This will print the exact SQL or SQLite error for debugging
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Add Failed: $e")));
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
        backgroundColor: const Color(0xFF1A237E), // Matching your theme
        foregroundColor: Colors.white,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _buildTextField(_titleController, "Subject / Task Title", Icons.edit_calendar),
          const SizedBox(height: 15),

          if (!_isHomework) ...[
            _buildTextField(_locController, "Venue / Location", Icons.location_on),
            const SizedBox(height: 15),
          ],

          _buildTextField(_labelController, "Category (e.g. BMIT2013, Exams)", Icons.label),

          const Divider(height: 40),

          SwitchListTile(
            title: const Text("Is this Homework?", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Locations will be hidden for tasks"),
            value: _isHomework,
            onChanged: (val) => setState(() => _isHomework = val),
            activeColor: const Color(0xFF1A237E),
          ),

          const SizedBox(height: 10),

          ListTile(
            tileColor: Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: Text(_isHomework ? "Due Date" : "Class Date"),
            subtitle: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
            trailing: const Icon(Icons.calendar_month, color: Color(0xFF1A237E)),
            onTap: _pickDate,
          ),

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

          ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Save to Timetable", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildTimeTile(String label, TimeOfDay time, bool isStart) {
    return ListTile(
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}