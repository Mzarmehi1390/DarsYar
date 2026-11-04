import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Shared presentation defaults for DarsYar modal sheets.
///
/// The large detent must remain refractive. The package defaults to an opaque
/// full sheet, so DarsYar uses a gradual fill threshold at the end of expansion.
Future<T?> showDarsYarGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlassSheetState initialState = GlassSheetState.full,
  double halfSize = 0.45,
  double? fullSize,
  GlassQuality? quality = GlassQuality.standard,
  double fillThreshold = 1.0,
  GlassFillTransition fillTransition = GlassFillTransition.gradual,
  bool maintainContentGlass = true,
  EdgeInsetsGeometry? padding,
  Color barrierColor = Colors.transparent,
}) {
  return GlassModalSheet.show<T>(
    context: context,
    builder: builder,
    initialState: initialState,
    halfSize: halfSize,
    fullSize: fullSize,
    quality: quality,
    fillThreshold: fillThreshold,
    fillTransition: fillTransition,
    maintainContentGlass: maintainContentGlass,
    padding: padding,
    barrierColor: barrierColor,
  );
}
