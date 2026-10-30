import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../game/ai.dart';
import '../game/game_controller.dart';
import '../game/puli_meka.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/board_view.dart';
import '../widgets/decorations.dart';
import 'about_screen.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = settings.s;
    return Scaffold(
      body: MugguluBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Thoranam(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _LanguageToggle(settings: settings),
                    const Spacer(),
                    IconButton(
                      tooltip: s.aboutApp,
                      icon: const Icon(Icons.info_outline_rounded),
                      onPressed: () => openAbout(context),
                    ),
                    IconButton(
                      tooltip: s.settings,
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: () => showSettingsSheet(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        children: [
                          const _Title(),
                          const SizedBox(height: 6),
                          Text(
                            s.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(height: 210, child: _PreviewBoard()),
                          const SizedBox(height: 20),
                          _MenuCard(
                            emoji: '🤖',
                            title: s.playComputer,
                            subtitle: s.playComputerSub,
                            primary: true,
                            onTap: () => _startVsComputer(context),
                          ),
                          _MenuCard(
                            emoji: '👫',
                            title: s.playFriend,
                            subtitle: s.playFriendSub,
                            onTap: () => _openGame(
                              context,
                              GameController(
                                mode: GameMode.twoPlayer,
                                captureTarget: settings.captureTarget,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _MenuCard(
                                  emoji: '📜',
                                  title: s.howToPlay,
                                  compact: true,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => const RulesScreen()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MenuCard(
                                  emoji: '🏆',
                                  title: s.stats,
                                  compact: true,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: () => openAbout(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.chalk.withValues(alpha: 0.6),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: Text('${s.madeIn} · ${s.aboutApp}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startVsComputer(BuildContext context) async {
    final settings = SettingsScope.of(context);
    final setup = await showModalBottomSheet<(Side, Difficulty)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewGameSheet(),
    );
    if (setup == null || !context.mounted) return;
    settings.rememberSetup(setup.$1, setup.$2);
    _openGame(
      context,
      GameController(
        mode: GameMode.vsComputer,
        humanSide: setup.$1,
        difficulty: setup.$2,
        captureTarget: settings.captureTarget,
      ),
    );
  }

  void _openGame(BuildContext context, GameController controller) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller)),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [AppColors.turmeric, AppColors.marigold],
          ).createShader(r),
          child: const Text(
            'పులి మేక',
            style: TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
        ),
        const Text(
          'PULI  MEKA',
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 6,
            fontWeight: FontWeight.w800,
            color: AppColors.chalk,
          ),
        ),
      ],
    );
  }
}

/// A position mid-game, shown on the home screen.
class _PreviewBoard extends StatelessWidget {
  const _PreviewBoard();

  static final _pieces = [
    for (final (i, p) in [0, 9, 16].indexed) Piece(i, true, p),
    for (final (i, p) in [2, 3, 8, 13, 14, 15, 19, 20, 17].indexed) Piece(10 + i, false, p),
  ];

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: BoardView(
          pieces: _pieces,
          arrows: const [(16, 18)],
        ),
      );
}

class _MenuCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final bool primary;
  final bool compact;
  final VoidCallback onTap;

  const _MenuCard({
    required this.emoji,
    required this.title,
    this.subtitle,
    this.primary = false,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? AppColors.night : AppColors.chalk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: primary ? AppColors.turmeric : AppColors.chalk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 14 : 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: primary ? Colors.transparent : AppColors.chalk.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Text(emoji, style: TextStyle(fontSize: compact ? 22 : 30)),
                const SizedBox(width: 12),
                Flexible(
                  fit: compact ? FlexFit.loose : FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: fg,
                          fontSize: compact ? 15 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: TextStyle(color: fg.withValues(alpha: 0.75))),
                    ],
                  ),
                ),
                if (!compact) Icon(Icons.chevron_right_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final AppSettings settings;
  const _LanguageToggle({required this.settings});

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool telugu) {
      final selected = settings.telugu == telugu;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => settings.setTelugu(telugu),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.turmeric : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.night : AppColors.chalk,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.chalk.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('EN', false), option('తెలుగు', true)],
      ),
    );
  }
}

class _NewGameSheet extends StatefulWidget {
  const _NewGameSheet();

  @override
  State<_NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<_NewGameSheet> {
  Side? _side;
  Difficulty? _difficulty;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = settings.s;
    final side = _side ?? settings.lastSide;
    final difficulty = _difficulty ?? settings.lastDifficulty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.chooseSide, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final option in Side.values) ...[
                  if (option == Side.tiger) const SizedBox(width: 12),
                  Expanded(
                    child: _SideCard(
                      side: option,
                      selected: side == option,
                      title: s.sideName(option),
                      blurb: s.sideBlurb(option),
                      onTap: () => setState(() => _side = option),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text(s.difficulty, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<Difficulty>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.turmeric,
                selectedForegroundColor: AppColors.night,
                minimumSize: const Size(0, 48),
              ),
              segments: [
                for (final d in Difficulty.values)
                  ButtonSegment(value: d, label: Text(s.difficultyName(d))),
              ],
              selected: {difficulty},
              onSelectionChanged: (v) => setState(() => _difficulty = v.first),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(s.start),
              onPressed: () => Navigator.of(context).pop((side, difficulty)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  final Side side;
  final bool selected;
  final String title;
  final String blurb;
  final VoidCallback onTap;

  const _SideCard({
    required this.side,
    required this.selected,
    required this.title,
    required this.blurb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: selected
            ? AppColors.turmeric.withValues(alpha: 0.18)
            : AppColors.chalk.withValues(alpha: 0.06),
        border: Border.all(
          color: selected ? AppColors.turmeric : AppColors.chalk.withValues(alpha: 0.2),
          width: selected ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: PieceToken(isTiger: side == Side.tiger),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                blurb,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.75), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void openAbout(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
}

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final settings = SettingsScope.of(context);
      final s = settings.s;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.settings, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(s.language, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.turmeric,
                  selectedForegroundColor: AppColors.night,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('English')),
                  ButtonSegment(value: true, label: Text('తెలుగు')),
                ],
                selected: {settings.telugu},
                onSelectionChanged: (v) => settings.setTelugu(v.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.soundVibration, style: const TextStyle(fontWeight: FontWeight.w700)),
                value: settings.sound,
                onChanged: settings.setSound,
              ),
              Text(s.captureTargetTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s.captureTargetSub,
                  style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.turmeric,
                  selectedForegroundColor: AppColors.night,
                ),
                segments: [
                  for (final t in PuliMekaGame.captureTargets)
                    ButtonSegment(value: t, label: Text('$t')),
                ],
                selected: {settings.captureTarget},
                onSelectionChanged: (v) => settings.setCaptureTarget(v.first),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(s.aboutApp, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  final navigator = Navigator.of(context)..pop();
                  navigator.push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
