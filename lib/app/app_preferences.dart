import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns persistence for application-wide user preferences.
///
/// Keeping preference keys and serialization in one place prevents widgets
/// from becoming coupled to SharedPreferences and makes settings testable.
class AppPreferences {
  AppPreferences({this._preferences});

  static const themeModeKey = 'darsyar.themeMode';
  static const animationsEnabledKey = 'darsyar.animationsEnabled';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<ThemeMode> loadThemeMode() async {
    final stored = (await _store).getString(themeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final stored = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await (await _store).setString(themeModeKey, stored);
  }

  Future<bool> loadAnimationsEnabled() async =>
      (await _store).getBool(animationsEnabledKey) ?? true;

  Future<void> saveAnimationsEnabled(bool enabled) async {
    await (await _store).setBool(animationsEnabledKey, enabled);
  }
}
