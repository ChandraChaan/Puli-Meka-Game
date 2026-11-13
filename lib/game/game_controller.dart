/// Drives one game: turns, the computer opponent, undo, hints and the
/// on-screen pieces.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai.dart';
import 'board.dart';
import 'puli_meka.dart';

enum GameMode { vsComputer, twoPlayer, online }

/// A piece on screen. Pieces keep their [id] as they move so the board can
/// animate them.
class Piece {
  final int id;
  final bool isTiger;
  int point;
  Piece(this.id, this.isTiger, this.point);
}

typedef MoveFinder = Future<Move> Function(
    PuliMekaGame game, Difficulty difficulty, Map<String, int> seen);

Move _findMove((PuliMekaGame, Difficulty, Map<String, int>) request) =>
    PuliMekaAI(request.$2).chooseMove(request.$1, seen: request.$3);

/// Runs the search on a background isolate where the platform allows it.
Future<Move> defaultMoveFinder(PuliMekaGame game, Difficulty difficulty, Map<String, int> seen) =>
    compute(_findMove, (game, difficulty, seen));

class GameController extends ChangeNotifier {
  final GameMode mode;

  /// The side the human plays against the computer or an online opponent.
  /// Online, sides swap on a rematch.
  Side humanSide;

  /// The other player's name in an online game.
  String? opponentName;
  final Difficulty difficulty;
  final int captureTarget;
  final MoveFinder _findMoveFor;

  /// Minimum time the computer appears to think, so its moves are easy to
  /// follow.
  final Duration aiDelay;

  /// Called after every move, for sounds and vibration.
  void Function(Move move)? onMove;

  /// Called after this player moves in an online game, to send the move.
  void Function(Move move)? onLocalMove;

  /// Called when the player picks up a piece.
  void Function(int point)? onSelect;

  /// Called when the player taps somewhere they cannot play.
  void Function(int point)? onInvalidTap;

  /// Called once when the game ends.
  void Function(GameResult result)? onGameOver;

  late PuliMekaGame game;
  final List<Move> history = [];
  final Map<String, int> _seen = {};
  final List<Piece> pieces = [];
  int _nextPieceId = 0;

  int? selected;
  Move? hint;
  GameResult? result;
  bool thinking = false;
  bool hinting = false;
  int _searchToken = 0;
  bool _disposed = false;

  GameController({
    required this.mode,
    this.humanSide = Side.goat,
    this.difficulty = Difficulty.medium,
    this.captureTarget = PuliMekaGame.defaultCaptureTarget,
    MoveFinder? moveFinder,
    this.aiDelay = const Duration(milliseconds: 550),
  }) : _findMoveFor = moveFinder ?? defaultMoveFinder {
    _reset();
  }

  void _reset() {
    game = PuliMekaGame(captureTarget: captureTarget);
    history.clear();
    _seen
      ..clear()
      ..[game.positionKey] = 1;
    pieces
      ..clear()
      ..addAll([for (final p in game.pointsWith(Cell.tiger)) Piece(_nextPieceId++, true, p)]);
    selected = null;
    hint = null;
    result = null;
    thinking = false;
    hinting = false;
    _searchToken++;
  }

  /// Begins play; lets the computer move first if it has the goats.
  void start() => _maybeComputerTurn();

  void restart({Side? side}) {
    if (side != null) humanSide = side;
    _reset();
    notifyListeners();
    _maybeComputerTurn();
  }

  bool get isOver => result != null;
  bool get isComputerTurn => mode == GameMode.vsComputer && game.turn != humanSide && !isOver;

  /// Whether the person holding this phone may move now.
  bool get isHumanTurn =>
      !isOver && !isComputerTurn && (mode != GameMode.online || game.turn == humanSide);
  bool get isOnline => mode == GameMode.online;
  Move? get lastMove => history.isEmpty ? null : history.last;

  /// The goats a tiger could jump right now, shown as a warning on the goats'
  /// turn.
  Set<int> get threatenedGoats =>
      game.turn == Side.goat && !isOver ? game.goatsUnderThreat() : const {};

  /// Goats a tiger could jump, whoever's turn it is; they look scared.
  Set<int> get goatsInDanger => isOver ? const {} : game.goatsUnderThreat();

  /// Tigers that could capture a goat, whoever's turn it is.
  Set<int> get huntingTigers {
    if (isOver) return const {};
    return {
      for (final p in game.pointsWith(Cell.tiger))
        if (Board.jumps[p]
            .any((j) => game.board[j.over] == Cell.goat && game.board[j.to] == Cell.empty))
          p,
    };
  }

  /// Tigers with no move at all.
  Set<int> get trappedTigers => {
        for (final p in game.pointsWith(Cell.tiger))
          if (game.tigerMobility(p) == 0) p,
      };

  /// Moves available to the selected piece.
  List<Move> get selectedMoves {
    final s = selected;
    if (s == null || !isHumanTurn) return const [];
    return game.movesFrom(s);
  }

  /// Points holding a piece the player to move can move.
  Set<int> get movablePieces {
    if (!isHumanTurn) return const {};
    if (game.turn == Side.goat && game.isPlacementPhase) return const {};
    return {for (final m in game.legalMoves()) m.from};
  }

