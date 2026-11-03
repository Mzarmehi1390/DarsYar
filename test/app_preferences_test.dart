import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dars_yar/app/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppPreferences', () {
    test('uses system theme and enabled animations as safe defaults', () async {
      final preferences = AppPreferences();

      expect(await preferences.loadThemeMode(), ThemeMode.system);
      expect(await preferences.loadAnimationsEnabled(), isTrue);
    });

    test('persists and restores every theme mode', () async {
      final preferences = AppPreferences();

      for (final mode in ThemeMode.values) {
        await preferences.saveThemeMode(mode);
        expect(await preferences.loadThemeMode(), mode);
      }
    });

    test('falls back to system for an unknown stored theme value', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferences.themeModeKey: 'unexpected',
      });

      expect(
        await AppPreferences().loadThemeMode(),
        ThemeMode.system,
      );
    });

    test('persists the reduced-motion preference', () async {
      final preferences = AppPreferences();

      await preferences.saveAnimationsEnabled(false);
      expect(await preferences.loadAnimationsEnabled(), isFalse);

      await preferences.saveAnimationsEnabled(true);
      expect(await preferences.loadAnimationsEnabled(), isTrue);
    });
  });
}
