import 'package:flutter/material.dart';

import 'darsyar_theme.dart';

/// Static atmospheric backdrop shared by the app shell.
///
/// Keeping this decorative layer isolated behind a repaint boundary prevents
/// page state changes (including the exam timer) from repainting the gradients.
class GlassAmbientBackground extends StatelessWidget {
  const GlassAmbientBackground({required this.isDark, super.key});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark
                    ? const [
                        Color(0xFF101D30),
                        Color(0xFF0A1321),
                        Color(0xFF1A2034),
                      ]
                    : const [
                        Color(0xFFF5F8FD),
                        Color(0xFFE8F0F8),
                        Color(0xFFF0ECF8),
                      ],
              ),
            ),
          ),
          Positioned(
            top: -150,
            right: -125,
            child: IgnorePointer(
              child: Container(
                width: 330,
                height: 330,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      DarsYarTokens.accent.withValues(
                        alpha: isDark ? 0.22 : 0.16,
                      ),
                      DarsYarTokens.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -175,
            left: -135,
            child: IgnorePointer(
              child: Container(
                width: 370,
                height: 370,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                              ? const Color(0xFF4F8EB8)
                              : const Color(0xFF8EBBE8))
                          .withValues(alpha: isDark ? 0.16 : 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -150,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                              ? const Color(0xFF6673C8)
                              : const Color(0xFFB8A8EE))
                          .withValues(alpha: isDark ? 0.13 : 0.19),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
