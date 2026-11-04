import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'glass_tokens.dart';

/// Shared presentation defaults for DarsYar modal sheets.
///
/// The large detent must remain refractive. The package defaults to an opaque
/// full sheet, so DarsYar uses a gradual fill threshold at the end of expansion.
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
  Color barrierColor = Colors.transparent,
}) {
  return GlassModalSheet.show<T>(
    context: context,
    builder: builder,
    // GlassSheetDetent.large is intentionally opaque in liquid_glass_widgets.
    // Use a tall medium detent instead so editors remain refractive at rest.
    initialState: initialState == GlassSheetState.full
        ? GlassSheetState.half
        : initialState,
    detents: const {GlassSheetDetent.medium},
    halfSize: fullSize ?? halfSize,
    fullSize: fullSize,
    quality: quality,
    fillThreshold: fillThreshold,
    fillTransition: fillTransition,
    maintainContentGlass: maintainContentGlass,
    padding: padding,
    barrierColor: barrierColor,
  );
}
