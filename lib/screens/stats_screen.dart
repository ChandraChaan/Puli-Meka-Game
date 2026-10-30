import 'package:flutter/material.dart';

import '../game/ai.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/decorations.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = settings.s;
    final st = settings.stats;
    final winRate = st.played == 0 ? 0 : (st.won * 100 / st.played).round();

    return Scaffold(
      appBar: AppBar(title: Text(s.stats)),
      extendBodyBehindAppBar: true,
      body: MugguluBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.statsVsComputer,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.turmeric,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (st.played == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Text('🐐 🐯', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(s.noGamesYet, style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        )
                      else ...[
                        _WinRateRing(percent: winRate),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.1,
                          children: [
                            _Tile(label: s.played, value: st.played),
                            _Tile(label: s.won, value: st.won, color: AppColors.leafLight),
                            _Tile(label: s.lost, value: st.lost, color: AppColors.kumkum),
                            _Tile(label: s.drawn, value: st.drawn),
                            _Tile(label: '🐐 ${s.asGoats}', value: st.wonAsGoats),
                            _Tile(label: '🐯 ${s.asTigers}', value: st.wonAsTigers),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Tile(
                            label: '🔥 ${s.streak}',
                            value: st.bestStreak,
                            color: AppColors.marigold),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final d in Difficulty.values) ...[
                              if (d != Difficulty.easy) const SizedBox(width: 10),
                              Expanded(
                                child: _Tile(
                                  label: '${s.won} · ${s.difficultyName(d)}',
                                  value: st.winsByDifficulty[d] ?? 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(s.resetStats),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('${s.resetStats}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(s.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(s.ok),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) settings.resetStats();
                          },
                        ),
                      ],
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

class _Tile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Tile({required this.label, required this.value, this.color = AppColors.chalk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.chalk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chalk.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.chalk.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _WinRateRing extends StatelessWidget {
  final int percent;
  const _WinRateRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                color: AppColors.turmeric,
                backgroundColor: AppColors.chalk.withValues(alpha: 0.1),
              ),
            ),
            Center(
              child: Text(
                '$percent%',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
