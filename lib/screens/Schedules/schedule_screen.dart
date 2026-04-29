import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/schedule_service.dart';
import '../auth_screen.dart';
import 'edit_schedule_screen.dart';
import '../../models/schedule_model.dart';

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

  // Using int as the key for deleting status
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

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Weekly Timetable"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _refresh,
          )
        ],
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
                : FutureBuilder<List<ScheduleModel>>(
              future: _scheduleService.getMySchedules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Catch potential formatting errors in the model mapping
                if (snapshot.hasError) {
                  return Center(child: Text("Data Error: ${snapshot.error}"));
                }

                final allSchedules = snapshot.data ?? [];

                // --- FILTERING LOGIC ---
                final dayRecords = allSchedules.where((item) {
                  if (item.id == null) return false;
                  final isNotDeleted = !_deletingIds.contains(item.id);

                  // 1. Check for one-time date match
                  bool matchesDate = isSameDay(item.startTime, _selectedDay);

                  // 2. Check for repeating weekday match
                  bool matchesRepeating = false;
                  if (item.isRepeating && (item.repeatDays as List).map((e) => int.parse(e.toString())).toList().contains(_selectedDay!.weekday)) {
                    matchesRepeating = true;
                  }

                  return (matchesDate || matchesRepeating) && isNotDeleted;
                }).toList();

                // Sort by time
                dayRecords.sort((a, b) => a.startTime.compareTo(b.startTime));

                if (dayRecords.isEmpty) {
                  return const Center(child: Text("No activities scheduled for today."));
                }

                final classes = dayRecords.where((i) => !i.isHomework).toList();
                final homework = dayRecords.where((i) => i.isHomework).toList();

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

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

  Widget _buildScheduleCard(BuildContext context, ScheduleModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ScheduleService.formatTimeRange(item.startTime, item.endTime),
              style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600),
            ),
            if (item.description != null && item.description!.isNotEmpty)
              Text(
                item.description!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
              onPressed: () async {
                // Converting back to JSON for the Edit screen's requirement
                await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditScheduleScreen(item: item.toMap()))
                );
                _refresh();
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

  void _confirmDelete(BuildContext context, ScheduleModel item) {
    if (item.id == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete '${item.title}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _deletingIds.add(item.id!));
              try {
                await _scheduleService.deleteSchedule(item.id!);
                _refresh();
              } catch (e) {
                if (mounted) {
                  setState(() => _deletingIds.remove(item.id!));
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Delete failed: $e"))
                  );
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