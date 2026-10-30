/// Computer opponent: alpha-beta search over the rules engine.
library;

import 'dart:math';

import 'board.dart';
import 'puli_meka.dart';

enum Difficulty { easy, medium, hard }

class PuliMekaAI {
  static const int _win = 100000;

  final Difficulty difficulty;
  final Random _rng;

  late Stopwatch _clock;
  late int _budgetMs;
  bool _outOfTime = false;
  int _nodes = 0;
  Map<String, int> _seen = const {};

  PuliMekaAI(this.difficulty, {Random? random}) : _rng = random ?? Random();

  /// Picks a move for the side to move in [game]. The game is left unchanged.
  ///
  /// [seen] counts how often each position has occurred so far, so the
  /// computer can steer away from repeating itself.
  Move chooseMove(PuliMekaGame game, {Map<String, int> seen = const {}}) {
    _seen = seen;
    final position = PuliMekaGame.copy(game);
    final moves = position.legalMoves();
    if (moves.isEmpty) throw StateError('No legal moves');
    if (moves.length == 1) return moves.first;

    switch (difficulty) {
      case Difficulty.easy:
        // A casual opponent: grabs captures, otherwise often plays at random.
        final captures = moves.where((m) => m.isCapture).toList();
        if (captures.isNotEmpty && _rng.nextDouble() < 0.7) {
          return captures[_rng.nextInt(captures.length)];
        }
        if (_rng.nextDouble() < 0.5) return moves[_rng.nextInt(moves.length)];
        return _search(position, maxDepth: 2, budgetMs: 200);
      case Difficulty.medium:
        return _search(position, maxDepth: 4, budgetMs: 600);
      case Difficulty.hard:
        return _search(position, maxDepth: 9, budgetMs: 1500);
    }
  }

  /// Iterative deepening; returns a random move among the best found by the
  /// deepest completed iteration.
  Move _search(PuliMekaGame game, {required int maxDepth, required int budgetMs}) {
    _clock = Stopwatch()..start();
    _budgetMs = budgetMs;
    _outOfTime = false;
    _nodes = 0;

    var moves = game.legalMoves()..shuffle(_rng);
    var best = <Move>[moves.first];

    for (var depth = 1; depth <= maxDepth; depth++) {
      final scored = <(Move, int)>[];
      var alpha = -_win * 2;
      for (final m in moves) {
        game.apply(m);
        // Search with a window that still separates moves within a few
        // points of the best, so ties can be broken randomly.
        final score = -_negamax(game, depth - 1, -_win * 2, -(alpha - 3), 1);
        game.undo(m);
        if (_outOfTime) break;
        scored.add((m, score));
        if (score > alpha) alpha = score;
      }
      if (_outOfTime) break;

      scored.sort((a, b) => b.$2.compareTo(a.$2));
      // Search the strongest moves first next iteration.
      moves = [for (final s in scored) s.$1];
      final top = scored.first.$2;
      if (top.abs() >= _win - 100) {
        // Forced win or loss found.
        best = [
          for (final s in scored)
            if (s.$2 == top) s.$1
        ];
        break;
      }
      // Unless it is losing, avoid going round in circles towards a draw.
      final adjusted =
          top < -150 ? scored : [for (final (m, v) in scored) (m, v - _repetitionPenalty(game, m))];
      final adjustedTop = adjusted.map((s) => s.$2).reduce(max);
      // Among moves the search rates about equal, prefer the ones that are
      // sound right now: take the goat, or keep every goat covered.
      final ranked = [
        for (final s in adjusted)
          if (s.$2 >= adjustedTop - _tieMargin) (s.$1, s.$2 + _immediateBonus(game, s.$1)),
      ];
      final bestRanked = ranked.map((r) => r.$2).reduce(max);
      best = [
        for (final r in ranked)
          if (r.$2 >= bestRanked - 2) r.$1
      ];
    }
    return best[_rng.nextInt(best.length)];
  }

  static const int _tieMargin = 40;

  int _repetitionPenalty(PuliMekaGame game, Move m) {
    if (_seen.isEmpty || m.isPlacement) return 0;
    game.apply(m);
    final count = _seen[game.positionKey] ?? 0;
    game.undo(m);
    return count * 60;
  }

  int _immediateBonus(PuliMekaGame game, Move m) {
    if (game.turn == Side.tiger) return m.isCapture ? _tieMargin : 0;
    game.apply(m);
    final safe = game.goatsUnderThreat().isEmpty;
    game.undo(m);
    return safe ? _tieMargin : 0;
  }

  int _negamax(PuliMekaGame game, int depth, int alpha, int beta, int ply) {
    if ((++_nodes & 1023) == 0 && _clock.elapsedMilliseconds > _budgetMs) {
      _outOfTime = true;
      return 0;
    }
    final sign = game.turn == Side.tiger ? 1 : -1;
    if (game.goatsCaptured >= game.captureTarget) {
      return sign * (_win - ply);
    }
    final moves = game.legalMoves();
    if (moves.isEmpty) return -(_win - ply);
    if (depth <= 0) return sign * evaluate(game);

    var best = -_win * 2;
    for (final m in moves) {
      game.apply(m);
      final score = -_negamax(game, depth - 1, -beta, -alpha, ply + 1);
      game.undo(m);
      if (_outOfTime) return 0;
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Static score from the tigers' point of view.
  static int evaluate(PuliMekaGame game) {
    final board = game.board;
    var score = game.goatsCaptured * 400;

    var mobility = 0;
    var trapped = 0;
    final threatened = <int>{};
    for (var p = 0; p < board.length; p++) {
      if (board[p] != Cell.tiger) continue;
      var m = 0;
      for (final n in Board.neighbours[p]) {
        if (board[n] == Cell.empty) m++;
      }
      for (final j in Board.jumps[p]) {
        if (board[j.over] == Cell.goat && board[j.to] == Cell.empty) {
          m++;
          threatened.add(j.over);
        }
      }
      mobility += m;
      if (m == 0) trapped++;
      // Central points with many lines are strong posts for a tiger.
      score += Board.neighbours[p].length * 2;
    }

    score += mobility * 12;
    score -= trapped * 90;
    score += threatened.length * 60;
    // An open capture on the tigers' turn is almost a goat in the bag, and
    // two threats at once usually cannot both be covered.
    if (game.turn == Side.tiger && threatened.isNotEmpty) {
      score += 300;
    } else if (threatened.length >= 2) {
      score += 200;
    }
    // Goats still in hand keep the goat side flexible.
    score -= game.goatsInHand * 4;
    return score;
  }
}
