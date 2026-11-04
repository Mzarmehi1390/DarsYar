import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'glass_tokens.dart';
import 'modal_content.dart';

/// Shared presentation defaults for DarsYar modal sheets.
///
/// The package intentionally renders its large detent as opaque. DarsYar uses
/// a tall medium detent instead, preserving the refractive glass surface.
Future<T?> showDarsYarGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlassSheetState initialState = GlassSheetState.half,
  double halfSize = DarsYarGlassTokens.defaultHalfSheetSize,
  double? fullSize,
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
  return GlassModalSheet.show<T>(
    context: context,
    // Every sheet gets the same RTL, typography and Cupertino contrast contract.
    // Call sites may still wrap specialized content without changing behaviour.
    builder: (sheetContext) => capturedThemes.wrap(
      DarsYarModalContent(child: builder(sheetContext)),
    ),
    // GlassSheetDetent.large is intentionally opaque in liquid_glass_widgets.
    // Use a tall medium detent instead so editors remain refractive at rest.
    initialState: initialState == GlassSheetState.full
        ? GlassSheetState.half
        : initialState,
    detents: const {GlassSheetDetent.medium},
    // DarsYar intentionally offers one tall, refractive medium detent.
    // fullSize belongs to the package's separate large detent; forwarding the
    // same value for both creates a zero-length half-to-full geometry range.
    halfSize: fullSize ?? halfSize,
    fullSize: null,
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
