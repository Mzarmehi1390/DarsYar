import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Shared material and motion policy for every Liquid Glass entry point.
///
/// Glass is reserved for floating controls, navigation and transient overlays.
/// Dense study content uses [DarsYarContentSurface] instead, keeping text
/// readable and preventing every nested card from competing for attention.
abstract final class DarsYarGlassTokens {
  static const GlassQuality quality = GlassQuality.standard;
  static const Duration modalTransitionDuration = Duration(milliseconds: 220);
  static const Color dialogBarrierColor = Color(0x4D000000);
  static const double sheetFillThreshold = 1.0;
  static const GlassFillTransition sheetFillTransition =
      GlassFillTransition.gradual;
  static const bool maintainSheetContentGlass = true;
  // A tall medium detent stays refractive; the package's large detent is opaque.
  static const double defaultHalfSheetSize = 0.92;

}
