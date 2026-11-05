import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Canonical segmented selector for top-level navigation and preferences.
/// Keeps selection geometry, glass quality and text contrast consistent.
class DarsYarGlassSegmentedControl extends StatelessWidget {
  const DarsYarGlassSegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
    this.height = 46,
    this.borderRadius = 20,
    this.quality = GlassQuality.standard,
    this.useOwnLayer = true,
    this.selectedTextStyle,
    this.unselectedTextStyle,
    this.backgroundColor,
    this.indicatorColor,
    super.key,
  });

  final List<GlassSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentSelected;
  final double height;
  final double borderRadius;
  final GlassQuality quality;
  final bool useOwnLayer;
  final TextStyle? selectedTextStyle;
  final TextStyle? unselectedTextStyle;
  final Color? backgroundColor;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) => GlassSegmentedControl(
        segments: segments,
        selectedIndex: selectedIndex,
        onSegmentSelected: onSegmentSelected,
        height: height,
        borderRadius: borderRadius,
        quality: quality,
        useOwnLayer: useOwnLayer,
        selectedTextStyle: selectedTextStyle,
        unselectedTextStyle: unselectedTextStyle,
        backgroundColor: backgroundColor,
        indicatorColor: indicatorColor,
      );
}
