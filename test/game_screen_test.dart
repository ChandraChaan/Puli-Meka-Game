import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puli_meka/app_settings.dart';
import 'package:puli_meka/game/board.dart';
import 'package:puli_meka/game/game_controller.dart';
import 'package:puli_meka/game/puli_meka.dart';
import 'package:puli_meka/main.dart';
import 'package:puli_meka/screens/game_screen.dart';

Future<void> _frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('captures animate through to the result card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = GameController(mode: GameMode.twoPlayer, captureTarget: 2);
    await tester.pumpWidget(SettingsScope(
      settings: AppSettings.inMemory(),
      child: MaterialApp(home: GameScreen(controller: c)),
    ));
    await _frames(tester, 1200);

    // Goats walk into danger; tigers take every goat they can.
    var sawWarning = false;
    for (var i = 0; i < 40 && !c.isOver; i++) {
      final g = c.game;
      if (g.turn == Side.goat) {
        int? bait;
        for (final t in g.pointsWith(Cell.tiger)) {
          for (final j in Board.jumps[t]) {
            if (g.board[j.over] == Cell.empty && g.board[j.to] == Cell.empty) bait ??= j.over;
          }
        }
        c.tapPoint(bait ?? g.board.indexOf(Cell.empty));
      } else {
        final m = g.tigerMoves().first;
        c.tapPoint(m.from);
        c.tapPoint(m.to);
      }
      await _frames(tester, 600);
      if (find.textContaining('One more capture').evaluate().isNotEmpty) sawWarning = true;
    }

    expect(c.result?.outcome, Outcome.tigersWin);
    expect(sawWarning, isTrue);
    // The result card waits for the final leap to land.
    await _frames(tester, 1500);
    expect(find.text('Play again'), findsOneWidget);

    await tester.tap(find.text('Play again'));
    await _frames(tester, 1200);
    expect(c.history, isEmpty);
    expect(find.text('Play again'), findsNothing);
  });
}
