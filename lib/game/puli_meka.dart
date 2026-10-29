/// Rules engine for Puli Meka (Tiger & Goats).
library;

import 'board.dart';

enum Side {
  goat,
  tiger;

  Side get opponent => this == goat ? tiger : goat;
}

/// Contents of a board point.
class Cell {
  Cell._();
  static const int empty = 0;
  static const int goat = 1;
  static const int tiger = 2;
}

class Move {
  /// Origin point, or -1 when a goat is placed from the hand.
  final int from;
  final int to;

  /// The goat jumped over and captured, or -1.
  final int captured;

  const Move.place(this.to)
      : from = -1,
        captured = -1;
  const Move.step(this.from, this.to) : captured = -1;
  const Move.jump(this.from, this.captured, this.to);

  bool get isPlacement => from < 0;
  bool get isCapture => captured >= 0;

  @override
  bool operator ==(Object other) =>
      other is Move && other.from == from && other.to == to && other.captured == captured;

  @override
  int get hashCode => Object.hash(from, to, captured);

  @override
  String toString() => isPlacement
      ? 'place@$to'
      : isCapture
          ? '$from x$captured>$to'
          : '$from>$to';
}

enum Outcome { tigersWin, goatsWin, draw }

enum OutcomeReason { captures, tigersTrapped, goatsTrapped, repetition }

class GameResult {
  final Outcome outcome;
  final OutcomeReason reason;
  const GameResult(this.outcome, this.reason);

  Side? get winner => switch (outcome) {
        Outcome.tigersWin => Side.tiger,
        Outcome.goatsWin => Side.goat,
        Outcome.draw => null,
      };
}

/// Mutable game position. [apply] and [undo] are cheap so the AI can search
/// in place.
class PuliMekaGame {
  static const int totalGoats = 15;
  static const List<int> captureTargets = [4, 5, 6, 7];
  static const int defaultCaptureTarget = 5;

  final List<int> board;
  Side turn;
  int goatsPlaced;
  int goatsCaptured;

  /// Goats the tigers must capture to win.
  final int captureTarget;

  PuliMekaGame({this.captureTarget = defaultCaptureTarget})
      : board = List.filled(Board.pointCount, Cell.empty),
        turn = Side.goat,
        goatsPlaced = 0,
        goatsCaptured = 0 {
    for (final p in Board.tigerStart) {
      board[p] = Cell.tiger;
    }
  }

  PuliMekaGame.copy(PuliMekaGame other)
      : board = List.of(other.board),
        turn = other.turn,
        goatsPlaced = other.goatsPlaced,
        goatsCaptured = other.goatsCaptured,
        captureTarget = other.captureTarget;

  int get goatsInHand => totalGoats - goatsPlaced;
  int get goatsOnBoard => goatsPlaced - goatsCaptured;
  bool get isPlacementPhase => goatsPlaced < totalGoats;

  /// A compact key identifying the position, used for repetition checks.
  String get positionKey => '${turn.index}${goatsPlaced.toRadixString(16)}${board.join()}';

  Iterable<int> pointsWith(int cell) sync* {
    for (var i = 0; i < board.length; i++) {
      if (board[i] == cell) yield i;
    }
  }

  List<Move> legalMoves() => turn == Side.goat ? goatMoves() : tigerMoves();

  List<Move> goatMoves() {
    final moves = <Move>[];
    if (isPlacementPhase) {
      for (var p = 0; p < board.length; p++) {
        if (board[p] == Cell.empty) moves.add(Move.place(p));
      }
      return moves;
    }
    for (var p = 0; p < board.length; p++) {
      if (board[p] != Cell.goat) continue;
      for (final n in Board.neighbours[p]) {
        if (board[n] == Cell.empty) moves.add(Move.step(p, n));
      }
    }
    return moves;
  }

  /// Tiger moves, captures first so the search sees them early.
  List<Move> tigerMoves() {
    final captures = <Move>[];
    final steps = <Move>[];
    for (var p = 0; p < board.length; p++) {
      if (board[p] != Cell.tiger) continue;
      _addTigerMoves(p, captures, steps);
    }
    return captures..addAll(steps);
  }

  void _addTigerMoves(int p, List<Move> captures, List<Move> steps) {
    for (final j in Board.jumps[p]) {
      if (board[j.over] == Cell.goat && board[j.to] == Cell.empty) {
        captures.add(Move.jump(p, j.over, j.to));
      }
    }
    for (final n in Board.neighbours[p]) {
      if (board[n] == Cell.empty) steps.add(Move.step(p, n));
    }
  }

  /// Legal moves for the piece on [point] if it belongs to the side to move.
  List<Move> movesFrom(int point) {
    final cell = board[point];
    if (turn == Side.tiger && cell == Cell.tiger) {
      final captures = <Move>[];
      final steps = <Move>[];
      _addTigerMoves(point, captures, steps);
      return captures..addAll(steps);
    }
    if (turn == Side.goat && cell == Cell.goat && !isPlacementPhase) {
      return [
        for (final n in Board.neighbours[point])
          if (board[n] == Cell.empty) Move.step(point, n),
      ];
    }
    return const [];
  }

  /// Number of moves the tiger on [point] has, ignoring whose turn it is.
  int tigerMobility(int point) {
    var count = 0;
    for (final n in Board.neighbours[point]) {
      if (board[n] == Cell.empty) count++;
    }
    for (final j in Board.jumps[point]) {
      if (board[j.over] == Cell.goat && board[j.to] == Cell.empty) count++;
    }
    return count;
  }

  /// Goats that some tiger could capture right now if it were its turn.
  Set<int> goatsUnderThreat() {
    final threatened = <int>{};
    for (var p = 0; p < board.length; p++) {
      if (board[p] != Cell.tiger) continue;
      for (final j in Board.jumps[p]) {
        if (board[j.over] == Cell.goat && board[j.to] == Cell.empty) {
          threatened.add(j.over);
        }
      }
    }
    return threatened;
  }

  void apply(Move m) {
    if (m.isPlacement) {
      board[m.to] = Cell.goat;
      goatsPlaced++;
    } else {
      board[m.to] = board[m.from];
      board[m.from] = Cell.empty;
      if (m.isCapture) {
        board[m.captured] = Cell.empty;
        goatsCaptured++;
      }
    }
    turn = turn.opponent;
  }

  void undo(Move m) {
    turn = turn.opponent;
    if (m.isPlacement) {
      board[m.to] = Cell.empty;
      goatsPlaced--;
    } else {
      board[m.from] = board[m.to];
      board[m.to] = Cell.empty;
      if (m.isCapture) {
        board[m.captured] = Cell.goat;
        goatsCaptured--;
      }
    }
  }

  /// The result of the game if it has ended, ignoring repetition (which
  /// needs the game history and is tracked by the caller).
  GameResult? get result {
    if (goatsCaptured >= captureTarget) {
      return const GameResult(Outcome.tigersWin, OutcomeReason.captures);
    }
    if (legalMoves().isEmpty) {
      return turn == Side.tiger
          ? const GameResult(Outcome.goatsWin, OutcomeReason.tigersTrapped)
          : const GameResult(Outcome.tigersWin, OutcomeReason.goatsTrapped);
    }
    return null;
  }
}
