import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/darsyar_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LiquidGlassWidgets.initialize();
  } catch (_) {
    // The adaptive glass widgets retain their standard fallback if shader
    // prewarming is unavailable on a particular device or renderer.
  }
  runApp(const DarsYarApp());
}
