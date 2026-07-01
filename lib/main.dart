import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:camera/camera.dart' as cam;

import 'ui/screens/splash/splash_screen.dart';
import 'models/project.dart';
import 'providers/theme_provider.dart';
import 'ui/theme/app_theme.dart';

late List<cam.CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await cam.availableCameras();
  } catch (e) {
    cameras = [];
    //print("Camera initialization failed: $e");
  }

  // Initialize Local Database
  await Hive.initFlutter();
  Hive.registerAdapter(ProjectAdapter());

  // Open Database Boxes
  await Hive.openBox<Project>('projectsBox');
  await Hive.openBox(
    'settingsBox',
  ); // NEW: Opens a box to permanently save settings

  runApp(const ProviderScope(child: SolarAlignApp()));
}

class SolarAlignApp extends ConsumerWidget {
  const SolarAlignApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current theme mode (Light or Dark)
    final currentThemeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Solar Align Pro',
      debugShowCheckedModeBanner: false,
      // Apply your premium custom themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Bind the active mode to the provider
      themeMode: currentThemeMode,
      home: const SplashScreen(),
    );
  }
}
