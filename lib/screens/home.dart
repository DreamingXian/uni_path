import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/payment_dashboard_service.dart';
import 'Events/create_event.dart';
import 'Events/payment_approval_dashboard.dart';
import 'Events/my_tickets.dart';
import 'auth_screen.dart';
import 'Events/manage_events.dart';
import 'Events/events_screen.dart';
import 'Events/scan_qr_nfc.dart';
import 'Posts/community_screen.dart';
import 'Schedules/schedule_screen.dart';
import 'Profiles/profile_screen.dart';
import 'Posts/create_post_screen.dart';


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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  // navigator pages dynamically generated to pass states down
  List<Widget> get _pages => [
    const CommunityScreen(), // Index 0
    EventsScreen(searchQuery: _searchController.text), // Index 1 receives live search
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
      drawer: _buildDrawer(context, user),
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
                if (!_isSearching) {
                   _searchController.clear();
                }
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
        onPressed: () => _handleFabAction(context, user),
        backgroundColor: const Color(0xFF6A1B9A),
        shape: const CircleBorder(),
        // Inside floatingActionButton:
        child: Icon(
          // Condition 1: If on Events tab AND user is a student, show Ticket icon
          _currentIndex == 1 && user?.role == 'student'
              ? Icons.confirmation_number
              : (_currentIndex == 0
              ? Icons.add_comment
              : _currentIndex == 1
              ? Icons.add_box
              : _currentIndex == 2
              ? Icons.alarm_add
              : Icons.home),
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
  /// Handles the action button based on the user's role and login status.
  void _handleFabAction(BuildContext context, dynamic user) {
    // 1. Check if logged in first (Gatekeeper)
    if (user == null) {
      _showLoginPrompt(context);
      return;
    }

    // 2. Handle actions based on which tab is active
    switch (_currentIndex) {
      case 0: // Community Hub
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostScreen()),
        ).then((value) {
          // We will add logic here later to refresh the feed if value == true
        });
        break;

      case 1: // Events Module
        if (user.role == 'society') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
          );
        } else {
          // Students or anyone else viewing events
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyTicketsScreen())
          );
        }
        break;

      case 2: // Schedules & Reminders
        print("Setting a Reminder...");
        // Future: Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateScheduleScreen()));
        break;

      case 3: // Profile
      // For example: Scroll to top or refresh profile data
        setState(() => _currentIndex = 0); // Return to home/community
        break;
    }
  }

  /// Shows a pop-up requiring the user to log in before proceeding.
  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Login Required"),
        content: const Text("Please log in to proceed with this action."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)),
              );
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }
  // -------------------------------------------------------
  // DRAWER
  // -------------------------------------------------------

  Widget _buildDrawer(BuildContext context, user) {
    final bool isLoggedIn = user != null;

    return Drawer(
      child: Column(
        children: [
          // --- Header ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 20, bottom: 20, right: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF6A1B9A), // Your Vibrant Purple
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. The Avatar
                CircleAvatar(
                  radius: 35, // Size control
                  backgroundColor: Colors.white,
                  backgroundImage: (isLoggedIn && user.avatarUrl != null)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (isLoggedIn && user.avatarUrl != null)
                      ? null
                      : const Icon(Icons.person, color: Color(0xFF6A1B9A), size: 40),
                ),

                const SizedBox(height: 15), // Precise spacing to prevent overlap

                // 2. The Name
                Text(
                  isLoggedIn ? user.fullName : 'Guest Student',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                // 3. The Email/ID
                if (isLoggedIn) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (user.studentId != null)
                    Text(
                      'ID: ${user.studentId}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ] else ...[
                  const Text(
                    'Explore UniPath Features',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          // --- Specific Module Links ---
          if (isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF6A1B9A)),
              title: const Text('Scan QR / NFC'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQRNFCScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF6A1B9A)),
              title: const Text('XXX'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(user.role == 'society' ? Icons.event_note : Icons.local_activity, color: const Color(0xFF6A1B9A)),
              title: Text(user.role == 'society' ? 'Manage Events' : 'Manage Tickets'),
              onTap: () {
                Navigator.pop(context);
                if (user.role == 'society') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageEventsScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
                }
              },
            ),
            // --- Payment Approval (society only) ---
            if (user.role == 'society')
              FutureBuilder<int>(
                future: PaymentDashboardService().getPendingPaymentCount(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data ?? 0;
                  return ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.receipt_long_outlined, color: Color(0xFF6A1B9A)),
                        if (pendingCount > 0)
                          Positioned(
                            top: -6,
                            right: -8,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: const Text('Payment Approval'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentApprovalDashboard()));
                    },
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.bookmark_border, color: Color(0xFF6A1B9A)),
              title: const Text('XXX'),
              onTap: () => Navigator.pop(context),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF6A1B9A)),
              title: const Text('Scan QR / NFC'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQRNFCScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz, color: Color(0xFF6A1B9A)),
              title: const Text('XXX'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz, color: Color(0xFF6A1B9A)),
              title: const Text('XXX'),
              onTap: () => Navigator.pop(context),
            ),
          ],

          const Spacer(),

          // --- Bottom General Links ---
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About UniPath'),
            onTap: () => Navigator.pop(context),
          ),
          
          const Divider(),

          // --- Login / Logout button ---
          if (isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => _handleLogout(context),
            )
          else
            ListTile(
              leading: const Icon(Icons.login, color: Color(0xFF6A1B9A)),
              title: const Text('Login', style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context); // close drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)),
                );
              },
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog and, if confirmed, signs the user out.
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // 1. Sign out from Supabase (clears server session)
      await AuthService().signOut();

      // 2. Clear the user from global state
      Provider.of<UserProvider>(context, listen: false).logout();

      // 3. Close the drawer and redirect to Login Page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)),
        (route) => false,
      );
    }
  }

  // -------------------------------------------------------
  // BOTTOM NAV
  // -------------------------------------------------------

  // Helper for Bottom Nav Icons
  Widget _buildBottomIcon(IconData icon, int index) {
    return IconButton(
      icon: Icon(icon, color: _currentIndex == index ? const Color(0xFF6A1B9A) : Colors.grey),
      onPressed: () => setState(() => _currentIndex = index),
    );
  }

}