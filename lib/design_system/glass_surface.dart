import 'package:flutter/material.dart';

import 'darsyar_theme.dart';

/// A high-contrast content surface for dense study information.
///
/// Native iOS keeps list rows and grouped content on solid surfaces; reserve
/// refractive glass for floating chrome and focal controls.
class DarsYarContentSurface extends StatelessWidget {
  const DarsYarContentSurface({
    required this.child,
    this.radius = DarsYarTokens.radiusLarge,
    this.tint,
    this.padding = EdgeInsets.zero,
    this.elevation = 0.35,
    super.key,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final fill = tint == null
        ? scheme.surface
        : Color.alphaBlend(
            tint!.withValues(alpha: isDark ? 0.16 : 0.12),
            scheme.surface,
          );
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.52),
          ),
          boxShadow: [
            if (elevation > 0)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.045),
                blurRadius: 18 * elevation,
                spreadRadius: -5,
                offset: Offset(0, 7 * elevation),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
