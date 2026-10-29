/// Persisted preferences and statistics.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/ai.dart';
import 'game/puli_meka.dart';
import 'l10n.dart';

class Stats {
  int played;
  int won;
  int lost;
  int drawn;
  int wonAsGoats;
  int wonAsTigers;
  int streak;
  int bestStreak;
  final Map<Difficulty, int> winsByDifficulty;

  Stats({
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.drawn = 0,
    this.wonAsGoats = 0,
    this.wonAsTigers = 0,
    this.streak = 0,
    this.bestStreak = 0,
    Map<Difficulty, int>? winsByDifficulty,
  }) : winsByDifficulty = winsByDifficulty ?? {};
}

class AppSettings extends ChangeNotifier {
  final SharedPreferences? _prefs;

  bool telugu;
  bool sound;
  int captureTarget;
  Side lastSide;
  Difficulty lastDifficulty;
  final Stats stats;

  AppSettings._(this._prefs)
      : telugu = _prefs?.getBool('telugu') ?? false,
        sound = _prefs?.getBool('sound') ?? true,
        captureTarget = _prefs?.getInt('captureTarget') ?? PuliMekaGame.defaultCaptureTarget,
        lastSide = Side.values[_prefs?.getInt('lastSide') ?? 0],
        lastDifficulty = Difficulty.values[_prefs?.getInt('lastDifficulty') ?? 1],
        stats = Stats(
          played: _prefs?.getInt('s.played') ?? 0,
          won: _prefs?.getInt('s.won') ?? 0,
          lost: _prefs?.getInt('s.lost') ?? 0,
          drawn: _prefs?.getInt('s.drawn') ?? 0,
          wonAsGoats: _prefs?.getInt('s.wonAsGoats') ?? 0,
          wonAsTigers: _prefs?.getInt('s.wonAsTigers') ?? 0,
          streak: _prefs?.getInt('s.streak') ?? 0,
          bestStreak: _prefs?.getInt('s.bestStreak') ?? 0,
          winsByDifficulty: {
            for (final d in Difficulty.values) d: _prefs?.getInt('s.wins.${d.name}') ?? 0,
          },
        );

  /// Settings that are not saved; used in tests.
  AppSettings.inMemory() : this._(null);

  static Future<AppSettings> load() async {
    try {
      return AppSettings._(await SharedPreferences.getInstance());
    } catch (_) {
      // Storage can be unavailable (e.g. private browsing); play without it.
      return AppSettings._(null);
    }
  }

  S get s => S(telugu);

  void setTelugu(bool value) {
    telugu = value;
    _prefs?.setBool('telugu', value);
    notifyListeners();
  }

  void setSound(bool value) {
    sound = value;
    _prefs?.setBool('sound', value);
    notifyListeners();
  }

  void setCaptureTarget(int value) {
    captureTarget = value;
    _prefs?.setInt('captureTarget', value);
    notifyListeners();
  }

  void rememberSetup(Side side, Difficulty difficulty) {
    lastSide = side;
    lastDifficulty = difficulty;
    _prefs?.setInt('lastSide', side.index);
    _prefs?.setInt('lastDifficulty', difficulty.index);
  }

  void recordGame({
    required Side playerSide,
    required Difficulty difficulty,
    required Outcome outcome,
  }) {
    final st = stats;
    st.played++;
    final winner = GameResult(outcome, OutcomeReason.captures).winner;
    if (winner == null) {
      st.drawn++;
      st.streak = 0;
    } else if (winner == playerSide) {
      st.won++;
      st.streak++;
      if (st.streak > st.bestStreak) st.bestStreak = st.streak;
      if (playerSide == Side.goat) {
        st.wonAsGoats++;
      } else {
        st.wonAsTigers++;
      }
      st.winsByDifficulty[difficulty] = (st.winsByDifficulty[difficulty] ?? 0) + 1;
    } else {
      st.lost++;
      st.streak = 0;
    }
    _saveStats();
    notifyListeners();
  }

  void resetStats() {
    final st = stats;
    st
      ..played = 0
      ..won = 0
      ..lost = 0
      ..drawn = 0
      ..wonAsGoats = 0
      ..wonAsTigers = 0
      ..streak = 0
      ..bestStreak = 0;
    st.winsByDifficulty.updateAll((_, __) => 0);
    _saveStats();
    notifyListeners();
  }

  void _saveStats() {
    final p = _prefs;
    if (p == null) return;
    final st = stats;
    p.setInt('s.played', st.played);
    p.setInt('s.won', st.won);
    p.setInt('s.lost', st.lost);
    p.setInt('s.drawn', st.drawn);
    p.setInt('s.wonAsGoats', st.wonAsGoats);
    p.setInt('s.wonAsTigers', st.wonAsTigers);
    p.setInt('s.streak', st.streak);
    p.setInt('s.bestStreak', st.bestStreak);
    for (final e in st.winsByDifficulty.entries) {
      p.setInt('s.wins.${e.key.name}', e.value);
    }
  }
}
