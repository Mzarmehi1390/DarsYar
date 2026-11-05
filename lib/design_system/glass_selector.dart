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

/// Shared day/category chip used for compact single-choice navigation.
class DarsYarGlassChoiceChip extends StatelessWidget {
  const DarsYarGlassChoiceChip({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.selectedColor,
    required this.labelStyle,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.quality = GlassQuality.standard,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final Color selectedColor;
  final TextStyle labelStyle;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) => GlassChip(
        label: label,
        semanticLabel: semanticLabel,
        selected: selected,
        selectedColor: selectedColor,
        labelStyle: labelStyle,
        padding: padding,
        quality: quality,
        onTap: onTap,
      );
}


/// Shared circular choice used for compact selectors such as weekdays.
/// Keeps tap semantics, selection contrast and motion consistent.
class DarsYarGlassCircularChoice extends StatelessWidget {
  const DarsYarGlassCircularChoice({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
    this.size = 42,
    this.animationDuration = const Duration(milliseconds: 150),
    super.key,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: AnimatedContainer(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? scheme.primary.withValues(alpha: 0.18)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                border: Border.all(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.78)
                      : scheme.outlineVariant.withValues(alpha: 0.62),
                  width: selected ? 1.4 : 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
