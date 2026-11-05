import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:dars_yar/app/presentation/home_shell.dart';
import 'package:dars_yar/design_system/darsyar_theme.dart';

void main() {
  testWidgets('home shell renders the active page and forwards tab changes',
      (tester) async {
    int? selectedTab;

    await tester.pumpWidget(
      MaterialApp(
        theme: DarsYarTheme.light,
        home: DarsYarHomeShell(
          page: const Text('صفحه فعال'),
          loading: false,
          background: const SizedBox.shrink(),
          selectedIndex: 0,
          liteMotion: true,
          onTabSelected: (index) => selectedTab = index,
        ),
      ),
    );

    expect(find.text('صفحه فعال'), findsOneWidget);
    expect(find.byType(GlassTabBar), findsOneWidget);
    await tester.tap(find.text('برنامه‌ریزی'));
    expect(selectedTab, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shell keeps navigation hidden while loading',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DarsYarTheme.light,
        home: const DarsYarHomeShell(
          page: Text('صفحه پنهان'),
          loading: true,
          background: SizedBox.shrink(),
          selectedIndex: 0,
          liteMotion: true,
          onTabSelected: _ignoreTab,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('صفحه پنهان'), findsNothing);
    expect(find.byType(GlassTabBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreTab(int _) {}
