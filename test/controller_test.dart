import 'package:puli_meka/game/ai.dart';
import 'package:puli_meka/game/game_controller.dart';
import 'package:puli_meka/game/puli_meka.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Move> _firstMove(PuliMekaGame g, Difficulty d, Map<String, int> seen) async =>
    g.legalMoves().first;

void main() {
  test('two players alternate and can undo', () {
    final c = GameController(mode: GameMode.twoPlayer)..start();
    c.tapPoint(20);
    expect(c.game.board[20], Cell.goat);
    expect(c.game.turn, Side.tiger);
    expect(c.pieces, hasLength(4));

    c.tapPoint(0); // select tiger
    expect(c.selected, 0);
    expect(c.selectedMoves, isNotEmpty);
    c.tapPoint(2);
    expect(c.game.board[2], Cell.tiger);
    expect(c.pieces.where((p) => p.isTiger).map((p) => p.point), containsAll([2, 3, 4]));

    c.undo();
    expect(c.game.board[0], Cell.tiger);
    expect(c.game.turn, Side.tiger);
    c.undo();
    expect(c.history, isEmpty);
    expect(c.pieces, hasLength(3));
  });

  test('capture removes the piece and undo restores it', () {
    final c = GameController(mode: GameMode.twoPlayer)..start();
    c.tapPoint(9);
    c.tapPoint(3);
    c.tapPoint(15);
    expect(c.game.goatsCaptured, 1);
    expect(c.pieces.where((p) => !p.isTiger), isEmpty);
    c.undo();
    expect(c.pieces.where((p) => !p.isTiger).single.point, 9);
  });

  test('computer replies and undo returns to the human', () async {
    final c = GameController(
      mode: GameMode.vsComputer,
      humanSide: Side.goat,
      moveFinder: _firstMove,
      aiDelay: Duration.zero,
    )..start();
    c.tapPoint(22);
    expect(c.isComputerTurn, isTrue);
    await pumpEventQueue();
    expect(c.game.turn, Side.goat);
    expect(c.history, hasLength(2));

    c.undo();
    expect(c.history, isEmpty);
    expect(c.game.turn, Side.goat);
  });

  test('computer moves first when it has the goats', () async {
    final c = GameController(
      mode: GameMode.vsComputer,
      humanSide: Side.tiger,
      moveFinder: _firstMove,
      aiDelay: Duration.zero,
    )..start();
    await pumpEventQueue();
    expect(c.history, hasLength(1));
    expect(c.isHumanTurn, isTrue);
    expect(c.canUndo, isFalse);
  });

  test('threefold repetition is a draw', () {
    final c = GameController(mode: GameMode.twoPlayer, captureTarget: 7)..start();
    final g = c.game;
    // Place all 15 goats on safe points while tigers shuffle.
    final safe = [1, 6, 7, 12, 13, 18, 19, 20, 21, 22, 14, 17, 8, 11, 15];
    var tigerAtApex = true;
    for (final p in safe) {
      c.tapPoint(p);
      if (c.isOver) break;
      final m = g.tigerMoves().firstWhere((m) => !m.isCapture);
      c.tapPoint(m.from);
      c.tapPoint(m.to);
      tigerAtApex = !tigerAtApex;
    }
    expect(c.isOver, isFalse);
    expect(g.isPlacementPhase, isFalse);
    // Shuffle one goat and one tiger back and forth.
    final goatMove = g.goatMoves().first;
    final steps = [goatMove, Move.step(goatMove.to, goatMove.from)];
    for (var i = 0; i < 4 && !c.isOver; i++) {
      final gm = steps[i % 2];
      c.tapPoint(gm.from);
      c.tapPoint(gm.to);
      if (c.isOver) break;
      final tm = g.tigerMoves().firstWhere((m) => !m.isCapture);
      final back = Move.step(tm.to, tm.from);
      c.tapPoint(tm.from);
      c.tapPoint(tm.to);
      if (c.isOver) break;
      // Undo the tiger's wander on the next round.
      c.tapPoint(steps[(i + 1) % 2].from);
      c.tapPoint(steps[(i + 1) % 2].to);
      if (c.isOver) break;
      c.tapPoint(back.from);
      c.tapPoint(back.to);
    }
    expect(c.result?.outcome, Outcome.draw);
    expect(c.result?.reason, OutcomeReason.repetition);
  });
}
