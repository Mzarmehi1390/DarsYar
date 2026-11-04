import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_preferences.dart';
import '../design_system/darsyar_theme.dart';
import 'darsyar_home.dart';

class DarsYarApp extends StatefulWidget {
  const DarsYarApp({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<DarsYarApp> createState() => _DarsYarAppState();
}

class _DarsYarAppState extends State<DarsYarApp> {
  final AppPreferences _preferences = AppPreferences();
  ThemeMode mode = ThemeMode.system;
  bool animationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadAnimationPreference();
  }

  Future<void> _loadAnimationPreference() async {
    try {
      final restored = await _preferences.loadAnimationsEnabled();
      if (mounted) setState(() => animationsEnabled = restored);
    } catch (_) {
      // Keep animations enabled when preferences cannot be read.
    }
  }

  Future<void> _setAnimationsEnabled(bool value) async {
    setState(() => animationsEnabled = value);
    try {
      await _preferences.saveAnimationsEnabled(value);
    } catch (_) {
      // The current session still uses the selected performance mode.
    }
  }

  Future<void> _loadThemeMode() async {
    try {
      final restored = await _preferences.loadThemeMode();
      if (mounted) setState(() => mode = restored);
    } catch (_) {
      // Theme preferences are optional; keep the system default if unavailable.
    }
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    setState(() => mode = value);
    try {
      await _preferences.saveThemeMode(value);
    } catch (_) {
      // The selected theme remains active for this run even if persistence fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassWidgets.wrap(
      theme: const GlassThemeData.ios27(),
      brightnessResolver: Theme.maybeBrightnessOf,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'درس‌یار',
        themeMode: mode,
        theme: DarsYarTheme.light,
        darkTheme: DarsYarTheme.dark,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: media.disableAnimations || !animationsEnabled,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox.expand(child: child ?? const SizedBox()),
            ),
          );
        },
        home: DarsYarHome(
          initialTab: widget.initialTab,
          mode: mode,
          onModeChanged: _setThemeMode,
          animationsEnabled: animationsEnabled,
          onAnimationsChanged: _setAnimationsEnabled,
        ),
      ),
    );
  }
}
