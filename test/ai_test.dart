import 'dart:math';

import 'package:puli_meka/game/ai.dart';
import 'package:puli_meka/game/board.dart';
import 'package:puli_meka/game/puli_meka.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tiger takes a free goat', () {
    final g = PuliMekaGame()..apply(const Move.place(9));
    final m = PuliMekaAI(Difficulty.medium, random: Random(1)).chooseMove(g);
    expect(m.isCapture, isTrue);
  });

  test('goat does not hand the tiger a capture', () {
    final g = PuliMekaGame();
    final ai = PuliMekaAI(Difficulty.medium, random: Random(2));
    final m = ai.chooseMove(g);
    g.apply(m);
    expect(g.tigerMoves().where((t) => t.isCapture), isEmpty, reason: '$m');
  });

  test('goat blocks a threatened capture', () {
    // Goat on 9 is threatened by the tiger on 3 jumping to 15.
    final g = PuliMekaGame()
      ..apply(const Move.place(9))
      ..apply(const Move.step(0, 2));
    expect(g.goatsUnderThreat(), isNotEmpty);
    final m = PuliMekaAI(Difficulty.hard, random: Random(3)).chooseMove(g);
    g.apply(m);
    expect(g.tigerMoves().where((t) => t.isCapture), isEmpty, reason: '$m');
  });

  test('computer games always end legally', () {
    for (final seed in [1, 2, 3]) {
      final g = PuliMekaGame();
      final tiger = PuliMekaAI(Difficulty.medium, random: Random(seed));
      final goat = PuliMekaAI(Difficulty.easy, random: Random(seed + 10));
      final seen = <String, int>{};
      var plies = 0;
      while (g.result == null && plies < 300) {
        final ai = g.turn == Side.tiger ? tiger : goat;
        final m = ai.chooseMove(g);
        expect(g.legalMoves(), contains(m));
        g.apply(m);
        plies++;
        final n = seen.update(g.positionKey, (v) => v + 1, ifAbsent: () => 1);
        if (n >= 3) break;
        expect(g.pointsWith(Cell.tiger), hasLength(3));
        expect(g.pointsWith(Cell.goat).length, g.goatsOnBoard);
        expect(g.board.length, Board.pointCount);
      }
    }
  });

  test('hard search stays within its time budget', () {
    final g = PuliMekaGame();
    for (final p in [19, 20, 21, 22, 13, 18]) {
      g.apply(Move.place(p));
      g.apply(g.tigerMoves().firstWhere((m) => !m.isCapture));
    }
    final sw = Stopwatch()..start();
    PuliMekaAI(Difficulty.hard, random: Random(4)).chooseMove(g);
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}
