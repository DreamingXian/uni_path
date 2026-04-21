import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:uni_path/providers/user_provider.dart';
import 'package:uni_path/screens/home.dart';
import 'package:uni_path/screens/Events/event_details.dart';
import 'package:uni_path/services/event_service.dart';
import 'dart:async';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// new line added by shouxian
//xindongxi
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the bundled .env asset
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MainApp(),
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
      navigatorKey: globalNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'UniPath',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.purple,
      ),
      home: const HomePage(),
    );
  }
}
