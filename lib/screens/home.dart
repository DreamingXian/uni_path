import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

// Providers & Services
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/payment_dashboard_service.dart';
import '../services/sensor_service.dart';

// Screens
import 'Events/create_event.dart';
import 'Events/payment_approval_dashboard.dart';
import 'Events/my_tickets.dart';
import 'auth_screen.dart';
import 'Events/manage_events.dart';
import 'Events/events_screen.dart';
import 'Events/scan_qr_nfc.dart';
import 'Posts/community_screen.dart';
import 'Schedules/schedule_screen.dart';
import 'Schedules/create_schedule_screen.dart';
import 'Profiles/profile_screen.dart';
import 'Profiles/saved_posts_screen.dart';
import 'Posts/create_post_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  DateTime _selectedScheduleDate = DateTime.now();
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _updatePages();

    // Initialize Study Mode hardware listener on boot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sensorService = Provider.of<SensorService>(context, listen: false);
      sensorService.initStudyMode();
    });

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _updatePages();
        });
      }
    });
  }

  void _updatePages() {
    _pages = [
      const CommunityScreen(),
      EventsScreen(
        key: ValueKey('events_refresh_${_searchController.text}'),
        searchQuery: _searchController.text,
      ),
      ScheduleScreen(
        onDateChanged: (newDate) {
          _selectedScheduleDate = newDate;
        },
      ),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    // Stop listening to sensors when app is closed to save battery
    final sensorService = Provider.of<SensorService>(context, listen: false);
    sensorService.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = Provider.of<UserProvider>(context).currentUser;
    // Watch the SensorService for orientation changes
    final sensorService = Provider.of<SensorService>(context);

    return Scaffold(
      drawer: _buildDrawer(context, user),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isSearching ? null : Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1A237E)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(hintText: 'search_hint'.tr(), border: InputBorder.none),
        )
            : GestureDetector(
          onTap: _scrollToTop,
          child: Text('unipath_hub'.tr(),
              style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
        ),
        centerTitle: true,
        actions: [
          // --- STUDY MODE UI INDICATOR ---
          if (sensorService.isStudyModeActive)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                message: 'Study Mode Active',
                child: Icon(Icons.do_not_disturb_on, color: Color(0xFF6A1B9A), size: 26),
              ),
            ),

          if (_currentIndex != 3)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: const Color(0xFF1A237E)),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _updatePages();
                  }
                });
              },
            ),
        ],
      ),

      body: IndexedStack(index: _currentIndex, children: _pages),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleFabAction(context, user),
        backgroundColor: const Color(0xFF6A1B9A),
        shape: const CircleBorder(),
        child: Icon(
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

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomIcon(Icons.forum, 0, user),
              _buildBottomIcon(Icons.event, 1, user),
              const SizedBox(width: 40),
              _buildBottomIcon(Icons.calendar_month, 2, user),
              _buildBottomIcon(Icons.person, 3, user),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER METHODS PRESERVED ---
  Widget _buildBottomIcon(IconData icon, int index, dynamic user) {
    return IconButton(
      icon: Icon(icon, color: _currentIndex == index ? const Color(0xFF6A1B9A) : Colors.grey),
      onPressed: () {
        if (index == 3 && user == null) {
          _showLoginPrompt(context);
        } else {
          setState(() {
            _currentIndex = index;
            _isSearching = false;
            _searchController.clear();
            _updatePages();
          });
        }
      },
    );
  }

  void _handleFabAction(BuildContext context, dynamic user) {
    if (user == null) {
      _showLoginPrompt(context);
      return;
    }
    switch (_currentIndex) {
      case 0:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostScreen()));
        break;
      case 1:
        if (user.role == 'society') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateEventScreen()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
        }
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (context) => CreateScheduleScreen(initialDate: _selectedScheduleDate)));
        break;
      case 3:
        setState(() => _currentIndex = 0);
        break;
    }
  }

  // --- DRAWER & DIALOGS PRESERVED ---
  Widget _buildDrawer(BuildContext context, user) {
    final bool isLoggedIn = user != null;
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 20, bottom: 20, right: 20),
            decoration: const BoxDecoration(color: Color(0xFF6A1B9A)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: (isLoggedIn && user.avatarUrl != null)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (isLoggedIn && user.avatarUrl != null)
                      ? null
                      : const Icon(Icons.person, color: Color(0xFF6A1B9A), size: 40),
                ),
                const SizedBox(height: 15),
                Text(
                  isLoggedIn ? user.fullName : 'guest_student'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if (isLoggedIn) Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF6A1B9A)),
            title: Text('scan_qr_nfc'.tr()),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQRNFCScreen()));
            },
          ),
          if (isLoggedIn) ...[
            ListTile(
              leading: Icon(user.role == 'society' ? Icons.event_note : Icons.local_activity, color: const Color(0xFF6A1B9A)),
              title: Text(user.role == 'society' ? 'manage_events'.tr() : 'manage_tickets'.tr()),
              onTap: () {
                Navigator.pop(context);
                if (user.role == 'society') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageEventsScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
                }
              },
            ),
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
                            top: -6, right: -8,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            ),
                          ),
                      ],
                    ),
                    title: Text('payment_approval'.tr()),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentApprovalDashboard()));
                    },
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.bookmark_border, color: Color(0xFF6A1B9A)),
              title: Text('saved_posts'.tr()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPostsScreen()));
              },
            ),
          ],
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('language'.tr()),
            onTap: () {
              Navigator.pop(context);
              _showLanguageDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('about_unipath'.tr()),
            onTap: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse('https://www.tarc.edu.my/');
              if (!await launchUrl(url)) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(isLoggedIn ? Icons.logout : Icons.login, color: isLoggedIn ? Colors.red : const Color(0xFF6A1B9A)),
            title: Text(isLoggedIn ? 'logout'.tr() : 'login'.tr(),
                style: TextStyle(color: isLoggedIn ? Colors.red : const Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              if (isLoggedIn) {
                _handleLogout(context);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)));
              }
            },
          ),
        ],
      ),
    );
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Login Required"),
        content: const Text("Please log in to proceed with this action."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)));
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService().signOut();
      Provider.of<UserProvider>(context, listen: false).logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)),
            (route) => false,
      );
    }
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('language'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(context, 'English', 'en'),
              _buildLanguageOption(context, 'Bahasa Melayu', 'ms'),
              _buildLanguageOption(context, '简体中文', 'zh'),
              _buildLanguageOption(context, '日本語', 'ja'),
            ],
          ),
          actions: [
            TextButton(child: Text('cancel'.tr()), onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, String title, String locale) {
    return RadioListTile<String>(
      title: Text(title),
      value: locale,
      groupValue: context.locale.languageCode,
      activeColor: const Color(0xFF6A1B9A),
      onChanged: (String? value) {
        if (value != null) {
          context.setLocale(Locale(value));
          Navigator.of(context).pop();
        }
      },
    );
  }
}