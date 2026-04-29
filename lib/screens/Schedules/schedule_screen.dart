import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/schedule_service.dart';
import '../auth_screen.dart';
import 'edit_schedule_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final Function(DateTime)? onDateChanged;

  const ScheduleScreen({super.key, this.onDateChanged});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isStudyModeActive = false;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  final _scheduleService = ScheduleService();

  final Set<int> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEventStream().listen((event) {
      bool faceDown = event.z < -9.0;
      if (faceDown != _isStudyModeActive) {
        if (mounted) setState(() => _isStudyModeActive = faceDown);
      }
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
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (sel, foc) {
              setState(() {
                _selectedDay = sel;
                _focusedDay = foc;
              });
              if (widget.onDateChanged != null) {
                widget.onDateChanged!(sel);
              }
            },
          ),
          _buildStudyModeBanner(),
          Expanded(
            child: userId == null
                ? _buildGuestPlaceholder()
                : StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('schedules')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // --- REPEATING LOGIC FILTER ---
                final dayRecords = snapshot.data!.where((item) {
                  final id = item['id'] is int ? item['id'] : int.parse(item['id'].toString());
                  final isNotDeleted = !_deletingIds.contains(id);

                  // 1. Check for one-time specific date matches
                  final startTime = DateTime.parse(item['start_time']);
                  bool matchesDate = isSameDay(startTime, _selectedDay);

                  // 2. Check for repeating weekday matches
                  bool matchesRepeating = false;
                  if (item['is_repeating'] == true && item['repeat_days'] != null) {
                    final List<dynamic> repeatDays = item['repeat_days'];
                    if (repeatDays.contains(_selectedDay!.weekday)) {
                      matchesRepeating = true;
                    }
                  }

                  return (matchesDate || matchesRepeating) && isNotDeleted;
                }).toList();

                // Sort by time
                dayRecords.sort((a, b) {
                  final timeA = TimeOfDay.fromDateTime(DateTime.parse(a['start_time']));
                  final timeB = TimeOfDay.fromDateTime(DateTime.parse(b['start_time']));
                  if (timeA.hour != timeB.hour) return timeA.hour.compareTo(timeB.hour);
                  return timeA.minute.compareTo(timeB.minute);
                });

                if (dayRecords.isEmpty) return const Center(child: Text("No activities scheduled."));

                final classes = dayRecords.where((i) => i['is_homework'] == false).toList();
                final homework = dayRecords.where((i) => i['is_homework'] == true).toList();

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

  // --- UI HELPERS ---
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
    final start = DateTime.parse(item['start_time']);
    final end = item['end_time'] != null ? DateTime.parse(item['end_time']) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        // leading icon removed as requested
        title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ScheduleService.formatTimeRange(start, end),
              style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600),
            ),
            if (item['description'] != null && item['description'].toString().isNotEmpty)
              Text(item['description'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => EditScheduleScreen(item: item)));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _confirmDelete(context, item),
            ),
          ],
        ),
      ),
    );
  }

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
              Navigator.pop(dialogContext);
              setState(() => _deletingIds.add(id));
              try {
                await _scheduleService.deleteSchedule(id);
              } catch (e) {
                if (mounted) {
                  setState(() => _deletingIds.remove(id));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
                }
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
        Icon(_isStudyModeActive ? Icons.auto_awesome : Icons.phone_android, size: 16, color: _isStudyModeActive ? Colors.green : Colors.grey),
        const SizedBox(width: 8),
        Text(
          _isStudyModeActive ? "Study Mode Active" : "Place phone face-down to focus",
          style: TextStyle(fontSize: 12, color: _isStudyModeActive ? Colors.green : Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildGuestPlaceholder() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text("Viewing as Guest", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true))),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
          child: const Text("Login", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}