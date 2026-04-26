import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/schedule_service.dart';
import 'edit_schedule_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isStudyModeActive = false;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  final _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEventStream().listen((event) {
      bool faceDown = event.z < -9.0;
      if (faceDown != _isStudyModeActive) setState(() => _isStudyModeActive = faceDown);
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Weekly Timetable"),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (sel, foc) => setState(() { _selectedDay = sel; _focusedDay = foc; }),
          ),
          _buildStudyModeBanner(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('schedules')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', userId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // 1. FILTER & SORT: Sorting locally ensures UI stays responsive
                final dayRecords = snapshot.data!.where((item) {
                  return isSameDay(DateTime.parse(item['start_time']).toLocal(), _selectedDay);
                }).toList();

                // ASCENDING SORT (Earlier times first)
                dayRecords.sort((a, b) => a['start_time'].compareTo(b['start_time']));

                final classes = dayRecords.where((i) => i['is_homework'] == false).toList();
                final homework = dayRecords.where((i) => i['is_homework'] == true).toList();

                if (dayRecords.isEmpty) return const Center(child: Text("No activities scheduled."));

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (classes.isNotEmpty) ...[
                      _buildHeader("Academic Classes", Icons.school),
                      ...classes.map((i) => _buildScheduleCard(context, i))
                    ],
                    if (homework.isNotEmpty) ...[
                      _buildHeader("Homework & Tasks", Icons.assignment),
                      ...homework.map((i) => _buildScheduleCard(context, i))
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1A237E)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
      ],
    ),
  );

  Widget _buildScheduleCard(BuildContext context, Map<String, dynamic> item) {
    final start = DateTime.parse(item['start_time']).toLocal();
    final end = item['end_time'] != null ? DateTime.parse(item['end_time']).toLocal() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          ScheduleService.formatTimeRange(start, end),
          style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600),
        ),
        // We use a SizedBox to give the Row a defined width
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // EDIT
              IconButton(
                tooltip: "Edit",
                icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditScheduleScreen(item: item)),
                  );
                },
              ),
              // DELETE
              IconButton(
                tooltip: "Delete",
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _confirmDelete(context, item), // Pass the whole item
              ),
            ],
          ),
        ),
      ),
    );
  }

  Set<int> _deletingIds = {};

  void _confirmDelete(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete '${item['title']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final int id = item['id'] is int ? item['id'] : int.parse(item['id'].toString());

              // 1. Close dialog
              Navigator.pop(dialogContext);

              // 2. OPTIMISTIC UPDATE: Hide it from UI immediately
              setState(() => _deletingIds.add(id));

              try {
                await _scheduleService.deleteSchedule(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted successfully")));
                }
              } catch (e) {
                // If it fails, put it back in the list
                setState(() => _deletingIds.remove(id));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyModeBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    color: _isStudyModeActive ? Colors.green.withOpacity(0.1) : Colors.transparent,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
            _isStudyModeActive ? Icons.auto_awesome : Icons.phone_android,
            size: 16,
            color: _isStudyModeActive ? Colors.green : Colors.grey
        ),
        const SizedBox(width: 8),
        Text(
          _isStudyModeActive ? "Study Mode Active" : "Place phone face-down to focus",
          style: TextStyle(fontSize: 12, color: _isStudyModeActive ? Colors.green : Colors.grey),
        ),
      ],
    ),
  );
}