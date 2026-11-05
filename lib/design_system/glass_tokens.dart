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
  static const Color dialogBarrierColor = Color(0x8F000000); // 56% backdrop tint
  static const Color sheetBarrierColor = Color(0x8F000000); // 56% backdrop tint
  static const double sheetFillThreshold = 1.0;
  static const GlassFillTransition sheetFillTransition =
      GlassFillTransition.gradual;
  static const bool maintainSheetContentGlass = true;
  // Keep the glass refraction, but skip the whole-sheet saturation pulse on taps.
  static const bool enableSheetSaturationGlow = false;
  // Leave room between the medium stop and the full-height glass detent.
  static const double defaultHalfSheetSize = 0.78;
}
