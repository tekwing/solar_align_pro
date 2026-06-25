import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Controls the active theme of the app (Persisted permanently)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = Hive.box('settingsBox');

    // Automatically save to Hive whenever the user toggles the UI
    listenSelf((previous, next) {
      box.put('isDarkMode', next == ThemeMode.dark);
    });

    // Load the initial value from Hive when the app opens
    final isDark = box.get('isDarkMode', defaultValue: false);
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
