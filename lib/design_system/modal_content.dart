import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Re-establishes DarsYar's typography, contrast and RTL contract inside
/// overlay routes, including Cupertino-based Liquid Glass controls.
/// A predictable label style for actions rendered inside Liquid Glass sheets.
/// GlassButton's internal surface must not decide text contrast or typography.
class DarsYarModalButtonLabel extends StatelessWidget {
  const DarsYarModalButtonLabel({
    required this.child,
    this.primary = false,
    super.key,
  });

  final Widget child;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DefaultTextStyle.merge(
      textAlign: TextAlign.center,
      style: TextStyle(
        color: primary ? scheme.onPrimary : scheme.onSurface,
        fontFamily: theme.textTheme.labelLarge?.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
        decoration: TextDecoration.none,
      ),
      child: IconTheme(
        data: IconThemeData(color: primary ? scheme.onPrimary : scheme.onSurface),
        child: child,
      ),
    );
  }
}

class DarsYarModalContent extends StatelessWidget {
  const DarsYarModalContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final modalTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      primaryTextTheme: theme.primaryTextTheme.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      iconTheme: theme.iconTheme.copyWith(color: scheme.onSurface),
      primaryIconTheme:
          theme.primaryIconTheme.copyWith(color: scheme.onPrimary),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: modalTheme,
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: theme.brightness,
            primaryColor: scheme.primary,
            // Cupertino-backed glass inputs inherit this style. Explicitly
            // bind their text to the active Material color scheme so neither
            // theme can fall back to low-contrast platform defaults.
            textTheme: CupertinoTextThemeData(
              textStyle: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontFamily: theme.textTheme.bodyLarge?.fontFamily,
              ),
              actionTextStyle: TextStyle(
                color: scheme.primary,
                fontFamily: theme.textTheme.labelLarge?.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          // Force the modal's readable foreground through nested package
          // defaults as well; GlassButton/GlassChip may otherwise reintroduce
          // a low-contrast default text style inside an overlay.
          child: IconTheme(
            data: IconThemeData(color: scheme.onSurface),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: scheme.onSurface,
                fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                fontSize: 14,
                height: 1.4,
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
              ),
              // Keep dynamic form/list repaints inside the modal content
              // layer instead of invalidating the surrounding glass surface.
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ),
    );
  }
}


/// Keeps every glass sheet's complete content above Android/iOS system
/// navigation areas. The inset belongs to the sheet as a whole, not only to
/// its action row, so scrolling content and fixed actions share one safe edge.
class DarsYarModalSheetContent extends StatelessWidget {
  const DarsYarModalSheetContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Some Android edge-to-edge configurations report the gesture-navigation
    // region through systemGestureInsets while viewPadding.bottom is zero.
    // Keep a minimum footer clearance as a final fallback for those devices.
    final systemBottomInset = math.max(
      media.viewPadding.bottom,
      math.max(media.systemGestureInsets.bottom, media.padding.bottom),
    );
    final bottomClearance = math.max(24.0, systemBottomInset + 8);
    return DarsYarModalContent(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomClearance),
        child: child,
      ),
    );
  }
}
