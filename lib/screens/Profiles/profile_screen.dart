import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'saved_posts_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;

    if (user == null) {
      return const Center(child: Text("Please log in to view your profile."));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text("Profile"), backgroundColor: Colors.white, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Header
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
              child: Text(user.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(user.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Center(child: Text(user.email, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 32),

          // --- Navigation to Saved Posts ---
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: ListTile(
              leading: const Icon(Icons.bookmark, color: Color(0xFF6A1B9A)),
              title: const Text("Saved Posts", style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPostsScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }
}