import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Presents a DarsYar modal sheet without letting the large detent flatten
/// the refractive surface into an opaque panel.
Future<T?> showDarsYarGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlassSheetState initialState = GlassSheetState.full,
  double halfSize = 0.45,
  double fullSize = 0.90,
  EdgeInsetsGeometry? padding,
  Color barrierColor = Colors.transparent,
}) {
  return GlassModalSheet.show<T>(
    context: context,
    builder: builder,
    initialState: initialState,
    halfSize: halfSize,
    fullSize: fullSize,
    quality: GlassQuality.standard,
    fillThreshold: 1.0,
    fillTransition: GlassFillTransition.gradual,
    maintainContentGlass: true,
    padding: padding,
    barrierColor: barrierColor,
  );
}
