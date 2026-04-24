import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uni_path/providers/user_provider.dart';
import 'package:uni_path/screens/home.dart';
import 'package:uni_path/screens/Events/event_details.dart';
import 'package:uni_path/services/event_service.dart';
import 'package:uni_path/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:uni_path/services/notification_service.dart';
import 'package:uni_path/services/schedule_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// new line added by shouxian
//xindongxi
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the bundled .env asset
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await EasyLocalization.ensureInitialized();

  // --- MODULE 4 INITIALIZATION ---
  // Initialize notifications (Timezones, Channels, and Permissions)
  final notificationService = NotificationService();
  await notificationService.init();

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
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    // Check local preferences to see if they specifically un-checked "Remember Me"
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? true; // default to true if never explicitly set

    if (!rememberMe) {
      // They didn't want to be remembered across app boots. Wipe the cached Supabase token.
      await Supabase.instance.client.auth.signOut();
    } else {
      // 1. Check for immediate session on boot
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        _loadUser(session.user.id);

        // --- MODULE 4: BACKGROUND SYNC ---
        // Sync local SQLite database with fresh data on app boot
        ScheduleService().getMySchedules();
      }
    }

    // 2. Listen globally for token refreshes or logouts
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
    
    // Handle initial routing if app launched cold from a link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingURI(uri);
    });

    // Handle deep links when app is already in the background/foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingURI(uri);
    });
  }

  Future<void> _handleIncomingURI(Uri uri) async {
    // Expected link: https://unipath.com/event/<eventId>
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'event') {
      if (uri.pathSegments.length > 1) {
        final eventIdStr = uri.pathSegments[1];
        final eventId = int.tryParse(eventIdStr);
        if (eventId != null) {
          try {
            final eventService = EventService();
            final matchedEvent = await eventService.getEventById(eventId);
            if (matchedEvent != null && globalNavigatorKey.currentState != null) {
              globalNavigatorKey.currentState!.push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: matchedEvent),
                ),
              );
            }
          } catch (e) {
            debugPrint("Failed to route to event from deep link: $e");
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
        primarySwatch: Colors.purple,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF5F7F9),
      ),
      home: const HomePage(),
    );
  }
}
