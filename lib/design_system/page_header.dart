import 'package:flutter/material.dart';

import 'darsyar_theme.dart';
import 'glass_surface.dart';

/// A consistent RTL-friendly heading used by the primary DarsYar destinations.
class DarsYarPageHeader extends StatelessWidget {
  const DarsYarPageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DarsYarGlassSurface(
          radius: 19,
          elevation: 0.55,
          padding: const EdgeInsets.all(11),
          tint: isDark
              ? const Color(0xFF244C4A)
              : const Color(0xFFD8F0E8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withValues(alpha: 0.17),
                  colors.secondary.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 29,
              height: 29,
              child: Icon(icon, color: colors.primary, size: 23),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
