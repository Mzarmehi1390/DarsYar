import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'darsyar_theme.dart';

/// A bounded optical material inspired by Apple's Liquid Glass language.
///
/// The blur is intentionally clipped to each surface. Multiple restrained
/// highlights create a sense of thickness and reflection without obscuring
/// the content placed above the material.
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
    final scheme = Theme.of(context).colorScheme;
    final base = tint ?? (isDark
        ? DarsYarTokens.darkSurface
        : DarsYarTokens.lightSurface);
    final outerEdge = isDark
        ? const Color(0xFFDAFFF1).withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.82);
    final innerEdge = isDark
        ? const Color(0xFF8EDCC4).withValues(alpha: 0.12)
        : const Color(0xFF789FAD).withValues(alpha: 0.10);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            if (elevation > 0)
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: (isDark ? 0.25 : 0.085) * elevation,
                ),
                blurRadius: 28 * elevation,
                spreadRadius: -7,
                offset: Offset(0, 11 * elevation),
              ),
            BoxShadow(
              color: (isDark ? DarsYarTokens.accentLight : Colors.white)
                  .withValues(alpha: isDark ? 0.075 : 0.56),
              blurRadius: 18,
              spreadRadius: -11,
              offset: const Offset(0, -3),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    base.withValues(alpha: isDark ? 0.66 : 0.62),
                    scheme.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.48 : 0.40,
                    ),
                    base.withValues(alpha: isDark ? 0.58 : 0.54),
                  ],
                  stops: const [0, 0.48, 1],
                ),
                border: Border.all(color: outerEdge, width: 1.05),
              ),
              child: Stack(
                children: [
                  // A soft reflected highlight, concentrated along the upper
                  // edge instead of washing out the whole content surface.
                  Positioned(
                    top: 0,
                    left: radius * 0.7,
                    right: radius * 0.7,
                    child: IgnorePointer(
                      child: Container(
                        height: 1.4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: isDark ? 0.72 : 1),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // A faint lower rim gives the material a glass-like edge.
                  Positioned(
                    left: 1,
                    right: 1,
                    bottom: 1,
                    child: IgnorePointer(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              innerEdge.withValues(alpha: 0),
                              innerEdge,
                              innerEdge.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Small specular bloom: visible on the material, never
                  // placed over text or controls.
                  Positioned(
                    top: -radius * 0.72,
                    left: -radius * 0.45,
                    child: IgnorePointer(
                      child: Container(
                        width: radius * 3.2,
                        height: radius * 1.65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(
                                alpha: isDark ? 0.095 : 0.32,
                              ),
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
