import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'glass_tokens.dart';

void showDarsYarGlassSnackBar(
  BuildContext context,
  SnackBar snackBar, {
  Duration? duration,
}) {
  final colors = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: GlassContainer.card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const LiquidRoundedSuperellipse(borderRadius: 18),
          quality: DarsYarGlassTokens.quality,
          useOwnLayer: true,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            child: snackBar.content,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        duration: duration ?? snackBar.duration,
        action: snackBar.action,
        onVisible: snackBar.onVisible,
      ),
    );
}
