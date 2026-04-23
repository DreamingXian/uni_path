import 'package:flutter/material.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "My Schedule",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
          ),
          const SizedBox(height: 16),
          _buildScheduleItem("Software Engineering Lecture", "09:00 AM - 11:00 AM", Icons.laptop_mac),
          _buildScheduleItem("Database Management Lab", "02:00 PM - 04:00 PM", Icons.storage),
          const SizedBox(height: 24),
          const Divider(),
          _buildStudyModeStatus(),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String title, String time, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6A1B9A),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(time),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildStudyModeStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt, color: Color(0xFF6A1B9A)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Intelligent Study Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Active: Phone will silence when face-down.", style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}