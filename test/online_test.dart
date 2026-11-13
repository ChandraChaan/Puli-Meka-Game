import 'package:flutter_test/flutter_test.dart';
import 'package:puli_meka/game/board.dart';
import 'package:puli_meka/game/puli_meka.dart';
import 'package:puli_meka/online/backend.dart';
import 'package:puli_meka/online/online_session.dart';
import 'package:puli_meka/online/room.dart';

import 'fake_backend.dart';

/// Two players, each with their own session, in one room.
Future<(OnlineSession, OnlineSession, FakeBackend, FakeBackend)> _pair({
  Side hostSide = Side.goat,
  int captureTarget = 5,
  Duration awayAfter = const Duration(seconds: 30),
  Duration claimAfter = const Duration(seconds: 90),
}) async {
  final server = FakeServer();
  final hostBackend = FakeBackend(server, 'host');
  final guestBackend = FakeBackend(server, 'guest');
  final room = await hostBackend.createRoom(
    name: 'Asha',
    side: hostSide,
    captureTarget: captureTarget,
    isPublic: false,
  );
  final host = OnlineSession(
    backend: hostBackend,
    uid: 'host',
    awayAfter: awayAfter,
    claimAfter: claimAfter,
  )..attach(room);
  final joined = await guestBackend.joinRoom(room.code, 'Ravi');
  final guest = OnlineSession(
    backend: guestBackend,
    uid: 'guest',
    awayAfter: awayAfter,
    claimAfter: claimAfter,
  )..attach(joined);
  await pumpEventQueue();
  return (host, guest, hostBackend, guestBackend);
}

