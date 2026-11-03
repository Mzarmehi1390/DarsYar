import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'darsyar_theme.dart';

/// A bounded, reusable Liquid Glass surface.
///
/// Blur is deliberately kept local to the surface rather than applied to
/// whole pages, keeping scrolling and large lists inexpensive.
class DarsYarGlassSurface extends StatelessWidget {
  const DarsYarGlassSurface({
    required this.child,
    this.radius = DarsYarTokens.radiusLarge,
    this.tint,
    this.padding = EdgeInsets.zero,
    this.blurSigma = DarsYarTokens.glassBlur,
    this.elevation = 1,
    super.key,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final base = tint ?? (isDark
        ? DarsYarTokens.darkSurface
        : DarsYarTokens.lightSurface);
    final edge = isDark
        ? const Color(0xFFB5F3D2).withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.88);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            if (elevation > 0)
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: (isDark ? 0.22 : 0.075) * elevation,
                ),
                blurRadius: 24.0 * elevation,
                spreadRadius: -5,
                offset: Offset(0, 9.0 * elevation),
              ),
            BoxShadow(
              color: (isDark ? DarsYarTokens.accentLight : Colors.white)
                  .withValues(alpha: isDark ? 0.055 : 0.42),
              blurRadius: 14,
              spreadRadius: -8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: edge, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    base.withValues(alpha: isDark ? 0.76 : 0.76),
                    colors.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.48 : 0.42,
                    ),
                    base.withValues(alpha: isDark ? 0.68 : 0.64),
                  ],
                  stops: const [0, 0.56, 1],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: radius * 0.8,
                    right: radius * 0.8,
                    child: IgnorePointer(
                      child: Container(
                        height: 1.1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: isDark ? 0.48 : 0.94),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
