import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../feedback.dart';
import '../game/game_controller.dart';
import '../game/puli_meka.dart';
import '../l10n.dart';
import '../main.dart';
import '../online/online_session.dart';
import '../theme.dart';
import '../widgets/animal_face.dart';
import '../widgets/board_view.dart';
import '../widgets/decorations.dart';
import 'rules_screen.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;

  /// The online room, when playing someone over the internet.
  final OnlineSession? online;

  const GameScreen({super.key, required this.controller, this.online});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;
  bool _showResult = false;

  int? _rejectPoint;
  int? _rejectPiece;
  int _rejectSerial = 0;

  /// A short message shown over the board, such as a change of phase.
  String? _banner;
  int _bannerSerial = 0;

  @override
  void initState() {
    super.initState();
    c.onMove = _feedback;
    c.onGameOver = _gameOver;
    c.onSelect = (point) =>
        _play(c.game.board[point] == Cell.tiger ? GameSound.growl : GameSound.bleat);
    c.onInvalidTap = _invalidTap;
    c.addListener(_onChange);
    widget.online?.addListener(_onChange);
    c.start();
    if (online != null) {
      _round = online!.room?.round ?? 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBanner(SettingsScope.read(context).s.youAre(c.humanSide));
      });
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    final o = online;
    if (o != null) {
      o.removeListener(_onChange);
      // Closing the screen mid-game counts as resigning.
      if (!c.isOver) o.leave();
      o.dispose();
    }
    c.dispose();
    super.dispose();
  }

  OnlineSession? get online => widget.online;

  /// The online round shown, to notice when a rematch starts.
  int _round = 0;

  void _onChange() {
    if (c.result == null && _showResult) _showResult = false;
    // Keep up after undo, restart or a rematch.
    _danger = c.goatsInDanger;
    final round = online?.room?.round;
    if (round != null && round != _round) {
      _round = round;
      _showBanner(SettingsScope.read(context).s.youAre(c.humanSide));
    }
    setState(() {});
  }

  void _play(GameSound sound, {Buzz? buzz}) {
    final settings = SettingsScope.read(context);
    GameFeedback.instance
        .play(sound, sound: settings.sound, vibrate: settings.vibration, buzz: buzz);
  }

  /// Goats already in danger, so a nervous bleat sounds only for new ones.
  Set<int> _danger = const {};

  void _invalidTap(int point) {
    _play(GameSound.invalid);
    setState(() {
      _rejectPoint = point;
      // Shake the piece tapped, or the one in hand if the spot was empty.
      _rejectPiece = c.game.board[point] != Cell.empty ? point : c.selected;
      _rejectSerial++;
    });
  }

  void _showBanner(String text) {
    setState(() {
      _banner = text;
      _bannerSerial++;
    });
  }

  void _feedback(Move m) {
    _play(m.isPlacement
        ? GameSound.place
        : m.isCapture
            ? GameSound.capture
            : GameSound.move);
    final s = SettingsScope.read(context).s;
    final game = c.game;

    // A goat that has just come within a tiger's reach cries out, once the
    // move has landed.
    final danger = c.goatsInDanger;
    final fresh = danger.difference(_danger).isNotEmpty;
    _danger = danger;
    if (fresh && !m.isCapture && c.result == null) {
      Future<void>.delayed(const Duration(milliseconds: 380), () {
        if (mounted && !c.isOver) _play(GameSound.scared);
      });
    }

    if (m.isPlacement && !game.isPlacementPhase && c.result == null) {
      _showBanner(s.allGoatsPlaced);
    } else if (m.isCapture &&
        c.result == null &&
        game.goatsCaptured == game.captureTarget - 1) {
      _showBanner(s.oneMoreCapture);
    }
  }

  void _gameOver(GameResult result) {
    final settings = SettingsScope.read(context);
    if (c.mode == GameMode.vsComputer) {
      settings.recordGame(
        playerSide: c.humanSide,
        difficulty: c.difficulty,
        outcome: result.outcome,
      );
    }
    final winner = result.winner;
    // You hear the winning animal; the vibration says whether you won.
    final GameSound sound = switch (winner) {
      null => GameSound.draw,
      Side.tiger => GameSound.tigersWin,
      Side.goat => GameSound.goatsWin,
    };
    final Buzz buzz;
    if (winner == null) {
      buzz = Buzz.draw;
    } else if (c.mode != GameMode.twoPlayer && winner != c.humanSide) {
      buzz = Buzz.lose;
    } else {
      buzz = Buzz.win;
    }
    // Let the last move land and the winners celebrate before the result card.
    final lastWasCapture = c.lastMove?.isCapture ?? false;
    Future<void>.delayed(Duration(milliseconds: lastWasCapture ? 1300 : 900), () {
      if (!mounted || c.result != result) return;
      _play(sound, buzz: buzz);
      setState(() => _showResult = true);
    });
  }

  Future<bool> _confirm(String title, String yes) async {
    final s = SettingsScope.read(context).s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(yes)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _restart() async {
    final s = SettingsScope.read(context).s;
    if (c.history.isNotEmpty && !c.isOver && !await _confirm(s.restartConfirm, s.ok)) return;
    c.restart();
  }

  bool get _inProgress => c.history.isNotEmpty && !c.isOver;

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context).s;
    final result = c.result;
    final humanWon = result != null &&
        (c.mode == GameMode.twoPlayer ? result.winner != null : result.winner == c.humanSide);

    return PopScope(
      canPop: online == null ? !_inProgress : c.isOver,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = online == null
            ? await _confirm(s.leaveGame, s.leave)
            : await _confirm(s.resignConfirm, s.resign);
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: MugguluBackground(
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth > 640 && box.maxWidth > box.maxHeight;
                  final board = Padding(
                    padding: const EdgeInsets.all(8),
                    child: _board(),
                  );
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(child: board),
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              _topBar(s),
                              _players(s),
                              _status(s),
                              const Spacer(),
                              _actions(s),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _topBar(s),
                      _players(s),
                      _status(s),
                      Expanded(child: board),
                      _actions(s),
                    ],
                  );
                }),
                if (_banner != null)
                  _Banner(
                    key: ValueKey(_bannerSerial),
                    text: _banner!,
                    onDone: () => setState(() => _banner = null),
                  ),
                if (result != null && _showResult) ...[
                  _ResultOverlay(
                    s: s,
                    controller: c,
                    result: result,
                    onPlayAgain: c.restart,
                    online: online,
                    onViewBoard: () => setState(() => _showResult = false),
                    onHome: () => Navigator.of(context).pop(),
                  ),
                  if (humanWon) const Positioned.fill(child: PetalShower()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _board() {
    final placing =
        c.isHumanTurn && !c.thinking && c.game.turn == Side.goat && c.game.isPlacementPhase;
    return BoardView(
      pieces: c.pieces,
      selected: c.selected,
      destinations: c.selectedMoves,
      movable: c.thinking ? const {} : c.movablePieces,
      threatened: c.threatenedGoats,
      lastMove: c.lastMove,
      hint: c.hint,
      showPlacementTargets: placing,
      moveNumber: c.history.length,
      rejectPoint: _rejectPoint,
      rejectPiece: _rejectPiece,
      rejectSerial: _rejectSerial,
      celebrate: c.result?.winner,
      gameOver: c.isOver,
      scared: c.goatsInDanger,
      hunting: c.huntingTigers,
      trapped: c.trappedTigers,
      onTapPoint: c.tapPoint,
      pointLabel: (p) => SettingsScope.of(context).s.pointLabel(p, c.game.board[p]),
    );
  }

  Widget _topBar(S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(s.appName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(
                  switch (c.mode) {
                    GameMode.vsComputer => '${s.playComputer} · ${s.difficultyName(c.difficulty)}',
                    GameMode.twoPlayer => s.playFriend,
                    GameMode.online => s.onlineVs(c.opponentName ?? s.player(2)),
                  },
                  style: TextStyle(fontSize: 12, color: AppColors.chalk.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.howToPlay,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RulesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _players(S s) {
    String who(Side side) => c.sideLabel(side, s.you, s.computer, s.player);
    final game = c.game;
    final trappedTigers =
        game.pointsWith(Cell.tiger).where((p) => game.tigerMobility(p) == 0).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PlayerPanel(
              isTiger: false,
              name: s.sideName(Side.goat),
              who: who(Side.goat),
              active: !c.isOver && game.turn == Side.goat,
              thinking: _waitingOn(Side.goat),
              detail: game.isPlacementPhase ? s.inHand(game.goatsInHand) : null,
              tally: _GoatTally(game: game),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PlayerPanel(
              isTiger: true,
              name: s.sideName(Side.tiger),
              who: who(Side.tiger),
              active: !c.isOver && game.turn == Side.tiger,
              thinking: _waitingOn(Side.tiger),
              detail: s.captured(game.goatsCaptured, game.captureTarget),
              tally: Row(
                children: [
                  for (var i = 0; i < game.captureTarget; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _Pop(
                        key: ValueKey('cap$i${i < game.goatsCaptured}'),
                        // Wait for the tiger to land before the tally fills.
                        delay: i < game.goatsCaptured ? jumpDuration : Duration.zero,
                        enabled: i < game.goatsCaptured,
                        child: Icon(
                          i < game.goatsCaptured ? Icons.circle : Icons.circle_outlined,
                          size: 12,
                          color: i < game.goatsCaptured
                              ? AppColors.kumkum
                              : AppColors.chalk.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  if (trappedTigers > 0) ...[
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '🔒 ${s.trapped(trappedTigers)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Whether [side] is the computer or online opponent, and it is their move.
  bool _waitingOn(Side side) {
    if (c.isOver || c.game.turn != side) return false;
    if (c.thinking) return true;
    return c.isOnline && side != c.humanSide;
  }

  Widget _status(S s) {
    final result = c.result;
    final game = c.game;
    final o = online;
    final opponent = c.opponentName ?? s.player(2);
    String text;
    var warn = false;
    Widget? action;
    if (result != null) {
      text = result.winner == null ? s.draw : s.winnerTitle(result.winner!);
    } else if (c.thinking) {
      text = s.thinking;
    } else if (o != null && o.opponentAway) {
      text = s.opponentAway(opponent);
      warn = true;
      if (o.canClaimWin) {
        action = TextButton(onPressed: o.claimWin, child: Text(s.claimWin));
      }
    } else if (o != null && o.error != null) {
      text = s.syncProblem;
      warn = true;
    } else if (o != null && !c.isHumanTurn) {
      text = s.theirTurn(opponent);
    } else {
      final who = c.mode != GameMode.twoPlayer
          ? s.yourTurn
          : s.turnOf(c.sideLabel(game.turn, s.you, s.computer, s.player));
      final String what;
      if (game.turn == Side.tiger) {
        what = s.moveTiger;
      } else if (c.threatenedGoats.isNotEmpty) {
        what = s.mustCapture;
        warn = true;
      } else {
        what = game.isPlacementPhase ? s.placeGoat : s.moveGoat;
      }
      text = '$who · $what';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: warn
            ? AppColors.kumkum.withValues(alpha: 0.25)
            : AppColors.chalk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warn ? AppColors.kumkum : AppColors.chalk.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          if (_waitingOn(game.turn) && !warn) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.turmeric),
            ),
            const SizedBox(width: 10),
          ] else if (warn) ...[
            const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.turmeric),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: AnimatedSwitcher(
              // The old text leaves quickly; the new one arrives after it,
              // so the two never overlap.
              duration: const Duration(milliseconds: 320),
              reverseDuration: const Duration(milliseconds: 90),
              switchInCurve: const Interval(0.3, 1, curve: Curves.easeOut),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Text(
                text,
                key: ValueKey(text),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Future<void> _resign() async {
    final s = SettingsScope.read(context).s;
    if (await _confirm(s.resignConfirm, s.resign)) await online?.leave();
  }

  Widget _actions(S s) {
    if (online != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: _ActionButton(
          icon: Icons.flag_rounded,
          label: s.resign,
          onPressed: c.isOver ? null : _resign,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.undo_rounded,
              label: s.undo,
              onPressed: c.canUndo ? c.undo : null,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.lightbulb_outline_rounded,
              label: s.hint,
              busy: c.hinting,
              onPressed:
                  c.canHint && c.isHumanTurn && !c.thinking && !c.hinting ? c.showHint : null,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.refresh_rounded,
              label: s.restart,
              onPressed: _restart,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  final bool isTiger;
  final String name;
  final String who;
  final bool active;
  final bool thinking;
  final String? detail;
  final Widget tally;

  const _PlayerPanel({
    required this.isTiger,
    required this.name,
    required this.who,
    required this.active,
    required this.thinking,
    required this.detail,
    required this.tally,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isTiger ? AppColors.tigerOrange : AppColors.goatCream;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.16) : AppColors.chalk.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? accent : AppColors.chalk.withValues(alpha: 0.12),
          width: active ? 2 : 1,
        ),
        boxShadow:
            active ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 12)] : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 34, height: 34, child: PieceToken(isTiger: isTiger)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      who,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.chalk.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              if (thinking)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.turmeric),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: Text(
              detail ?? '',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          tally,
        ],
      ),
    );
  }
}

/// All 15 goats: on the board, still in hand, or captured.
class _GoatTally extends StatelessWidget {
  final PuliMekaGame game;
  const _GoatTally({required this.game});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (var i = 0; i < PuliMekaGame.totalGoats; i++)
          _Pop(
            key: ValueKey('goat$i${i < game.goatsCaptured}${i < game.goatsPlaced}'),
            enabled: i < game.goatsPlaced,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < game.goatsCaptured
                    ? AppColors.kumkum
                    : i < game.goatsPlaced
                        ? AppColors.goatCream
                        : Colors.transparent,
                border: Border.all(color: AppColors.chalk.withValues(alpha: 0.6), width: 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? AppColors.chalk : AppColors.chalk.withValues(alpha: 0.35);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(3),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.hint),
                    )
                  : Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final S s;
  final GameController controller;
  final GameResult result;
  final VoidCallback onPlayAgain;
  final OnlineSession? online;
  final VoidCallback onViewBoard;
  final VoidCallback onHome;

  const _ResultOverlay({
    required this.s,
    required this.controller,
    required this.result,
    required this.onPlayAgain,
    required this.online,
    required this.onViewBoard,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final winner = result.winner;
    // Against the computer or online, the result is told from your side.
    final vsComputer = controller.mode != GameMode.twoPlayer;
    final o = online;
    final opponent = controller.opponentName ?? s.player(2);
    final String emoji;
    final String title;
    if (winner == null) {
      emoji = '🤝';
      title = s.draw;
    } else if (vsComputer) {
      final won = winner == controller.humanSide;
      emoji = won ? '🏆' : (winner == Side.tiger ? '🐯' : '🐐');
      title = won ? s.youWin : s.youLose;
    } else {
      emoji = winner == Side.tiger ? '🐯' : '🐐';
      title = s.winnerTitle(winner);
    }

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.55 * t.clamp(0.0, 1.0)),
          child: Center(child: Transform.scale(scale: 0.8 + 0.2 * t, child: child)),
        ),
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: AppColors.redOxideDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.turmeric, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (winner == null)
                Text(emoji, style: const TextStyle(fontSize: 64))
              else
                SizedBox(
                  width: 92,
                  height: 92,
                  // Your own animal, grinning or sulking; in a two-player
                  // game, the winner.
                  child: PieceToken(
                    isTiger: (vsComputer ? controller.humanSide : winner) == Side.tiger,
                    mood: !vsComputer || winner == controller.humanSide
                        ? AnimalMood.happy
                        : AnimalMood.sad,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.turmeric,
                ),
              ),
              if (vsComputer && winner != null) ...[
                const SizedBox(height: 2),
                Text(s.winnerTitle(winner), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 8),
              Text(
                result.reason == OutcomeReason.forfeit && o != null
                    ? (winner == controller.humanSide ? s.opponentLeftReason : s.youResignedReason)
                    : s.reason(result.reason, controller.captureTarget),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 4),
              Text(
                s.movesPlayed(controller.history.length),
                style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (o == null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(s.playAgain),
                    onPressed: onPlayAgain,
                  ),
                )
              else if (o.canRematch) ...[
                if (o.opponentAskedRematch && !o.iAskedRematch) ...[
                  Text(
                    s.rematchAsked(opponent),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.turmeric),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: o.iAskedRematch
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.replay_rounded),
                    label: Text(o.iAskedRematch ? s.rematchWaiting(opponent) : s.rematch),
                    onPressed: o.iAskedRematch ? null : o.requestRematch,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.sidesSwap,
                  style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: onViewBoard, child: Text(s.review))),
                  Expanded(child: TextButton(onPressed: onHome, child: Text(s.home))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pops its child in with a little overshoot when it first appears.
class _Pop extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final Duration delay;
  const _Pop({super.key, required this.child, this.enabled = true, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final total = delay + const Duration(milliseconds: 420);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, raw, child) {
        final t = ((raw - start) / (1 - start)).clamp(0.0, 1.0);
        // Grows past full size, then settles.
        final scale = t == 0 ? 1.0 : 1 + 0.9 * math.sin(math.pi * t) * (1 - t);
        return Transform.scale(scale: scale, child: child);
      },
      child: child,
    );
  }
}

/// A message that drops over the board for a moment, then leaves.
class _Banner extends StatelessWidget {
  final String text;
  final VoidCallback onDone;
  const _Banner({super.key, required this.text, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 2000),
            onEnd: onDone,
            builder: (context, t, child) {
              // In for the first 15%, hold, then out over the last 15%.
              final inT = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
              final outT = Curves.easeIn.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0));
              return Opacity(
                opacity: (inT * (1 - outT)).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -30 * (1 - inT) - 20 * outT),
                  child: Transform.scale(scale: 0.85 + 0.15 * inT, child: child),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.redOxideDark.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.turmeric, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.turmeric,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
