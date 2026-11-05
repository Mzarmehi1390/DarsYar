import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../design_system/darsyar_theme.dart';

/// Owns the persistent app chrome and active-page transition.
///
/// Keeping this widget separate from the home state owner prevents feature
/// updates from coupling navigation chrome to feature orchestration.
class DarsYarHomeShell extends StatelessWidget {
  const DarsYarHomeShell({
    required this.page,
    required this.loading,
    required this.background,
    required this.selectedIndex,
    required this.liteMotion,
    required this.onTabSelected,
    super.key,
  });

  final Widget page;
  final bool loading;
  final Widget background;
  final int selectedIndex;
  final bool liteMotion;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassScaffold(
        // Keep the decorative atmosphere in its own paint layer. Feature
        // updates repaint active content without repainting the backdrop.
        background: background,
        body: SafeArea(
          bottom: false,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RepaintBoundary(
                  // Isolate page animation and timer-driven paints from the
                  // persistent glass tab bar and ambient backdrop.
                  child: AnimatedSwitcher(
                    // Do not retain the previous expensive page tree during
                    // navigation; preserve the incoming page's glass motion.
                    layoutBuilder: (currentChild, previousChildren) =>
                        currentChild ?? const SizedBox.shrink(),
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      if (liteMotion) {
                        return FadeTransition(opacity: curved, child: child);
                      }
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.012),
                        end: Offset.zero,
                      ).animate(curved);
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(selectedIndex),
                      child: page,
                    ),
                  ),
                ),
        ),
        bottomBar: loading
            ? null
            : GlassTabBar.bottom(
                tabs: const [
                  GlassTab(
                    icon: Icon(Icons.grid_view_rounded),
                    activeIcon: Icon(Icons.grid_view_rounded),
                    label: 'خانه',
                    semanticLabel: 'خانه',
                    glowColor: DarsYarTokens.accent,
                  ),
                  GlassTab(
                    icon: Icon(Icons.calendar_month_outlined),
                    activeIcon: Icon(Icons.calendar_month_rounded),
                    label: 'برنامه‌ریزی',
                    semanticLabel: 'برنامه‌ریزی',
                    glowColor: DarsYarTokens.accent,
                  ),
                  GlassTab(
                    icon: Icon(Icons.fact_check_outlined),
                    activeIcon: Icon(Icons.fact_check_rounded),
                    label: 'پاسخ‌برگ',
                    semanticLabel: 'پاسخ‌برگ',
                    glowColor: DarsYarTokens.accent,
                  ),
                  GlassTab(
                    icon: Icon(Icons.tune_outlined),
                    activeIcon: Icon(Icons.tune_rounded),
                    label: 'تنظیمات',
                    semanticLabel: 'تنظیمات',
                    glowColor: DarsYarTokens.accent,
                  ),
                ],
                selectedIndex: selectedIndex,
                onTabSelected: onTabSelected,
                selectedIconColor: isDark
                    ? DarsYarTokens.accentLight
                    : DarsYarTokens.accent,
                unselectedIconColor: theme.colorScheme.onSurfaceVariant,
                selectedLabelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                iconSize: 23,
                labelFontSize: 10.5,
                magnification: 1.12,
              ),
      ),
    );
  }
}