  bool get canUndo {
    if (mode == GameMode.online) return false;
    if (mode == GameMode.twoPlayer) return history.isNotEmpty;
    // Only undo if the human has made a move to take back.
    return history.length >= (humanSide == Side.goat ? 1 : 2);
  }

  String sideLabel(Side side, String you, String computer, String Function(int) player) {
    if (mode == GameMode.twoPlayer) return player(side == Side.goat ? 1 : 2);
    if (side == humanSide) return you;
    return mode == GameMode.online ? opponentName ?? player(2) : computer;
  }

  void tapPoint(int point) {
    if (!isHumanTurn || thinking) return;
    hint = null;
    final cell = game.board[point];

    if (game.turn == Side.goat && game.isPlacementPhase) {
      if (cell == Cell.empty) {
        _play(Move.place(point));
      } else {
        onInvalidTap?.call(point);
        notifyListeners();
      }
      return;
    }

    final s = selected;
    if (s != null) {
      for (final m in game.movesFrom(s)) {
        if (m.to == point) {
          _play(m);
          return;
        }
      }
    }
    final own = game.turn == Side.goat ? Cell.goat : Cell.tiger;
    if (cell == own && game.movesFrom(point).isNotEmpty && point != s) {
      selected = point;
      onSelect?.call(point);
    } else if (point == s) {
      // Tapping the picked-up piece again puts it down.
      selected = null;
    } else {
      onInvalidTap?.call(point);
      // Keep the piece in hand after a miss on an empty point, so the player
      // can try another spot.
      if (cell != Cell.empty) selected = null;
    }
    notifyListeners();
  }

  /// Plays a move from the online room: the opponent's, or this player's
  /// own when catching up with the server. Returns false, and changes
  /// nothing, if the move is not legal here. [silent] skips the sound.
  bool applyRemoteMove(Move m, {bool silent = false}) {
    if (isOver || !game.legalMoves().contains(m)) return false;
    _play(m, remote: true, silent: silent);
    return true;
  }

  /// Ends the game early, e.g. when an online player leaves.
  void endGame(GameResult r) {
    if (isOver) return;
    _searchToken++;
    thinking = false;
    hinting = false;
    selected = null;
    hint = null;
    result = r;
    notifyListeners();
    onGameOver?.call(r);
  }

  void _play(Move m, {bool remote = false, bool silent = false}) {
    game.apply(m);
    history.add(m);
    _movePieces(m);
    selected = null;
    hint = null;

    final key = game.positionKey;
    final seen = (_seen[key] ?? 0) + 1;
    _seen[key] = seen;
    result = game.result ??
        (seen >= 3 ? const GameResult(Outcome.draw, OutcomeReason.repetition) : null);

    if (!silent) onMove?.call(m);
    if (mode == GameMode.online && !remote) onLocalMove?.call(m);
    notifyListeners();
    final r = result;
    if (r != null) {
      onGameOver?.call(r);
    } else {
      _maybeComputerTurn();
    }
  }

  Future<void> _maybeComputerTurn() async {
    if (!isComputerTurn) return;
    final token = ++_searchToken;
    thinking = true;
    notifyListeners();
    final started = DateTime.now();
    final move = await _findMoveFor(PuliMekaGame.copy(game), difficulty, Map.of(_seen));
    final wait = aiDelay - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (_disposed || token != _searchToken) return;
    thinking = false;
    _play(move);
  }

  bool get canHint => mode != GameMode.online;

  Future<void> showHint() async {
    if (!canHint || !isHumanTurn || thinking || hinting) return;
    final token = _searchToken;
    hinting = true;
    notifyListeners();
    final move = await _findMoveFor(PuliMekaGame.copy(game), Difficulty.hard, Map.of(_seen));
    if (_disposed) return;
    hinting = false;
    if (token == _searchToken && isHumanTurn) {
      hint = move;
      selected = move.isPlacement ? null : move.from;
    }
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _searchToken++; // Drop any search in progress.
    thinking = false;
    hinting = false;
    result = null;
    hint = null;
    selected = null;
    if (mode == GameMode.twoPlayer) {
      _undoOne();
    } else {
      // Take back moves until it is the human's turn again.
      do {
        _undoOne();
      } while (history.isNotEmpty && game.turn != humanSide);
    }
    notifyListeners();
    _maybeComputerTurn();
  }

  void _undoOne() {
    final m = history.removeLast();
    final key = game.positionKey;
    final seen = (_seen[key] ?? 1) - 1;
    if (seen <= 0) {
      _seen.remove(key);
    } else {
      _seen[key] = seen;
    }
    game.undo(m);
    if (m.isPlacement) {
      pieces.removeWhere((p) => p.point == m.to);
    } else {
      _pieceAt(m.to).point = m.from;
      if (m.isCapture) pieces.add(Piece(_nextPieceId++, false, m.captured));
    }
  }

  void _movePieces(Move m) {
    if (m.isPlacement) {
      pieces.add(Piece(_nextPieceId++, false, m.to));
      return;
    }
    if (m.isCapture) pieces.removeWhere((p) => p.point == m.captured);
    _pieceAt(m.from).point = m.to;
  }

  Piece _pieceAt(int point) => pieces.firstWhere((p) => p.point == point);

  @override
  void dispose() {
    _disposed = true;
    _searchToken++;
    super.dispose();
  }
}
