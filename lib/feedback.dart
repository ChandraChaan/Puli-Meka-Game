/// Sound effects and vibration for game events.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

enum GameSound { select, place, move, capture, invalid, win, lose, draw }

/// One vibration: a pattern for phones with a real vibration motor
/// (Android), and timed taps for the Taptic Engine (iOS).
class _Buzz {
  /// Alternating wait/vibrate durations in milliseconds, starting with a wait.
  final List<int> pattern;

  /// Strength (1–255) of each entry in [pattern]; waits use 0.
  final List<int> intensities;

  /// iOS taps as (delay in ms from start, strength 0 light … 2 heavy).
  final List<(int, int)> taps;

  const _Buzz(this.pattern, this.intensities, this.taps);
}

const _buzzes = {
  GameSound.select: _Buzz([0, 12], [0, 90], [(0, 0)]),
  GameSound.place: _Buzz([0, 22], [0, 160], [(0, 1)]),
  GameSound.move: _Buzz([0, 10, 90, 22], [0, 70, 0, 160], [(0, 0), (100, 1)]),
  // Lift-off, the heavy landing as the goat is taken, then a small aftershock.
  GameSound.capture: _Buzz(
    [0, 14, 210, 70, 70, 35],
    [0, 80, 0, 255, 0, 140],
    [(0, 0), (225, 2), (360, 1)],
  ),
  GameSound.invalid: _Buzz([0, 18, 60, 18], [0, 110, 0, 110], [(0, 0), (80, 0)]),
  GameSound.win: _Buzz(
    [0, 30, 90, 30, 90, 30, 90, 120],
    [0, 150, 0, 180, 0, 210, 0, 255],
    [(0, 1), (120, 1), (240, 1), (360, 2)],
  ),
  GameSound.lose: _Buzz([0, 380], [0, 120], [(0, 2), (300, 1)]),
  GameSound.draw: _Buzz([0, 40, 120, 40], [0, 150, 0, 150], [(0, 1), (160, 1)]),
};

class GameFeedback {
  GameFeedback._();
  static final GameFeedback instance = GameFeedback._();

  /// Turn off in tests, where the audio and vibration plugins are missing.
  static bool enabled = true;

  final Map<GameSound, AudioPlayer> _players = {};
  bool? _hasVibrator;
  bool _hasAmplitude = false;
  bool _warmedUp = false;

  /// Loads the sounds and checks the vibrator ahead of the first move, so
  /// the first effect plays without a delay.
  Future<void> warmUp() async {
    if (!enabled || _warmedUp) return;
    _warmedUp = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(
        // Mix with the user's music instead of stopping it.
        focus: AudioContextConfigFocus.mixWithOthers,
        // Stay quiet when an iPhone's silent switch is on.
        respectSilence: true,
      ).build());
    } catch (_) {}
    for (final s in GameSound.values) {
      unawaited(_player(s));
    }
    unawaited(_checkVibrator());
  }

  Future<AudioPlayer?> _player(GameSound s) async {
    final existing = _players[s];
    if (existing != null) return existing;
    try {
      final p = AudioPlayer(playerId: 'sfx_${s.name}');
      _players[s] = p;
      await p.setReleaseMode(ReleaseMode.stop);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await p.setSource(AssetSource('sounds/${s.name}.wav'));
      return p;
    } catch (e) {
      debugPrint('Sound ${s.name} unavailable: $e');
      return null;
    }
  }

  Future<void> _checkVibrator() async {
    if (_hasVibrator != null) return;
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _hasAmplitude = await Vibration.hasAmplitudeControl();
    } catch (_) {
      _hasVibrator = false;
    }
  }

  void play(GameSound s, {required bool sound, required bool vibrate}) {
    if (!enabled) return;
    if (sound) unawaited(_playSound(s));
    if (vibrate) unawaited(_vibrate(s));
  }

  Future<void> _playSound(GameSound s) async {
    try {
      final p = await _player(s);
      if (p == null) return;
      await p.stop();
      await p.resume();
    } catch (_) {}
  }

  Future<void> _vibrate(GameSound s) async {
    final buzz = _buzzes[s]!;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // The Taptic Engine feels best through the system impact styles.
      _tapSequence(buzz.taps);
      return;
    }
    await _checkVibrator();
    if (_hasVibrator != true) {
      _tapSequence(buzz.taps);
      return;
    }
    try {
      await Vibration.vibrate(
        pattern: buzz.pattern,
        intensities: _hasAmplitude ? buzz.intensities : const [],
      );
    } catch (_) {
      _tapSequence(buzz.taps);
    }
  }

  void _tapSequence(List<(int, int)> taps) {
    for (final (delay, strength) in taps) {
      void tap() => switch (strength) {
            0 => HapticFeedback.lightImpact(),
            1 => HapticFeedback.mediumImpact(),
            _ => HapticFeedback.heavyImpact(),
          };
      if (delay == 0) {
        tap();
      } else {
        Timer(Duration(milliseconds: delay), tap);
      }
    }
  }
}
