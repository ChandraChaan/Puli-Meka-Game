/// An online game room, shared by two players, and how moves are written
/// into it.
library;

import 'dart:math' as math;

import '../game/puli_meka.dart';

enum RoomStatus { waiting, playing, over, abandoned }

/// Moves are stored as short strings: `p12` places a goat on point 12,
/// `3-7` steps from 3 to 7, and `3x5-7` jumps from 3 over 5 to 7.
class MoveCodec {
  MoveCodec._();

  static String encode(Move m) {
    if (m.isPlacement) return 'p${m.to}';
    if (m.isCapture) return '${m.from}x${m.captured}-${m.to}';
    return '${m.from}-${m.to}';
  }

  static final _place = RegExp(r'^p(\d{1,2})$');
  static final _step = RegExp(r'^(\d{1,2})-(\d{1,2})$');
  static final _jump = RegExp(r'^(\d{1,2})x(\d{1,2})-(\d{1,2})$');

  /// The move written as [s], or null if it is not a well-formed move.
  static Move? decode(String s) {
    var m = _place.firstMatch(s);
    if (m != null) return Move.place(int.parse(m[1]!));
    m = _step.firstMatch(s);
    if (m != null) return Move.step(int.parse(m[1]!), int.parse(m[2]!));
    m = _jump.firstMatch(s);
    if (m != null) return Move.jump(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    return null;
  }
}

/// Room codes avoid letters and digits that are easy to mix up (0/O, 1/I).
class RoomCode {
  RoomCode._();
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 6;

  static String generate([math.Random? random]) {
    final r = random ?? math.Random.secure();
    return String.fromCharCodes(
      List.generate(length, (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length))),
    );
  }

  /// Tidies what a player typed: upper case, without spaces or dashes.
  static String normalise(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValid(String code) =>
      code.length == length && code.split('').every(alphabet.contains);
}

class Room {
  final String code;
  final String hostUid;
  final String hostName;
  final Side hostSide;
  final String? guestUid;
  final String? guestName;
  final String? goatUid;
  final String? tigerUid;
  final int captureTarget;
  final List<String> moves;
  final RoomStatus status;
  final bool isPublic;

  /// Counts rematches; the board is cleared and sides swap each round.
  final int round;

  /// The player who left or resigned, when [status] is abandoned.
  final String? leftBy;

  /// Players asking for a rematch.
  final Set<String> rematch;

  /// When each player was last heard from, to notice a lost connection.
  final Map<String, DateTime> lastSeen;

  const Room({
    required this.code,
    required this.hostUid,
    required this.hostName,
    required this.hostSide,
    this.guestUid,
    this.guestName,
    this.goatUid,
    this.tigerUid,
    required this.captureTarget,
    this.moves = const [],
    this.status = RoomStatus.waiting,
    this.isPublic = false,
    this.round = 0,
    this.leftBy,
    this.rematch = const {},
    this.lastSeen = const {},
  });

  bool get isFull => guestUid != null;

  /// The side [uid] plays this round, or null if they are not in the room.
  Side? sideOf(String uid) {
    if (uid == goatUid) return Side.goat;
    if (uid == tigerUid) return Side.tiger;
    if (!isFull && uid == hostUid) return hostSide;
    return null;
  }

  /// The other player's uid, from [uid]'s point of view.
  String? opponentOf(String uid) => uid == hostUid ? guestUid : hostUid;

  String? nameOf(String? uid) {
    if (uid == null) return null;
    if (uid == hostUid) return hostName;
    if (uid == guestUid) return guestName;
    return null;
  }

  Room copyWith({
    String? guestUid,
    String? guestName,
    String? goatUid,
    String? tigerUid,
    List<String>? moves,
    RoomStatus? status,
    int? round,
    String? leftBy,
    bool clearLeftBy = false,
    Set<String>? rematch,
    Map<String, DateTime>? lastSeen,
  }) =>
      Room(
        code: code,
        hostUid: hostUid,
        hostName: hostName,
        hostSide: hostSide,
        guestUid: guestUid ?? this.guestUid,
        guestName: guestName ?? this.guestName,
        goatUid: goatUid ?? this.goatUid,
        tigerUid: tigerUid ?? this.tigerUid,
        captureTarget: captureTarget,
        moves: moves ?? this.moves,
        status: status ?? this.status,
        isPublic: isPublic,
        round: round ?? this.round,
        leftBy: clearLeftBy ? null : leftBy ?? this.leftBy,
        rematch: rematch ?? this.rematch,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
