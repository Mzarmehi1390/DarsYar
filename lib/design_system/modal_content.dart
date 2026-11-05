import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Re-establishes DarsYar's typography, contrast and RTL contract inside
/// overlay routes, including Cupertino-based Liquid Glass controls.
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
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared safe-area contract for every glass sheet.
///
/// The bottom inset is supplied by the presenting route because some
/// edge-to-edge Android configurations report zero in the sheet route even
/// while the gesture/navigation region is still reserved by the system.
class DarsYarModalSheetContent extends StatelessWidget {
  const DarsYarModalSheetContent({
    required this.child,
    this.bottomInset = 0,
    super.key,
  });

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Keep direct uses and tests safe too, while preferring the presenter's
    // captured inset when this widget is hosted inside a modal route.
    final effectiveInset = math.max(
      bottomInset,
      math.max(
        media.viewPadding.bottom,
        math.max(media.systemGestureInsets.bottom, media.padding.bottom),
      ),
    );
    // Never cap a real system inset: large Android navigation areas and
    // edge-to-edge gesture regions must remain fully clear of fixed actions.
    final double bottomClearance = math.max(24.0, effectiveInset + 12);
    return DarsYarModalContent(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomClearance),
        child: child,
      ),
    );
  }
}
