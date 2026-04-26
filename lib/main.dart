import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Internal Project Imports (Adjusted for your root folder structure)
import 'providers/user_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home.dart';
import 'screens/Events/event_details.dart';
import 'services/event_service.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'services/schedule_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    await EasyLocalization.ensureInitialized();

    // Notification Init (Soft catch to prevent "Asia/Kuala Lumpur" hang)
    try {
      final notificationService = NotificationService();
      await notificationService.init();
    } catch (e) {
      debugPrint("Warning: Notifications failed to init: $e");
    }

    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('ms'),
          Locale('zh'),
          Locale('ja'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: const MainApp(),
        ),
      ),
    );
  } catch (e) {
    debugPrint("CRITICAL ERROR DURING BOOT: $e");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Startup Error: $e", textAlign: TextAlign.center)),
      ),
    ));
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitializing = true; // Prevents the app from showing Home prematurely

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? true;

    if (!rememberMe) {
      await Supabase.instance.client.auth.signOut();
    } else {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await _loadUser(session.user.id);
        // Background sync for offline DB
        ScheduleService().getMySchedules();
      }
    }

    // Listen for Auth changes (Login/Logout)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _loadUser(session.user.id);
      } else {
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).logout();
        }
      }
    });

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _loadUser(String userId) async {
    final userService = UserService();
    final user = await userService.getUserById(userId);
    if (user != null && mounted) {
      Provider.of<UserProvider>(context, listen: false).setUser(user);
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingURI(uri);
    });
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingURI(uri);
    });
  }

  Future<void> _handleIncomingURI(Uri uri) async {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'event') {
      if (uri.pathSegments.length > 1) {
        final eventId = int.tryParse(uri.pathSegments[1]);
        if (eventId != null) {
          try {
            final matchedEvent = await EventService().getEventById(eventId);
            if (matchedEvent != null && globalNavigatorKey.currentState != null) {
              globalNavigatorKey.currentState!.push(
                MaterialPageRoute(builder: (_) => EventDetailScreen(event: matchedEvent)),
              );
            }
          } catch (e) {
            debugPrint("Deep link error: $e");
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorKey: globalNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'UniPath',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A)),
      ),
      home: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          // Show spinner while checking the session
          if (_isInitializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
            );
          }

          // If no user is logged in, show Auth Screen
          if (userProvider.currentUser == null) {
            return const AuthScreen(showLogin: true);
          }

          // If logged in, show Home Page
          return const HomePage();
        },
      ),
    );
  }
}