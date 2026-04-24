import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/user_provider.dart';
import '../../services/schedule_service.dart';
import '../auth_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isStudyModeActive = false;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Calendar State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initAccelerometer();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _initAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Study Mode logic: Flip phone face down
      bool faceDown = event.z < -9.0;
      if (faceDown != _isStudyModeActive) {
        setState(() => _isStudyModeActive = faceDown);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;
    if (user == null) return _buildLoginRequiredView(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Weekly Timetable", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. ONE-WEEK CALENDAR VIEW
          Container(
            color: Colors.white,
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.week, // Lock to one week
              availableCalendarFormats: const {CalendarFormat.week: 'Week'},
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(color: Color(0xFF6A1B9A), shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: Color(0xFF1A237E), shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildStudyModeStatus(),
          ),

          // 2. SEPARATED LIST (CLASSES VS HOMEWORK)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('schedules')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', user.id)
                  .order('start_time'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final dayRecords = snapshot.data!.where((item) {
                  final date = DateTime.parse(item['start_time']).toLocal();
                  return isSameDay(date, _selectedDay);
                }).toList();

                // Categorizing records
                final classes = dayRecords.where((item) => item['is_homework'] == false).toList();
                final homework = dayRecords.where((item) => item['is_homework'] == true).toList();

                if (dayRecords.isEmpty) return _buildEmptyState();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (classes.isNotEmpty) ...[
                      _buildSectionHeader("Academic Classes", Icons.school),
                      ...classes.map((item) => _buildScheduleCard(context, item)),
                      const SizedBox(height: 10),
                    ],
                    if (homework.isNotEmpty) ...[
                      _buildSectionHeader("Homework & Tasks", Icons.assignment_turned_in),
                      ...homework.map((item) => _buildScheduleCard(context, item)),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1A237E)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, Map<String, dynamic> item) {
    final startTime = DateTime.parse(item['start_time']).toLocal();
    final bool isHomework = item['is_homework'] == true;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(item['title'] ?? "Untitled", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(isHomework ? "Due Today" : item['location_name'] ?? "No Venue"),
        trailing: Text(
          "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
        ),
        onLongPress: () => _showDeleteDialog(context, item['id']),
      ),
    );
  }

  Widget _buildStudyModeStatus() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isStudyModeActive ? Colors.green.withOpacity(0.1) : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isStudyModeActive ? Colors.green : const Color(0xFF6A1B9A)),
      ),
      child: Row(
        children: [
          Icon(_isStudyModeActive ? Icons.auto_awesome : Icons.info_outline, color: _isStudyModeActive ? Colors.green : const Color(0xFF6A1B9A)),
          const SizedBox(width: 10),
          Expanded(child: Text(_isStudyModeActive ? "Study Mode: Notifications Silenced" : "Place phone face-down to focus", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("This will remove the schedule and cancel any upcoming notifications."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final int scheduleId = id is int ? id : int.parse(id.toString());

              // 1. Pop the dialog immediately so the user isn't waiting
              Navigator.pop(context);

              // 2. Perform the deletion in the background
              try {
                await ScheduleService().deleteSchedule(scheduleId);

                // 3. Optional: Show confirmation after background task finishes
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Schedule removed successfully")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error deleting: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text("No records for this day.", style: TextStyle(color: Colors.grey))));

  Widget _buildLoginRequiredView(BuildContext context) => const Center(child: Text("Please Log In"));
}