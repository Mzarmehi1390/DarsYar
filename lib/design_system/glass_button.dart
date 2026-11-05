import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// The single DarsYar entry point for primary, secondary and compact glass
/// actions. Keeps geometry, quality and interaction semantics consistent.
class DarsYarGlassButton extends StatelessWidget {
  const DarsYarGlassButton({
    required this.onTap,
    required this.child,
    this.style = GlassButtonStyle.filled,
    this.width,
    this.height = 48,
    this.radius = 16,
    this.quality = GlassQuality.standard,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;
  final double? width;
  final double height;
  final double radius;
  final GlassButtonStyle style;
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

/// Shared icon action used for navigation, completion and compact controls.
class DarsYarGlassIconButton extends StatelessWidget {
  const DarsYarGlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 40,
    this.shape = GlassIconButtonShape.roundedSquare,
    this.quality = GlassQuality.standard,
    super.key,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;
  final GlassIconButtonShape shape;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: icon,
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        size: size,
        shape: shape,
        quality: quality,
      );
}
