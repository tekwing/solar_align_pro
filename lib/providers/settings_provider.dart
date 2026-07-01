import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum MeasurementUnit { metric, imperial }

// --- APP PREFERENCES (PERMANENTLY PERSISTED) ---

class KeepScreenActiveNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box('settingsBox');
    listenSelf((previous, next) => box.put('keepScreenActive', next));
    return box.get('keepScreenActive', defaultValue: false);
  }

  // NEW: Public setter
  void set(bool value) => state = value;
}

final keepScreenActiveProvider =
    NotifierProvider<KeepScreenActiveNotifier, bool>(
      KeepScreenActiveNotifier.new,
    );

class SoundEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box('settingsBox');
    listenSelf((previous, next) => box.put('soundEnabled', next));
    return box.get('soundEnabled', defaultValue: true);
  }

  // NEW: Public setter
  void set(bool value) => state = value;
}

final soundEnabledProvider = NotifierProvider<SoundEnabledNotifier, bool>(
  SoundEnabledNotifier.new,
);

class VibrationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box('settingsBox');
    listenSelf((previous, next) => box.put('vibrationEnabled', next));
    return box.get('vibrationEnabled', defaultValue: true);
  }

  // NEW: Public setter
  void set(bool value) => state = value;
}

final vibrationEnabledProvider =
    NotifierProvider<VibrationEnabledNotifier, bool>(
      VibrationEnabledNotifier.new,
    );

// --- LOCALIZATION & UNITS (PERMANENTLY PERSISTED) ---

class UnitNotifier extends Notifier<MeasurementUnit> {
  @override
  MeasurementUnit build() {
    final box = Hive.box('settingsBox');
    listenSelf(
      (previous, next) => box.put('isMetric', next == MeasurementUnit.metric),
    );
    final isMetric = box.get('isMetric', defaultValue: true);
    return isMetric ? MeasurementUnit.metric : MeasurementUnit.imperial;
  }

  // NEW: Public setter
  void set(MeasurementUnit value) => state = value;
}

final unitProvider = NotifierProvider<UnitNotifier, MeasurementUnit>(
  UnitNotifier.new,
);

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    final box = Hive.box('settingsBox');
    listenSelf((previous, next) => box.put('currency', next));
    return box.get('currency', defaultValue: '\$');
  }

  // NEW: Public setter
  void set(String value) => state = value;
}

final currencyProvider = NotifierProvider<CurrencyNotifier, String>(
  CurrencyNotifier.new,
);

// --- OVERRIDES (TEMPORARY: Resets when app closes) ---

// Global Manual Location Override
// By NOT connecting these to Hive, they automatically reset to null when the app opens!
// Note: StateProviders natively allow .state modifications, so they don't need custom setters.
final manualLatProvider = StateProvider<double?>((ref) => null);
final manualLonProvider = StateProvider<double?>((ref) => null);
