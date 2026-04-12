import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_path/providers/user_provider.dart';
import 'package:uni_path/screens/home.dart';

// test 2
// test 3
// test 4
// test 5
// test 66
// test 7
// test 8
// jason enter something

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vyqztsexupsgcljbzaqx.supabase.co',
    anonKey: 'sb_secret_pdR-TPPGCbXbSzbspitDCg_PULxY-LG',
  );

  runApp(
    MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
    ],
    child: const MainApp(),
  ),);
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
    );
  }
}


