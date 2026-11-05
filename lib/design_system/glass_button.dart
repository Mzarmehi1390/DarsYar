import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// The single DarsYar entry point for primary, secondary and compact glass
/// actions. Keeps geometry, quality and interaction semantics consistent.
class DarsYarGlassButton extends StatelessWidget {
  const DarsYarGlassButton({
    required this.onTap,
    required this.child,
    this.width,
    this.height = 48,
    this.radius = 16,
    this.style,
    this.quality = GlassQuality.standard,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double? width;
  final double height;
  final double radius;
  final GlassButtonStyle? style;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) => GlassButton.custom(
        width: width,
        height: height,
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        quality: quality,
        style: style,
        onTap: onTap,
        child: child,
      );
}
