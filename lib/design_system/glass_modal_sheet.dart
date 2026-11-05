import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'glass_tokens.dart';
import 'modal_content.dart';

/// Shared presentation defaults for DarsYar modal sheets.
///
/// The presenter MediaQuery is captured before the package pushes its
/// RawDialogRoute. Some Android edge-to-edge routes report zero bottom
/// viewPadding after the route is installed, even though system navigation
/// still occupies the bottom of the screen.
Future<T?> showDarsYarGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlassSheetState initialState = GlassSheetState.half,
  double halfSize = DarsYarGlassTokens.defaultHalfSheetSize,
  double? fullSize,
  LiquidGlassSettings? fullSettings,
  GlassQuality? quality = DarsYarGlassTokens.quality,
  double fillThreshold = DarsYarGlassTokens.sheetFillThreshold,
  GlassFillTransition fillTransition = DarsYarGlassTokens.sheetFillTransition,
  bool maintainContentGlass = DarsYarGlassTokens.maintainSheetContentGlass,
  EdgeInsetsGeometry? padding,
  Color? barrierColor,
}) {
  final media = MediaQuery.of(context);
  final reduceMotion = media.disableAnimations;
  final bottomSystemInset = [
    media.viewPadding.bottom,
    media.systemGestureInsets.bottom,
    media.padding.bottom,
  ].reduce((a, b) => a > b ? a : b);

  // GlassModalSheet.show pushes a RawDialogRoute and does not capture
  // inherited themes. Preserve the presenting Navigator's theme.
  final capturedThemes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context).context,
  );

  final isDark = GlassTheme.brightnessOf(context) == Brightness.dark;
  final themedGlassBase = isDark
      ? LiquidGlassSettings.ios27Dark
      : LiquidGlassSettings.ios27Light;
  final themedSettings = GlassThemeData.of(context).settingsFor(context);
  final resolvedFullSettings =
      fullSettings ?? themedSettings?.applyTo(themedGlassBase) ?? themedGlassBase;
  final resolvedBarrierColor = barrierColor ??
      Colors.black.withValues(alpha: isDark ? 0.72 : 0.56);

  return GlassModalSheet.show<T>(
    context: context,
    builder: (sheetContext) => capturedThemes.wrap(
      // Use metrics captured from the presenting page, not the new route:
      // Android gesture navigation can otherwise be lost at this boundary.
      DarsYarModalSheetContent(
        bottomInset: bottomSystemInset,
        // GlassModalSheet intentionally sinks its full-state frame below the
        // screen by its base bottom radius. Keep the content footer above that
        // submerged edge as well as above Android's navigation area.
        bottomRadiusCompensation:
            defaultTargetPlatform == TargetPlatform.android ? 28 : 0,
        child: builder(sheetContext),
      ),
    ),
    initialState: initialState,
    bottomBorderRadius:
        defaultTargetPlatform == TargetPlatform.android ? 28 : null,
    fullBottomBorderRadius:
        defaultTargetPlatform == TargetPlatform.android ? 0 : null,
    detents: const {GlassSheetDetent.medium, GlassSheetDetent.large},
    halfSize: halfSize,
    fullSize: fullSize,
    fullSettings: resolvedFullSettings,
    quality: quality,
    fillThreshold: fillThreshold,
    fillTransition: fillTransition,
    maintainContentGlass: maintainContentGlass,
    enableInteractionGlow: !reduceMotion,
    enableSaturationGlow: DarsYarGlassTokens.enableSheetSaturationGlow,
    suppressInteractionOnChildren: true,
    sheetAnimationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 240),
            reverseDuration: Duration(milliseconds: 200),
          ),
    padding: padding,
    barrierColor: resolvedBarrierColor,
  );
}
