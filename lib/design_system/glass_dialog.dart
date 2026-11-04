import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'modal_content.dart';
import 'glass_tokens.dart';

/// Shows the package's glass dialog with a DarsYar-owned modal barrier.
///
/// The upstream GlassDialog.show API currently accepts a barrierColor but
/// does not forward it to its Cupertino route. Using our own route keeps the
/// backdrop tint predictable and preserves the app's RTL/theme inheritance.
Future<T?> showDarsYarGlassDialog<T>({
  required BuildContext context,
  required List<GlassDialogAction> actions,
  String? title,
  String? message,
  Widget? content,
  LiquidGlassSettings? settings,
  GlassQuality quality = DarsYarGlassTokens.quality,
  bool barrierDismissible = false,
  Color barrierColor = DarsYarGlassTokens.dialogBarrierColor,
  double maxWidth = 280,
}) {
  final liteMotion = MediaQuery.of(context).disableAnimations;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: DarsYarGlassTokens.modalTransitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: DarsYarModalContent(
          child: GlassDialog(
            title: title,
            message: message,
            content: content,
            actions: actions,
            settings: settings,
            quality: quality,
            maxWidth: maxWidth,
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      if (liteMotion) {
        return FadeTransition(opacity: curved, child: child);
      }
      final scale = Tween<double>(begin: 0.985, end: 1.0).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}
