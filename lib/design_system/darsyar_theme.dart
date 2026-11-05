import 'package:flutter/material.dart';

/// Shared visual foundations for every DarsYar screen.
///
/// Keep product colors, geometry and component defaults here so the UI can
/// evolve without scattering one-off values across screen implementations.
abstract final class DarsYarTokens {
  static const accent = Color(0xFF16A36A);
  static const accentLight = Color(0xFF75D9A5);
  static const secondary = Color(0xFF5B83B6);

  static const lightBackground = Color(0xFFE5EDF6);
  static const lightCanvas = Color(0xFFEDF3F9);
  static const lightSurface = Color(0xFFF0F5FA);
  static const lightSurfaceRaised = Color(0xFFDCE7F1);
  static const lightOutline = Color(0xFFB8CADA);
  static const lightText = Color(0xFF172536);
  static const lightMuted = Color(0xFF5D7186);

  static const darkBackground = Color(0xFF0B1422);
  static const darkCanvas = Color(0xFF101D2D);
  static const darkSurface = Color(0xFF192A3D);
  static const darkSurfaceRaised = Color(0xFF263D54);
  static const darkOutline = Color(0xFF405A72);
  static const darkText = Color(0xFFEAF3FC);
  static const darkMuted = Color(0xFFA8B9CC);

  static const radiusSmall = 12.0;
  static const radiusMedium = 18.0;
  static const radiusLarge = 22.0;
  static const radiusExtraLarge = 28.0;

  static const pageHorizontalPadding = 20.0;
  static const pageBottomClearance = 152.0;
  static const glassBlur = 15.0;
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
      inputFill: const Color(0xFFE5EEF8),
      cardFill: const Color(0xC8FFFFFF),
      cardBorder: const Color(0xD9FFFFFF),
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
      secondary: const Color(0xFF9BC4E8),
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
      inputFill: const Color(0xFF22364B),
      cardFill: const Color(0xE61A2B40),
      cardBorder: const Color(0x3AAED8FF),
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
      // GlassDialog and GlassModalSheet draw their own shader-backed
      // surfaces. An opaque Material dialog underneath them masks refraction
      // and turns the overlay into a flat white/solid panel.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 20,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.34 : 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DarsYarTokens.radiusExtraLarge),
          side: BorderSide(color: cardBorder.withValues(alpha: 0.9)),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.55,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface.withValues(alpha: isDark ? 0.98 : 0.97),
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DarsYarTokens.radiusMedium),
          side: BorderSide(color: cardBorder.withValues(alpha: 0.9)),
        ),
        textStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        // The liquid-glass sheet owns its material. Keep Flutter's fallback
        // Material transparent so it cannot paint an opaque layer over glass.
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DarsYarTokens.radiusExtraLarge),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DarsYarTokens.radiusMedium),
        ),
        hourMinuteColor: scheme.surfaceContainerHighest,
        hourMinuteTextColor: scheme.onSurface,
        dialBackgroundColor: scheme.surfaceContainerHighest,
        dialHandColor: scheme.primary,
        dialTextColor: scheme.onSurface,
        entryModeIconColor: scheme.primary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: isDark
            ? DarsYarTokens.darkSurfaceRaised
            : DarsYarTokens.lightSurfaceRaised,
        headerForegroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DarsYarTokens.radiusExtraLarge),
          side: BorderSide(color: cardBorder.withValues(alpha: 0.9)),
        ),
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
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
