import 'dart:async';

import 'package:puli_meka/game/puli_meka.dart';
import 'package:puli_meka/online/backend.dart';
import 'package:puli_meka/online/room.dart';

/// An in-memory stand-in for Firestore, shared by several fake players.
/// It applies the same checks as firestore.rules for moves.
class FakeServer {
  final Map<String, Room> rooms = {};
  final Map<String, StreamController<Room?>> _streams = {};
  int _codes = 0;

  /// Moments at which each player was last heard from.
  final Map<String, DateTime> clock = {};

  String nextCode() => 'ROOM${(_codes++).toString().padLeft(2, '0')}';

  void put(String code, Room? room) {
    if (room == null) {
      rooms.remove(code);
    } else {
      rooms[code] = room;
    }
    // Deliver asynchronously, like a real snapshot listener.
    scheduleMicrotask(() => _streams[code]?.add(room));
  }

  Stream<Room?> watch(String code) {
    final c = _streams.putIfAbsent(code, () => StreamController<Room?>.broadcast());
    scheduleMicrotask(() => c.add(rooms[code]));
    return c.stream;
  }
}

class FakeBackend implements OnlineBackend {
  final FakeServer server;
  final String uid;
  bool offline = false;

  FakeBackend(this.server, this.uid);

  void _check() {
    if (offline) throw const OnlineError(OnlineErrorKind.offline);
  }

  Room _room(String code) {
    final r = server.rooms[code];
    if (r == null) throw const OnlineError(OnlineErrorKind.notFound);
    return r;
  }

  Map<String, DateTime> _seen(Room r) => {...r.lastSeen, uid: DateTime.now()};

  @override
  Future<String> signIn() async {
    _check();
    return uid;
  }

  @override
  Future<Room> createRoom({
    required String name,
    required Side side,
    required int captureTarget,
    required bool isPublic,
  }) async {
    _check();
    final room = Room(
      code: server.nextCode(),
      hostUid: uid,
      hostName: name,
      hostSide: side,
      captureTarget: captureTarget,
      isPublic: isPublic,
      lastSeen: {uid: DateTime.now()},
    );
    server.put(room.code, room);
    return room;
  }

  @override
  Future<Room> joinRoom(String code, String name) async {
    _check();
    final r = _room(code);
    if (r.hostUid == uid) throw const OnlineError(OnlineErrorKind.ownRoom);
    if (r.isFull) throw const OnlineError(OnlineErrorKind.full);
    final hostIsGoat = r.hostSide == Side.goat;
    final joined = r.copyWith(
      guestUid: uid,
      guestName: name,
      goatUid: hostIsGoat ? r.hostUid : uid,
      tigerUid: hostIsGoat ? uid : r.hostUid,
      status: RoomStatus.playing,
      lastSeen: _seen(r),
    );
    server.put(code, joined);
    return joined;
  }

  @override
  Future<List<Room>> openPublicRooms() async {
    _check();
    return [
      for (final r in server.rooms.values)
        if (r.isPublic && r.status == RoomStatus.waiting && r.hostUid != uid) r,
    ];
  }

  @override
  Stream<Room?> watchRoom(String code) => server.watch(code);

  @override
  Future<void> sendMoves(String code, List<String> moves, {RoomStatus? status}) async {
    _check();
    final r = _room(code);
    final before = r.moves;
    final ok = r.status == RoomStatus.playing &&
        moves.length == before.length + 1 &&
        Iterable<int>.generate(before.length).every((i) => moves[i] == before[i]) &&
        uid == (before.length.isEven ? r.goatUid : r.tigerUid);
    if (!ok) throw const OnlineError(OnlineErrorKind.unknown, 'permission-denied');
    server.put(code, r.copyWith(moves: moves, status: status, lastSeen: _seen(r)));
  }

  @override
  Future<void> heartbeat(String code) async {
    _check();
    final r = _room(code);
    server.put(code, r.copyWith(lastSeen: _seen(r)));
  }

  @override
  Future<void> leave(String code) async {
    _check();
    final r = server.rooms[code];
    if (r == null) return;
    if (r.status == RoomStatus.waiting) {
      if (r.hostUid == uid) server.put(code, null);
    } else if (r.status == RoomStatus.playing) {
      server.put(code, r.copyWith(status: RoomStatus.abandoned, leftBy: uid));
    }
  }

  @override
  Future<void> markAbandoned(String code, String who) async {
    _check();
    server.put(code, _room(code).copyWith(status: RoomStatus.abandoned, leftBy: who));
  }

  @override
  Future<void> requestRematch(String code) async {
    _check();
    final r = _room(code);
    final asked = {...r.rematch, uid};
    if (asked.contains(r.hostUid) && asked.contains(r.guestUid)) {
      server.put(
        code,
        Room(
          code: r.code,
          hostUid: r.hostUid,
          hostName: r.hostName,
          hostSide: r.hostSide,
          guestUid: r.guestUid,
          guestName: r.guestName,
          goatUid: r.tigerUid,
          tigerUid: r.goatUid,
          captureTarget: r.captureTarget,
          status: RoomStatus.playing,
          isPublic: r.isPublic,
          round: r.round + 1,
          lastSeen: r.lastSeen,
        ),
      );
    } else {
      server.put(code, r.copyWith(rematch: asked));
    }
  }
}
