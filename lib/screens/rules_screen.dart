import 'package:flutter/material.dart';

import '../game/board.dart';
import '../game/game_controller.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/board_view.dart';
import '../widgets/decorations.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = settings.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.howToPlay)),
      extendBodyBehindAppBar: true,
      body: MugguluBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoSection(title: s.aboutTitle, child: Text(s.about, style: _body)),
                      Row(
                        children: [
                          Expanded(
                            child: _Diagram(
                              caption: s.diagramStart,
                              tigers: Board.tigerStart,
                              goats: const [],
                            ),
                          ),
                          Expanded(
                            child: _Diagram(
                              caption: s.diagramJump,
                              tigers: const [9],
                              goats: const [15, 8, 13],
                              arrow: (9, 20),
                            ),
                          ),
                          Expanded(
                            child: _Diagram(
                              caption: s.diagramTrap,
                              tigers: const [19],
                              goats: const [14, 20, 8, 21],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InfoSection(
                        title: s.rulesTitle,
                        child: _NumberedList(items: s.rules(settings.captureTarget)),
                      ),
                      InfoSection(
                        title: s.tipsTitle,
                        child: _NumberedList(items: s.tips, bullet: '💡'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _body = TextStyle(fontSize: 15, height: 1.5, color: AppColors.chalk);

class _NumberedList extends StatelessWidget {
  final List<String> items;
  final String? bullet;
  const _NumberedList({required this.items, this.bullet});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: bullet == null
                      ? const BoxDecoration(color: AppColors.turmeric, shape: BoxShape.circle)
                      : null,
                  child: Text(
                    bullet ?? '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.night,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(child: Text(item, style: _body)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Diagram extends StatelessWidget {
  final String caption;
  final List<int> tigers;
  final List<int> goats;
  final (int, int)? arrow;

  const _Diagram({
    required this.caption,
    required this.tigers,
    required this.goats,
    this.arrow,
  });

  @override
  Widget build(BuildContext context) {
    final a = arrow;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: BoardView(
              pieces: [
                for (final (i, p) in tigers.indexed) Piece(i, true, p),
                for (final (i, p) in goats.indexed) Piece(100 + i, false, p),
              ],
              arrows: [if (a != null) a],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.chalk.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
