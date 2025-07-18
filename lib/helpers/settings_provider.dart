import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Settings {
  final bool darkMode;
  final bool accessibilityMode;
  final bool backupEnabled;
  // Add more settings as needed

  Settings({
    required this.darkMode,
    required this.accessibilityMode,
    required this.backupEnabled,
  });

  Settings copyWith({
    bool? darkMode,
    bool? accessibilityMode,
    bool? backupEnabled,
  }) {
    return Settings(
      darkMode: darkMode ?? this.darkMode,
      accessibilityMode: accessibilityMode ?? this.accessibilityMode,
      backupEnabled: backupEnabled ?? this.backupEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'darkMode': darkMode,
    'accessibilityMode': accessibilityMode,
    'backupEnabled': backupEnabled,
  };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    darkMode: json['darkMode'] ?? false,
    accessibilityMode: json['accessibilityMode'] ?? false,
    backupEnabled: json['backupEnabled'] ?? false,
  );

  static Settings defaults() =>
      Settings(darkMode: false, accessibilityMode: false, backupEnabled: false);
}

class SettingsNotifier extends StateNotifier<Settings> {
  static const _prefsKey = 'app_settings';
  SettingsNotifier() : super(Settings.defaults()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      state = Settings.fromJson(json.decode(jsonString));
    }
  }

  Future<void> update(Settings newSettings) async {
    state = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(state.toJson()));
  }

  Future<void> reset() async {
    state = Settings.defaults();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(state.toJson()));
  }

  // Convenience methods
  Future<void> setDarkMode(bool value) async =>
      update(state.copyWith(darkMode: value));
  Future<void> setAccessibilityMode(bool value) async =>
      update(state.copyWith(accessibilityMode: value));
  Future<void> setBackupEnabled(bool value) async =>
      update(state.copyWith(backupEnabled: value));
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>(
  (ref) => SettingsNotifier(),
);
