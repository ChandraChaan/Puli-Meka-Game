/// Online rooms stored in Cloud Firestore. See firestore.rules for what the
/// server allows.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/puli_meka.dart';
import 'backend.dart';
import 'room.dart';

class FirestoreBackend implements OnlineBackend {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreBackend({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Rooms nobody has touched for this long can be deleted by a TTL policy
  /// on `expireAt`.
  static const _roomLifetime = Duration(days: 2);

  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('rooms');

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw const OnlineError(OnlineErrorKind.unknown, 'not signed in');
    return u.uid;
  }

  Timestamp get _expiry => Timestamp.fromDate(DateTime.now().add(_roomLifetime));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } on OnlineError {
      rethrow;
    } on TimeoutException catch (e) {
      throw OnlineError(OnlineErrorKind.offline, e);
    } on FirebaseException catch (e) {
      throw OnlineError(
        switch (e.code) {
          'unavailable' || 'network-request-failed' || 'deadline-exceeded' =>
            OnlineErrorKind.offline,
          'not-found' => OnlineErrorKind.notFound,
          _ => OnlineErrorKind.unknown,
        },
        e,
      );
    }
  }

  @override
  Future<String> signIn() => _guard(() async {
        final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
        if (user == null) throw const OnlineError(OnlineErrorKind.unknown, 'sign-in failed');
        return user.uid;
      });

  @override
  Future<Room> createRoom({
    required String name,
    required Side side,
    required int captureTarget,
    required bool isPublic,
  }) =>
      _guard(() async {
        final uid = _uid;
        // A clash between two random codes is very unlikely; try a few.
        for (var attempt = 0; attempt < 5; attempt++) {
          final code = RoomCode.generate();
          final ref = _rooms.doc(code);
          final created = await _db.runTransaction((tx) async {
            if ((await tx.get(ref)).exists) return false;
            tx.set(ref, {
              'code': code,
              'hostUid': uid,
              'hostName': name,
              'hostSide': side.name,
              'guestUid': null,
              'guestName': null,
              'goatUid': null,
              'tigerUid': null,
              'captureTarget': captureTarget,
              'moves': <String>[],
              'status': RoomStatus.waiting.name,
              'isPublic': isPublic,
              'round': 0,
              'rematch': <String>[],
              'lastSeen': {uid: FieldValue.serverTimestamp()},
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'expireAt': _expiry,
            });
            return true;
          });
          if (created) {
            return Room(
              code: code,
              hostUid: uid,
              hostName: name,
              hostSide: side,
              captureTarget: captureTarget,
              isPublic: isPublic,
            );
          }
        }
        throw const OnlineError(OnlineErrorKind.unknown, 'no free room code');
      });

  @override
  Future<Room> joinRoom(String code, String name) => _guard(() async {
        final uid = _uid;
        final ref = _rooms.doc(code);
        return _db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          final data = snap.data();
          if (data == null) throw const OnlineError(OnlineErrorKind.notFound);
          final room = _parse(data);
          if (room.hostUid == uid) {
            // Coming back to our own room, e.g. after the app restarted.
            if (room.isFull || room.status == RoomStatus.waiting) return room;
            throw const OnlineError(OnlineErrorKind.ownRoom);
          }
          if (room.guestUid == uid) return room;
          if (room.isFull || room.status != RoomStatus.waiting) {
            throw const OnlineError(OnlineErrorKind.full);
          }
          final hostIsGoat = room.hostSide == Side.goat;
          final goatUid = hostIsGoat ? room.hostUid : uid;
          final tigerUid = hostIsGoat ? uid : room.hostUid;
          tx.update(ref, {
            'guestUid': uid,
            'guestName': name,
            'goatUid': goatUid,
            'tigerUid': tigerUid,
            'status': RoomStatus.playing.name,
            'lastSeen.$uid': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'expireAt': _expiry,
          });
          return room.copyWith(
            guestUid: uid,
            guestName: name,
            goatUid: goatUid,
            tigerUid: tigerUid,
            status: RoomStatus.playing,
          );
        });
      });

  @override
  Future<List<Room>> openPublicRooms() => _guard(() async {
        final uid = _uid;
        final snap = await _rooms
            .where('isPublic', isEqualTo: true)
            .where('status', isEqualTo: RoomStatus.waiting.name)
            .limit(20)
            .get();
        final now = DateTime.now();
        return [
          for (final doc in snap.docs)
            if (_parse(doc.data()) case final room
                when room.hostUid != uid &&
                    // Skip rooms whose host has gone quiet.
                    now.difference(room.lastSeen[room.hostUid] ?? DateTime(2000)) <
                        const Duration(seconds: 45))
              room,
        ];
      });

  @override
  Stream<Room?> watchRoom(String code) => _rooms.doc(code).snapshots().map((snap) {
        // A heartbeat still on its way to the server reads as null; the
        // parser skips it.
        final data = snap.data();
        return data == null ? null : _parse(data);
      });

  @override
  Future<void> sendMoves(String code, List<String> moves, {RoomStatus? status}) =>
      _guard(() => _rooms.doc(code).update({
            'moves': moves,
            if (status != null) 'status': status.name,
            'lastSeen.$_uid': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'expireAt': _expiry,
          }));

  @override
  Future<void> heartbeat(String code) => _guard(() => _rooms.doc(code).update({
        'lastSeen.$_uid': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expireAt': _expiry,
      }));

  @override
  Future<void> leave(String code) => _guard(() async {
        final uid = _uid;
        final ref = _rooms.doc(code);
        await _db.runTransaction((tx) async {
          final data = (await tx.get(ref)).data();
          if (data == null) return;
          final room = _parse(data);
          if (room.status == RoomStatus.waiting) {
            if (room.hostUid == uid) tx.delete(ref);
          } else if (room.status == RoomStatus.playing) {
            tx.update(ref, {
              'status': RoomStatus.abandoned.name,
              'leftBy': uid,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
      });

  @override
  Future<void> markAbandoned(String code, String uid) => _guard(() => _rooms.doc(code).update({
        'status': RoomStatus.abandoned.name,
        'leftBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }));

  @override
  Future<void> requestRematch(String code) => _guard(() async {
        final uid = _uid;
        final ref = _rooms.doc(code);
        await _db.runTransaction((tx) async {
          final data = (await tx.get(ref)).data();
          if (data == null) throw const OnlineError(OnlineErrorKind.notFound);
          final room = _parse(data);
          if (room.status == RoomStatus.playing) return;
          final asked = {...room.rematch, uid};
          if (asked.contains(room.hostUid) && asked.contains(room.guestUid)) {
            tx.update(ref, {
              'moves': <String>[],
              'status': RoomStatus.playing.name,
              'round': room.round + 1,
              'goatUid': room.tigerUid,
              'tigerUid': room.goatUid,
              'rematch': <String>[],
              'leftBy': null,
              'updatedAt': FieldValue.serverTimestamp(),
              'expireAt': _expiry,
            });
          } else {
            tx.update(ref, {
              'rematch': asked.toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
      });

  static Room _parse(Map<String, dynamic> d) {
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    final seen = <String, DateTime>{};
    final rawSeen = d['lastSeen'];
    if (rawSeen is Map) {
      for (final e in rawSeen.entries) {
        final t = time(e.value);
        if (t != null) seen[e.key as String] = t;
      }
    }
    return Room(
      code: d['code'] as String,
      hostUid: d['hostUid'] as String,
      hostName: d['hostName'] as String? ?? '?',
      hostSide: d['hostSide'] == 'tiger' ? Side.tiger : Side.goat,
      guestUid: d['guestUid'] as String?,
      guestName: d['guestName'] as String?,
      goatUid: d['goatUid'] as String?,
      tigerUid: d['tigerUid'] as String?,
      captureTarget: (d['captureTarget'] as num?)?.toInt() ?? PuliMekaGame.defaultCaptureTarget,
      moves: [for (final m in (d['moves'] as List? ?? const [])) m as String],
      status: RoomStatus.values.asNameMap()[d['status']] ?? RoomStatus.waiting,
      isPublic: d['isPublic'] as bool? ?? false,
      round: (d['round'] as num?)?.toInt() ?? 0,
      leftBy: d['leftBy'] as String?,
      rematch: {for (final u in (d['rematch'] as List? ?? const [])) u as String},
      lastSeen: seen,
    );
  }
}
