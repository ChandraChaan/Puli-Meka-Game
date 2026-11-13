/// Keeps one online room and the local game in step.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/game_controller.dart';
import '../game/puli_meka.dart';
import 'backend.dart';
import 'room.dart';

class OnlineSession extends ChangeNotifier {
  final OnlineBackend backend;
  final String uid;

  /// How often this player says it is still here.
  final Duration heartbeatEvery;

  /// Silence after which the opponent is shown as disconnected.
  final Duration awayAfter;

  /// Further silence after which this player may claim the win.
  final Duration claimAfter;

  Room? room;

  /// The game on this phone; created once the second player arrives.
  GameController? controller;

  /// The latest problem talking to the server, if any.
  OnlineError? error;

  /// True when the room was deleted, e.g. the host cancelled it.
  bool closed = false;

  StreamSubscription<Room?>? _sub;
  Timer? _heartbeat;
  Timer? _watchdog;
  DateTime? _opponentSeenValue;
  DateTime _opponentHeardAt = DateTime.now();
  bool _disposed = false;

  OnlineSession({
    required this.backend,
    required this.uid,
    this.heartbeatEvery = const Duration(seconds: 10),
    this.awayAfter = const Duration(seconds: 30),
    this.claimAfter = const Duration(seconds: 90),
  });

  String get code => room!.code;
  Side? get mySide => room?.sideOf(uid);
  String? get opponentUid => room?.opponentOf(uid);
  String? get opponentName => room?.nameOf(opponentUid);
  bool get isPlaying => room?.status == RoomStatus.playing;
  bool get hasOpponent => room?.isFull ?? false;

  /// The opponent has been silent too long while the game is on.
  bool get opponentAway =>
      isPlaying && DateTime.now().difference(_opponentHeardAt) > awayAfter;

  bool get canClaimWin =>
      isPlaying && DateTime.now().difference(_opponentHeardAt) > claimAfter;

  bool get iAskedRematch => room?.rematch.contains(uid) ?? false;
  bool get opponentAskedRematch => room?.rematch.contains(opponentUid) ?? false;

  /// A rematch is offered after a game played to the end; not after
  /// someone left.
  bool get canRematch => room?.status == RoomStatus.over;

  void attach(Room initial) {
    room = initial;
    _sub?.cancel();
    _sub = backend.watchRoom(initial.code).listen(_onRoom, onError: (Object e) {
      _setError(e);
    });
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatEvery, (_) => _beat());
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isPlaying) _notify();
    });
    _onRoom(initial);
  }

  Future<void> _beat() async {
    final r = room;
    if (r == null || closed || r.status == RoomStatus.abandoned) return;
    try {
      await backend.heartbeat(r.code);
    } catch (_) {
      // A missed heartbeat is harmless; the next one will try again.
    }
  }

  void _onRoom(Room? r) {
    if (_disposed) return;
    if (r == null) {
      closed = true;
      _notify();
      return;
    }
    room = r;

    final opp = r.opponentOf(uid);
    final seen = opp == null ? null : r.lastSeen[opp];
    if (seen != null && seen != _opponentSeenValue) {
      _opponentSeenValue = seen;
      _opponentHeardAt = DateTime.now();
    }

    if (r.isFull && r.status != RoomStatus.waiting) _syncGame(r);
    _notify();
  }

  void _syncGame(Room r) {
    final side = r.sideOf(uid);
    if (side == null) return;
    var c = controller;
    if (c == null) {
      c = controller = GameController(
        mode: GameMode.online,
        humanSide: side,
        captureTarget: r.captureTarget,
      )..onLocalMove = _sendMove;
      _round = r.round;
      _opponentHeardAt = DateTime.now();
    }
    c.opponentName = r.nameOf(r.opponentOf(uid));

    if (r.round != _round) {
      // A rematch: fresh board, swapped sides.
      _round = r.round;
      _opponentHeardAt = DateTime.now();
      c.restart(side: side);
    }

    // The server is the record. If our own move was refused, start over from
    // what the server holds.
    final local = [for (final m in c.history) MoveCodec.encode(m)];
    final matches = local.length <= r.moves.length &&
        Iterable<int>.generate(local.length).every((i) => local[i] == r.moves[i]);
    if (!matches) {
      c.restart(side: side);
    }
    for (var i = c.history.length; i < r.moves.length; i++) {
      final m = MoveCodec.decode(r.moves[i]);
      // When catching up on several moves, only the last one makes a sound.
      if (m == null || !c.applyRemoteMove(m, silent: i < r.moves.length - 1)) {
        error = OnlineError(OnlineErrorKind.unknown, 'bad move ${r.moves[i]}');
        break;
      }
    }

    if (r.status == RoomStatus.abandoned && !c.isOver) {
      final winner = r.leftBy == uid ? side.opponent : side;
      c.endGame(GameResult(
        winner == Side.tiger ? Outcome.tigersWin : Outcome.goatsWin,
        OutcomeReason.forfeit,
      ));
    }
  }

  int _round = 0;

  Future<void> _sendMove(Move m) async {
    final c = controller;
    final r = room;
    if (c == null || r == null) return;
    final moves = [for (final mv in c.history) MoveCodec.encode(mv)];
    try {
      await backend.sendMoves(r.code, moves, status: c.isOver ? RoomStatus.over : null);
      error = null;
    } catch (e) {
      _setError(e);
      // Show the board as the server has it.
      if (room != null) _syncGame(room!);
    }
    _notify();
  }

  /// Resigns a game in progress, or cancels a room nobody has joined.
  Future<void> leave() async {
    final r = room;
    if (r == null || closed) return;
    if (r.status == RoomStatus.over || r.status == RoomStatus.abandoned) return;
    try {
      await backend.leave(r.code);
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> claimWin() async {
    final opp = opponentUid;
    if (!canClaimWin || opp == null) return;
    try {
      await backend.markAbandoned(code, opp);
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> requestRematch() async {
    try {
      await backend.requestRematch(code);
    } catch (e) {
      _setError(e);
    }
  }

  void _setError(Object e) {
    debugPrint('Online error: $e');
    error = e is OnlineError ? e : OnlineError(OnlineErrorKind.unknown, e);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Stops listening. The controller belongs to the game screen, which
  /// disposes it.
  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _heartbeat?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }
}
