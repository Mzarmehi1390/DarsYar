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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DarsYarGlassSurface(
          radius: DarsYarTokens.radiusMedium,
          elevation: 0,
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: colors.primary, size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
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
