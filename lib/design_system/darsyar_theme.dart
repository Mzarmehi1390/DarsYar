import 'package:flutter/material.dart';

/// Shared visual foundations for every DarsYar screen.
///
/// Keep product colors, geometry and component defaults here so the UI can
/// evolve without scattering one-off values across screen implementations.
abstract final class DarsYarTokens {
  static const accent = Color(0xFF16A36A);
  static const accentLight = Color(0xFF75D9A5);
  static const secondary = Color(0xFF4B849C);

  static const lightBackground = Color(0xFFEAF2EE);
  static const lightCanvas = Color(0xFFF3F8F5);
  static const lightSurface = Color(0xFFF9FCFA);
  static const lightSurfaceRaised = Color(0xFFE5F0E9);
  static const lightOutline = Color(0xFFC8D9CF);
  static const lightText = Color(0xFF14231D);
  static const lightMuted = Color(0xFF71847A);

  static const darkBackground = Color(0xFF08130F);
  static const darkCanvas = Color(0xFF0D1A14);
  static const darkSurface = Color(0xFF14251D);
  static const darkSurfaceRaised = Color(0xFF20372B);
  static const darkOutline = Color(0xFF3B5748);
  static const darkText = Color(0xFFEAF5EE);
  static const darkMuted = Color(0xFFA5B9AD);

  static const radiusSmall = 12.0;
  static const radiusMedium = 18.0;
  static const radiusLarge = 22.0;
  static const radiusExtraLarge = 28.0;

  static const pageHorizontalPadding = 20.0;
  static const pageBottomClearance = 124.0;
  static const glassBlur = 8.0;
}

abstract final class DarsYarTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: DarsYarTokens.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: DarsYarTokens.accent,
      onPrimary: Colors.white,
      secondary: DarsYarTokens.secondary,
      surface: DarsYarTokens.lightSurface,
      onSurface: DarsYarTokens.lightText,
      surfaceContainerHighest: DarsYarTokens.lightSurfaceRaised,
      outline: DarsYarTokens.lightOutline,
      outlineVariant: DarsYarTokens.lightOutline.withValues(alpha: 0.72),
    );

    return _buildTheme(
      scheme: scheme,
      brightness: Brightness.light,
      background: DarsYarTokens.lightBackground,
      inputFill: const Color(0xFFE7F0EA),
      cardFill: const Color(0xF7FFFFFF),
      cardBorder: const Color(0xDFFFFFFF),
      mutedText: DarsYarTokens.lightMuted,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: DarsYarTokens.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: DarsYarTokens.accentLight,
      onPrimary: const Color(0xFF092016),
      secondary: const Color(0xFF8DBBD0),
      surface: DarsYarTokens.darkSurface,
      onSurface: DarsYarTokens.darkText,
      surfaceContainerHighest: DarsYarTokens.darkSurfaceRaised,
      outline: DarsYarTokens.darkOutline,
      outlineVariant: DarsYarTokens.darkOutline.withValues(alpha: 0.78),
    );

    return _buildTheme(
      scheme: scheme,
      brightness: Brightness.dark,
      background: DarsYarTokens.darkBackground,
      inputFill: const Color(0xFF1B3025),
      cardFill: const Color(0xE61A2B23),
      cardBorder: const Color(0x35B5F5D2),
      mutedText: DarsYarTokens.darkMuted,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Brightness brightness,
    required Color background,
    required Color inputFill,
    required Color cardFill,
    required Color cardBorder,
    required Color mutedText,
  }) {
    final isDark = brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DarsYarTokens.radiusLarge),
      side: BorderSide(color: cardBorder, width: 1.1),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DarsYarTokens.radiusMedium),
      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardFill,
        shape: shape,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill.withValues(alpha: isDark ? 0.58 : 0.62),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        labelStyle: TextStyle(color: mutedText),
        hintStyle: TextStyle(color: mutedText.withValues(alpha: 0.82)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DarsYarTokens.radiusMedium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DarsYarTokens.radiusMedium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w650),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DarsYarTokens.radiusSmall),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF263B30)
            : const Color(0xFF203B2E),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DarsYarTokens.radiusMedium),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
