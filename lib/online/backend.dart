/// What online play needs from a server. The app uses Firestore; tests use
/// an in-memory fake.
library;

import '../game/puli_meka.dart';
import 'room.dart';

enum OnlineErrorKind { offline, notFound, full, ownRoom, unavailable, unknown }

class OnlineError implements Exception {
  final OnlineErrorKind kind;
  final Object? cause;
  const OnlineError(this.kind, [this.cause]);

  @override
  String toString() => 'OnlineError($kind${cause == null ? '' : ': $cause'})';
}

abstract class OnlineBackend {
  /// Signs in (anonymously) if needed and returns this player's id.
  Future<String> signIn();

  Future<Room> createRoom({
    required String name,
    required Side side,
    required int captureTarget,
    required bool isPublic,
  });

  /// Takes the empty seat in room [code].
  Future<Room> joinRoom(String code, String name);

  /// Public rooms waiting for a player, other than this player's own.
  Future<List<Room>> openPublicRooms();

  Stream<Room?> watchRoom(String code);

  /// Writes the moves played so far; the server accepts one new move at a
  /// time from the side to move. [status] ends the game with this move.
  Future<void> sendMoves(String code, List<String> moves, {RoomStatus? status});

  /// Tells the other player this one is still here.
  Future<void> heartbeat(String code);

  /// Cancels a waiting room, or resigns a game in progress.
  Future<void> leave(String code);

  /// Ends the game because [uid] has gone (left or lost connection).
  Future<void> markAbandoned(String code, String uid);

  /// Asks for another game. When both players have asked, the board is
  /// cleared and they swap sides.
  Future<void> requestRematch(String code);
}
