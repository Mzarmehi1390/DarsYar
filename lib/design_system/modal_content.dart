import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Re-establishes DarsYar's typography, contrast and RTL contract inside
/// overlay routes, including Cupertino-based Liquid Glass controls.
/// A predictable label style for actions rendered inside Liquid Glass sheets.\n/// GlassButton's internal surface must not decide text contrast or typography.\nclass DarsYarModalButtonLabel extends StatelessWidget {\n  const DarsYarModalButtonLabel({\n    required this.child,\n    this.primary = false,\n    super.key,\n  });\n\n  final Widget child;\n  final bool primary;\n\n  @override\n  Widget build(BuildContext context) {\n    final theme = Theme.of(context);\n    final scheme = theme.colorScheme;\n    return DefaultTextStyle.merge(\n      textAlign: TextAlign.center,\n      style: TextStyle(\n        color: primary ? scheme.onPrimary : scheme.onSurface,\n        fontFamily: theme.textTheme.labelLarge?.fontFamily,\n        fontSize: 14,\n        fontWeight: FontWeight.w700,\n        height: 1.2,\n        decoration: TextDecoration.none,\n      ),\n      child: IconTheme(\n        data: IconThemeData(color: primary ? scheme.onPrimary : scheme.onSurface),\n        child: child,\n      ),\n    );\n  }\n}\n\nclass DarsYarModalContent extends StatelessWidget {
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
                fontWeight: FontWeight.w700,
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
