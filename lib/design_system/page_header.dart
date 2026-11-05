import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A consistent RTL-friendly glass heading used by the primary destinations.
///
/// One bounded shader surface wraps the whole heading. The icon is deliberately
/// a tinted solid well so the header does not stack independent glass layers.
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

    return GlassContainer.card(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      shape: const LiquidRoundedSuperellipse(borderRadius: 25),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // A broad, soft specular reflection gives the surface a visible
          // curved-glass highlight while staying behind the title and icon.
          Positioned(
            top: -30,
            left: -22,
            child: IgnorePointer(
              child: Container(
                width: 178,
                height: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.13 : 0.48),
                      Colors.white.withValues(alpha: isDark ? 0.045 : 0.16),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.48, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 26,
            right: 26,
            child: IgnorePointer(
              child: Container(
                height: 0.7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: isDark ? 0.16 : 0.42),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 18,
            right: 18,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: isDark ? 0.34 : 0.78),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: isDark ? 0.22 : 0.16),
                      colors.secondary.withValues(alpha: isDark ? 0.16 : 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.07),
                  ),
                ),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(icon, color: colors.primary, size: 25),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.4,
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
          ),
        ],
      ),
    );
  }
}
