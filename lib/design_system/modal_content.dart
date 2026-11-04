import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Re-establishes DarsYar's typography, contrast and RTL contract inside
/// overlay routes, including Cupertino-based Liquid Glass controls.
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
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
