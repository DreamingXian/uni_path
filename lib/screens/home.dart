import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'auth_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UniPath - Dev Hub'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Temporary Navigation Menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- AUTHENTICATION SECTION ---
            // Inside HomePage ListView...
            Text('Welcome, ${user?.fullName ?? "Student"}!'),

            _buildNavButton(
              context,
              title: 'Go to Sign Up',
              icon: Icons.person_add,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen(showLogin: false)),
                );
              },
            ),

            _buildNavButton(
              context,
              title: 'Go to Login',
              icon: Icons.login,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen(showLogin: true)),
                );
              },
            ),

            const Divider(height: 40),

            // --- MODULES SECTION ---
            _buildNavButton(
              context,
              title: 'Events Module',
              icon: Icons.event,
              color: Colors.orange,
              onTap: () {
                // TODO: Link to Event List Screen
                print("Navigate to Events pagesss");
              },
            ),
            _buildNavButton(
              context,
              title: 'Community Hub',
              icon: Icons.forum,
              color: Colors.purple,
              onTap: () {
                // TODO: Link to Community Feed
                print("Navigate to Community");
              },
            ),
            _buildNavButton(
              context,
              title: 'Personal Schedule',
              icon: Icons.calendar_today,
              color: Colors.teal,
              onTap: () {
                // TODO: Link to Schedule/Reminders
                print("Navigate to Schedule");
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to keep code clean
  Widget _buildNavButton(BuildContext context,
      {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}