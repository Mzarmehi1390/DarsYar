import 'package:flutter/material.dart';

/// Re-establishes DarsYar's typography and RTL contract inside overlay routes.
///
/// Modal routes are rendered in a separate navigator overlay. Keeping these
/// inherited values explicit prevents platform/default overlay styles from
/// leaking into Persian labels and form controls.
class DarsYarModalContent extends StatelessWidget {
  const DarsYarModalContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: theme,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
          child: child,
        ),
      ),
    );
  }
}
