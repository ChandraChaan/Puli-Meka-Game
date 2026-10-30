import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_controller.dart';
import '../game/puli_meka.dart';
import '../l10n.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/board_view.dart';
import '../widgets/decorations.dart';
import 'rules_screen.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  const GameScreen({super.key, required this.controller});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    c.onMove = _feedback;
    c.onGameOver = _gameOver;
    c.addListener(_onChange);
    c.start();
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    c.dispose();
    super.dispose();
  }

  void _onChange() {
    if (c.result == null && _showResult) _showResult = false;
    setState(() {});
  }

  void _feedback(Move m) {
    if (!SettingsScope.read(context).sound) return;
    if (m.isCapture) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    SystemSound.play(SystemSoundType.click);
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
    if (settings.sound) HapticFeedback.mediumImpact();
    setState(() => _showResult = true);
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
      canPop: !_inProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirm(s.leaveGame, s.leave) && context.mounted) {
          Navigator.of(context).pop();
        }
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
                if (result != null && _showResult) ...[
                  _ResultOverlay(
                    s: s,
                    controller: c,
                    result: result,
                    onPlayAgain: c.restart,
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
                  c.mode == GameMode.vsComputer
                      ? '${s.playComputer} · ${s.difficultyName(c.difficulty)}'
                      : s.playFriend,
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
              thinking: c.thinking && game.turn == Side.goat,
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
              thinking: c.thinking && game.turn == Side.tiger,
              detail: s.captured(game.goatsCaptured, game.captureTarget),
              tally: Row(
                children: [
                  for (var i = 0; i < game.captureTarget; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        i < game.goatsCaptured ? Icons.circle : Icons.circle_outlined,
                        size: 12,
                        color: i < game.goatsCaptured
                            ? AppColors.kumkum
                            : AppColors.chalk.withValues(alpha: 0.5),
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

  Widget _status(S s) {
    final result = c.result;
    final game = c.game;
    String text;
    var warn = false;
    if (result != null) {
      text = result.winner == null ? s.draw : s.winnerTitle(result.winner!);
    } else if (c.thinking) {
      text = s.thinking;
    } else {
      final who = c.mode == GameMode.vsComputer
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
          if (c.thinking) ...[
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
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(S s) {
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
              onPressed: c.isHumanTurn && !c.thinking && !c.hinting ? c.showHint : null,
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
          Container(
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
  final VoidCallback onViewBoard;
  final VoidCallback onHome;

  const _ResultOverlay({
    required this.s,
    required this.controller,
    required this.result,
    required this.onPlayAgain,
    required this.onViewBoard,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final winner = result.winner;
    final vsComputer = controller.mode == GameMode.vsComputer;
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
              Text(emoji, style: const TextStyle(fontSize: 64)),
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
                s.reason(result.reason, controller.captureTarget),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 4),
              Text(
                s.movesPlayed(controller.history.length),
                style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(s.playAgain),
                  onPressed: onPlayAgain,
                ),
              ),
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
