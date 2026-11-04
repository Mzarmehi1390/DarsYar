import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'glass_tokens.dart';
import 'modal_content.dart';

/// Shared presentation defaults for DarsYar modal sheets.
///
/// Both medium and large detents stay refractive. The explicit full-state
/// material overrides the package's default opaque fill at the large detent.
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
  Color barrierColor = DarsYarGlassTokens.sheetBarrierColor,
}) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  // GlassModalSheet.show pushes a RawDialogRoute and, unlike showDialog,
  // does not capture inherited themes. Preserve the presenting Navigator's
  // theme so dark/light Cupertino and Material styling survives the route.
  final capturedThemes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context).context,
  );

  // The upstream sheet normally fades its large detent to a solid fill.
  // Supplying an explicit, non-zero-blur fullSettings keeps the actual full
  // detent refractive: the package's renderer then holds colorOpacity at zero
  // while preserving the full-screen geometry and the iOS 27 glass material.
  final isDark = GlassTheme.brightnessOf(context) == Brightness.dark;
  final themedGlassBase = isDark
      ? LiquidGlassSettings.ios27Dark
      : LiquidGlassSettings.ios27Light;
  final themedSettings = GlassThemeData.of(context).settingsFor(context);
  final resolvedFullSettings = fullSettings ??
      settings ??
      themedSettings?.applyTo(themedGlassBase) ??
      themedGlassBase;

  return GlassModalSheet.show<T>(
    context: context,
    // Every sheet gets the same RTL, typography and Cupertino contrast contract.
    // Call sites may still wrap specialized content without changing behaviour.
    builder: (sheetContext) => capturedThemes.wrap(
      DarsYarModalContent(child: builder(sheetContext)),
    ),
    initialState: initialState,
    // Offer both the content-height glass stop and the full-height glass stop.
    detents: const {GlassSheetDetent.medium, GlassSheetDetent.large},
    halfSize: halfSize,
    fullSize: fullSize,
    fullSettings: resolvedFullSettings,
    quality: quality,
    fillThreshold: fillThreshold,
    fillTransition: fillTransition,
    maintainContentGlass: maintainContentGlass,
    // Keep touch refraction in normal mode; remove the moving glare in lite mode.
    enableInteractionGlow: !reduceMotion,
    // Avoid repainting/pulsing the entire large form on every child tap.
    enableSaturationGlow: DarsYarGlassTokens.enableSheetSaturationGlow,
    // Complex forms should not make the entire sheet wobble on every tap.
    suppressInteractionOnChildren: true,
    // Respect the app's Reduce Motion setting for sheets as well as dialogs
    // and page transitions; do not compensate by making motion faster.
    sheetAnimationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 240),
            reverseDuration: Duration(milliseconds: 200),
          ),
    padding: padding,
    barrierColor: barrierColor,
  );
}
