import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/firebase_options.dart';
import 'package:jva_projecttracker/screens/shared/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: JvaProjectTrackerApp()));
}

class JvaProjectTrackerApp extends StatelessWidget {
  const JvaProjectTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JVA Project Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
