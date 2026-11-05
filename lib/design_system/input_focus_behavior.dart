import 'package:flutter/material.dart';

/// Applies the shared first-focus selection behavior to any input control.
///
/// When a field still contains its untouched initial value (for example "0"),
/// focusing it selects that value so typing replaces it instead of appending.
class DarsYarInputFocusBehavior extends StatelessWidget {
  const DarsYarInputFocusBehavior({
    required this.controller,
    required this.child,
    this.initialValue = '0',
    this.selectInitialValue = true,
    super.key,
  });

  final TextEditingController controller;
  final Widget child;
  final String initialValue;
  final bool selectInitialValue;

  @override
  Widget build(BuildContext context) => Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus ||
              !selectInitialValue ||
              controller.text != initialValue) {
            return;
          }
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        },
        child: child,
      );
}