void main() {
  group('MoveCodec', () {
    test('round-trips every kind of move', () {
      final game = PuliMekaGame();
      final moves = <Move>[
        ...game.legalMoves(),
        const Move.step(3, 9),
        const Move.jump(3, 9, 15),
        const Move.jump(22, 21, 20),
      ];
      for (final m in moves) {
        expect(MoveCodec.decode(MoveCodec.encode(m)), m, reason: '$m');
      }
    });

    test('rejects nonsense', () {
      for (final s in ['', 'p', 'x', '3-', '3x-4', 'p123', '1-2-3', 'hello']) {
        expect(MoveCodec.decode(s), isNull, reason: s);
      }
    });
  });

  group('RoomCode', () {
    test('codes are six unambiguous characters', () {
      for (var i = 0; i < 200; i++) {
        final c = RoomCode.generate();
        expect(RoomCode.isValid(c), isTrue, reason: c);
        expect(c, isNot(matches(RegExp('[01OI]'))));
      }
    });

    test('tidies what players type', () {
      expect(RoomCode.normalise(' ab-c 2x9 '), 'ABC2X9');
      expect(RoomCode.isValid('ABC2X9'), isTrue);
      expect(RoomCode.isValid('ABC0X9'), isFalse);
      expect(RoomCode.isValid('ABC2X'), isFalse);
    });
  });

  group('OnlineSession', () {
    test('both players get a board with opposite sides and names', () async {
      final (host, guest, _, _) = await _pair(hostSide: Side.tiger);
      expect(host.controller!.humanSide, Side.tiger);
      expect(guest.controller!.humanSide, Side.goat);
      expect(host.controller!.opponentName, 'Ravi');
      expect(guest.controller!.opponentName, 'Asha');
      // Goats move first, so only the guest can play.
      expect(guest.controller!.isHumanTurn, isTrue);
      expect(host.controller!.isHumanTurn, isFalse);
    });

    test('moves travel both ways and turns alternate', () async {
      final (host, guest, _, _) = await _pair();
      final goats = host.controller!;
      final tigers = guest.controller!;

      tigers.tapPoint(20); // Not the tigers' turn: nothing happens.
      expect(tigers.history, isEmpty);

      goats.tapPoint(20);
      await pumpEventQueue();
      expect(tigers.game.board[20], Cell.goat);
      expect(tigers.isHumanTurn, isTrue);
      expect(goats.isHumanTurn, isFalse);

      tigers.tapPoint(0);
      tigers.tapPoint(2);
      await pumpEventQueue();
      expect(goats.game.board[2], Cell.tiger);
      expect(goats.history, hasLength(2));
      expect(host.room!.moves, ['p20', '0-2']);
    });

    test('a capture to the target ends the game for both', () async {
      final (host, guest, _, _) = await _pair(captureTarget: 4);
      final goats = host.controller!;
      final tigers = guest.controller!;
      for (var i = 0; i < 60 && !goats.isOver; i++) {
        final g = goats.game;
        if (g.turn == Side.goat) {
          // Put goats where a tiger can jump them.
          int? bait;
          for (final t in g.pointsWith(Cell.tiger)) {
            for (final j in Board.jumps[t]) {
              if (g.board[j.over] == Cell.empty && g.board[j.to] == Cell.empty) bait ??= j.over;
            }
          }
          final m = bait != null
              ? Move.place(bait)
              : g.legalMoves().first;
          if (m.isPlacement) {
            goats.tapPoint(m.to);
          } else {
            goats.tapPoint(m.from);
            goats.tapPoint(m.to);
          }
        } else {
          final m = tigers.game.tigerMoves().first;
          tigers.tapPoint(m.from);
          tigers.tapPoint(m.to);
        }
        await pumpEventQueue();
      }
      expect(goats.result?.outcome, Outcome.tigersWin);
      expect(tigers.result?.outcome, Outcome.tigersWin);
      expect(host.room!.status, RoomStatus.over);
      expect(host.canRematch, isTrue);
    });

    test('a rematch clears the board and swaps sides', () async {
      final (host, guest, hostBackend, _) = await _pair();
      // Skip to a finished game.
      hostBackend.server.put(
        host.code,
        host.room!.copyWith(status: RoomStatus.over),
      );
      await pumpEventQueue();

      await host.requestRematch();
      await pumpEventQueue();
      expect(host.iAskedRematch, isTrue);
      expect(guest.opponentAskedRematch, isTrue);
      expect(host.controller!.humanSide, Side.goat);

      await guest.requestRematch();
      await pumpEventQueue();
      expect(host.room!.round, 1);
      expect(host.controller!.humanSide, Side.tiger);
      expect(guest.controller!.humanSide, Side.goat);
      expect(host.controller!.history, isEmpty);
      expect(host.controller!.isOver, isFalse);
    });

    test('resigning gives the other player the win', () async {
      final (host, guest, _, _) = await _pair();
      await guest.leave();
      await pumpEventQueue();
      final r = host.controller!.result!;
      expect(r.reason, OutcomeReason.forfeit);
      expect(r.winner, Side.goat); // The host plays goats.
      expect(guest.controller!.result!.winner, Side.goat);
      expect(host.canRematch, isFalse);
    });

    test('a silent opponent is shown as away and the win can be claimed', () async {
      final (host, guest, _, _) = await _pair(
        awayAfter: const Duration(milliseconds: 40),
        claimAfter: const Duration(milliseconds: 80),
      );
      expect(host.opponentAway, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(host.opponentAway, isTrue);
      expect(host.canClaimWin, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(host.canClaimWin, isTrue);
      await host.claimWin();
      await pumpEventQueue();
      expect(host.controller!.result!.winner, Side.goat);
      expect(guest.controller!.result!.winner, Side.goat);
    });

    test('a move the server refuses is taken back', () async {
      final (host, _, hostBackend, _) = await _pair();
      hostBackend.offline = true;
      host.controller!.tapPoint(20);
      await pumpEventQueue();
      expect(host.error?.kind, OnlineErrorKind.offline);
      expect(host.controller!.history, isEmpty);
      expect(host.controller!.isHumanTurn, isTrue);
    });

    test('the room being deleted closes the session', () async {
      final server = FakeServer();
      final b = FakeBackend(server, 'host');
      final room = await b.createRoom(
        name: 'Asha',
        side: Side.goat,
        captureTarget: 5,
        isPublic: false,
      );
      final s = OnlineSession(backend: b, uid: 'host')..attach(room);
      await pumpEventQueue();
      expect(s.controller, isNull);
      await s.leave();
      await pumpEventQueue();
      expect(s.closed, isTrue);
    });
  });
}
