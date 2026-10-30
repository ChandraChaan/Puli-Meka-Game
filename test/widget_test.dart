import 'package:beryapp/app_settings.dart';
import 'package:beryapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The board pulses forever, so settle by pumping a fixed time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('home screen opens a two player game', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PuliMekaApp(settings: AppSettings.inMemory()));
    await _settle(tester);
    expect(find.text('పులి మేక'), findsOneWidget);
    expect(find.text('Play vs Computer'), findsOneWidget);

    await tester.ensureVisible(find.text('2 Players'));
    await tester.tap(find.text('2 Players'));
    await _settle(tester);
    expect(find.textContaining('Place a goat'), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
  });

  testWidgets('about screen shows version, privacy and links', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    PackageInfo.setMockInitialValues(
      appName: 'Puli Meka',
      packageName: 'com.beryapp.beryapp',
      version: '2.1.0',
      buildNumber: '7',
      buildSignature: '',
    );

    await tester.pumpWidget(PuliMekaApp(settings: AppSettings.inMemory()));
    await _settle(tester);
    await tester.tap(find.byTooltip('About'));
    await _settle(tester);

    expect(find.text('Version 2.1.0 (7)'), findsOneWidget);
    expect(find.text('About this app'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Privacy'), 200);
    expect(find.text('Privacy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Source code'), 200);
    expect(find.text('Report a problem or idea'), findsOneWidget);
  });

  testWidgets('language switches to Telugu', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PuliMekaApp(settings: AppSettings.inMemory()));
    await tester.tap(find.text('తెలుగు'));
    await _settle(tester);
    expect(find.text('కంప్యూటర్‌తో ఆడండి'), findsOneWidget);
  });
}
