import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'auth_screen.dart';
import 'Events/events_screen.dart';
import 'Posts/community_screen.dart';
import 'Schedules/schedule_screen.dart';
import 'Profiles/profile_screen.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // 0: Community, 1: Events, 2: Schedule, 3: Profile
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // navigator pages
  final List<Widget> _pages = [
    const CommunityScreen(), // Index 0
    const EventsScreen(),    // Index 1
    const ScheduleScreen(),  // Index 2
    const ProfileScreen(),   // Index 3
  ];

  // Function to scroll to top
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            // Sidebar Header (Optional but looks professional)
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF6A1B9A)),
              accountName: Text("UniPath User"),
              accountEmail: Text("student@tarumt.edu.my"),
              currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person)),
            ),
            // Placeholder Buttons
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context), // Closes the drawer
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About UniPath'),
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(), // Pushes the next items to the bottom
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                // Handle Logout Logic here
              },
            ),
          ],
        ),
      ),
      // --- 1. TOP AREA (AppBar with Search Logic) ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isSearching
            ? null
            : Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1A237E)),
            onPressed: () => Scaffold.of(context).openDrawer(), // open sidebar
          ),
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search UniPath...',
            border: InputBorder.none,
          ),
        )
            : GestureDetector(
          onTap: _scrollToTop,
          child: const Text(
            'UniPath Hub',
            style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: const Color(0xFF1A237E)),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
        ],
      ),

      // --- 2. BODY (Your Temporary Menu) ---
      body: _pages[_currentIndex],
      /*body: ListView(
        controller: _scrollController, // Linked to the "Back to Top" logic
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Welcome, ${user?.fullName ?? "Guest Student"}!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('This hub is a temporary navigation for development.'),
          const Divider(height: 40),

          _buildNavButton(context, 'Go to Sign Up', Icons.person_add, Colors.green, false),
          _buildNavButton(context, 'Go to Login', Icons.login, Colors.blue, true),

          // Add enough space to test scrolling
          const SizedBox(height: 800, child: Center(child: Text("Scroll down to test 'Back to Top'"))),
        ],
      ),*/

      // --- 3. CENTER ACTION BUTTON (FloatingActionButton) ---
      // Shifted up to be half-crossed by the bar edge
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Logic based on current page
          if (_currentIndex == 0) print("Creating a Post");
          if (_currentIndex == 1) print("Adding an Event");
          if (_currentIndex == 2) print("Setting a Reminder");
        },
        backgroundColor: const Color(0xFF6A1B9A),
        shape: const CircleBorder(),
        child: Icon(
          _currentIndex == 0 ? Icons.add_comment :
          _currentIndex == 1 ? Icons.add_box :
          _currentIndex == 2 ? Icons.alarm_add : Icons.home,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // --- 4. BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Creates the notch for the FAB
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomIcon(Icons.forum, 0),      // Community
              _buildBottomIcon(Icons.event, 1),      // Events
              const SizedBox(width: 40),             // Gap for the center button
              _buildBottomIcon(Icons.calendar_month, 2), // Schedule
              _buildBottomIcon(Icons.person, 3),     // Profile
            ],
          ),
        ),
      ),
    );
  }

  // Helper for Bottom Nav Icons
  Widget _buildBottomIcon(IconData icon, int index) {
    return IconButton(
      icon: Icon(icon, color: _currentIndex == index ? const Color(0xFF6A1B9A) : Colors.grey),
      onPressed: () => setState(() => _currentIndex = index),
    );
  }

  // Helper for your temporary Nav Buttons
  Widget _buildNavButton(BuildContext context, String title, IconData icon, Color color, bool showLogin) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthScreen(showLogin: showLogin))),
      ),
    );
  }
}