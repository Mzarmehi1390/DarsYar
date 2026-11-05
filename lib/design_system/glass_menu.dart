import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Shared contract for compact contextual glass menus across DarsYar.
class DarsYarGlassMenuButton extends StatelessWidget {
  const DarsYarGlassMenuButton({
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.menuWidth = 220,
    this.quality = GlassQuality.standard,
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final List<GlassMenuItem> items;
  final double menuWidth;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) => GlassPullDownButton(
        icon: icon,
        semanticLabel: semanticLabel,
        quality: quality,
        menuWidth: menuWidth,
        items: items,
      );
}
