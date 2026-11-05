import 'package:flutter/material.dart';

/// Applies the shared first-focus selection behavior to any input control.
///
/// When a field still contains its untouched initial value (for example "0"),
/// focusing it selects that value so typing replaces it instead of appending.
class DarsYarInputFocusBehavior extends StatefulWidget {
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
  State<DarsYarInputFocusBehavior> createState() =>
      _DarsYarInputFocusBehaviorState();
}

class _DarsYarInputFocusBehaviorState
    extends State<DarsYarInputFocusBehavior> {
  late bool _initialValueWasChanged;

  @override
  void initState() {
    super.initState();
    _initialValueWasChanged =
        widget.controller.text != widget.initialValue;
    widget.controller.addListener(_trackInitialValueChange);
  }

  @override
  void didUpdateWidget(covariant DarsYarInputFocusBehavior oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_trackInitialValueChange);
      widget.controller.addListener(_trackInitialValueChange);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.initialValue != widget.initialValue) {
      _initialValueWasChanged =
          widget.controller.text != widget.initialValue;
    }
  }

  void _trackInitialValueChange() {
    if (!_initialValueWasChanged &&
        widget.controller.text != widget.initialValue) {
      _initialValueWasChanged = true;
    }
  }

  void _handleFocusChange(bool hasFocus) {
    if (!hasFocus ||
        !widget.selectInitialValue ||
        _initialValueWasChanged ||
        widget.controller.text != widget.initialValue) {
      return;
    }
    widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.controller.text.length,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_trackInitialValueChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        onFocusChange: _handleFocusChange,
        child: widget.child,
      );
}
