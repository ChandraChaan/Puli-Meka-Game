import 'package:beryapp/game/board.dart';
import 'package:beryapp/game/puli_meka.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Board', () {
    test('has 23 points with symmetric neighbours', () {
      expect(Board.positions, hasLength(23));
      for (var p = 0; p < Board.pointCount; p++) {
        for (final n in Board.neighbours[p]) {
          expect(Board.neighbours[n], contains(p), reason: '$p-$n');
        }
      }
      expect(Board.neighbours[0], [2, 3, 4, 5]);
      expect(Board.neighbours[9], [3, 8, 10, 15]);
      expect(Board.neighbours[19], [14, 20]);
    });

    test('jumps follow straight lines', () {
      final from0 = Board.jumps[0].map((j) => (j.over, j.to)).toSet();
      expect(from0, {(2, 8), (3, 9), (4, 10), (5, 11)});
      final from20 = Board.jumps[20].map((j) => (j.over, j.to)).toSet();
      expect(from20, {(15, 9), (21, 22)});
    });
  });

  group('PuliMekaGame', () {
    test('starts with three tigers and goats to move', () {
      final g = PuliMekaGame();
      expect(g.pointsWith(Cell.tiger).toList(), Board.tigerStart);
      expect(g.turn, Side.goat);
      expect(g.goatsInHand, 15);
      expect(g.legalMoves(), hasLength(20));
      expect(g.result, isNull);
    });

    test('goats cannot move until all are placed', () {
      final g = PuliMekaGame()
        ..apply(const Move.place(20))
        ..apply(const Move.step(0, 2));
      expect(g.movesFrom(20), isEmpty);
      expect(g.legalMoves().every((m) => m.isPlacement), isTrue);
    });

    test('tiger captures by jumping into an empty point', () {
      final g = PuliMekaGame()..apply(const Move.place(9));
      expect(g.tigerMoves(), contains(const Move.jump(3, 9, 15)));
      expect(g.tigerMoves().first.isCapture, isTrue);
      g.apply(const Move.jump(3, 9, 15));
      expect(g.board[9], Cell.empty);
      expect(g.board[15], Cell.tiger);
      expect(g.goatsCaptured, 1);
      expect(g.goatsOnBoard, 0);

      g.undo(const Move.jump(3, 9, 15));
      expect(g.board[9], Cell.goat);
      expect(g.board[3], Cell.tiger);
      expect(g.goatsCaptured, 0);
      expect(g.turn, Side.tiger);
    });

    test('a goat with a guarded back cannot be captured', () {
      final g = PuliMekaGame()
        ..apply(const Move.place(15))
        ..apply(const Move.step(0, 2))
        ..apply(const Move.place(9));
      // Tiger on 3 cannot jump 9 because 15 is occupied.
      expect(g.tigerMoves().where((m) => m.isCapture), isEmpty);
    });

    test('goats win by trapping every tiger', () {
      final g = PuliMekaGame();
      g.board.fillRange(0, Board.pointCount, Cell.goat);
      g.board[0] = Cell.tiger;
      g.board[3] = Cell.tiger;
      g.board[4] = Cell.tiger;
      g.board[22] = Cell.empty;
      g.goatsPlaced = PuliMekaGame.totalGoats;
      g.turn = Side.tiger;
      final r = g.result!;
      expect(r.outcome, Outcome.goatsWin);
      expect(r.reason, OutcomeReason.tigersTrapped);
    });

    test('tigers win on reaching the capture target', () {
      final g = PuliMekaGame(captureTarget: 4)..goatsCaptured = 4;
      expect(g.result?.outcome, Outcome.tigersWin);
    });

    test('copy is independent', () {
      final g = PuliMekaGame();
      final c = PuliMekaGame.copy(g)..apply(const Move.place(10));
      expect(g.board[10], Cell.empty);
      expect(c.board[10], Cell.goat);
      expect(g.positionKey, isNot(c.positionKey));
    });
  });
}
