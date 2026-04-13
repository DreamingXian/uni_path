import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_path/providers/user_provider.dart';
import 'package:uni_path/screens/home.dart';

// new line added by shouxian

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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if a session already exists in Supabase
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniPath',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.purple,
      ),
      // If session exists, we should technically fetch user data,
      // but for now, let's keep the HomePage as your dev hub.
      home: const HomePage(),
    );
  }
}
