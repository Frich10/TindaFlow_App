
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme.dart';
import 'data/firebase_sync.dart';
import 'data/store.dart';
import 'screens/auth_screens.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseSync.initPersistence();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  await store.load();

  runApp(const TindaFlowApp());
}

class TindaFlowApp extends StatelessWidget {
  const TindaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TindaFlow',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}
