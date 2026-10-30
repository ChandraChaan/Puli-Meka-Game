import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A thoranam: the mango-leaf and marigold garland hung over doorways for
/// festivals.
class Thoranam extends StatelessWidget {
  final double height;
  const Thoranam({super.key, this.height = 56});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: const CustomPaint(painter: _ThoranamPainter()),
      );
}

class _ThoranamPainter extends CustomPainter {
  const _ThoranamPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rope = Paint()
      ..color = const Color(0xFFB8860B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final sag = size.height * 0.12;
    canvas.drawPath(
      Path()
        ..moveTo(0, 4)
        ..quadraticBezierTo(size.width / 2, 4 + sag * 2, size.width, 4),
      rope,
    );

    final count = math.max(6, (size.width / 30).round());
    final step = size.width / count;
    for (var i = 0; i < count; i++) {
      final x = step * (i + 0.5);
      final tRope = x / size.width;
      final y = 4 + sag * 2 * 2 * tRope * (1 - tRope);
      if (i.isEven) {
        _leaf(canvas, Offset(x, y), size.height * 0.8);
      } else {
        _marigold(canvas, Offset(x, y + size.height * 0.18), size.height * 0.16);
      }
    }
  }

  void _leaf(Canvas canvas, Offset top, double length) {
    final w = length * 0.32;
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(top.dx + w, top.dy + length * 0.45, top.dx, top.dy + length)
      ..quadraticBezierTo(top.dx - w, top.dy + length * 0.45, top.dx, top.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: const [AppColors.leafLight, AppColors.mangoLeaf, Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(top.dx - w, top.dy, w * 2, length)),
    );
    canvas.drawLine(
      top,
      top + Offset(0, length * 0.95),
      Paint()
        ..color = const Color(0xFF1B5E20)
        ..strokeWidth = 1,
    );
  }

  void _marigold(Canvas canvas, Offset c, double r) {
    final petal = Paint()..color = AppColors.marigold;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.6, r * 0.5, petal);
    }
    canvas.drawCircle(c, r * 0.6, Paint()..color = AppColors.turmeric);
    canvas.drawCircle(c, r * 0.25, Paint()..color = const Color(0xFFB34700));
  }

  @override
  bool shouldRepaint(_ThoranamPainter old) => false;
}

/// A faint grid of muggulu (kolam) dots behind a screen.
class MugguluBackground extends StatelessWidget {
  final Widget child;
  const MugguluBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: appBackground,
        child: CustomPaint(painter: const _DotsPainter(), child: child),
      );
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 28.0;
    final dot = Paint()..color = AppColors.chalk.withValues(alpha: 0.05);
    final loop = Paint()
      ..color = AppColors.chalk.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.6, dot);
      }
    }
    // Loops woven between the dots, as in a sikku muggu.
    for (var y = gap; y < size.height; y += gap * 4) {
      for (var x = gap; x < size.width; x += gap * 4) {
        canvas.drawCircle(Offset(x, y), gap * 0.7, loop);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

/// Marigold petals falling in celebration.
class PetalShower extends StatefulWidget {
  const PetalShower({super.key});

  @override
  State<PetalShower> createState() => _PetalShowerState();
}

class _PetalShowerState extends State<PetalShower> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..forward();
  final _petals = List.generate(70, (i) => _Petal(math.Random(i * 7919)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PetalPainter(_c, _petals),
        ),
      );
}

class _Petal {
  final double x;
  final double delay;
  final double speed;
  final double sway;
  final double size;
  final double spin;
  final Color color;

  _Petal(math.Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.4,
        speed = 0.7 + r.nextDouble() * 0.6,
        sway = r.nextDouble() * 2 * math.pi,
        size = 6 + r.nextDouble() * 7,
        spin = (r.nextDouble() - 0.5) * 10,
        color = const [
          AppColors.marigold,
          AppColors.turmeric,
          Color(0xFFFF7043),
          AppColors.kumkum,
          Color(0xFFFFE082),
        ][r.nextInt(5)];
}

class _PetalPainter extends CustomPainter {
  final Animation<double> progress;
  final List<_Petal> petals;
  _PetalPainter(this.progress, this.petals) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      final t = ((progress.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0) * p.speed;
      if (t <= 0 || t >= 1.05) continue;
      final y = -20 + t * (size.height + 40);
      final x = p.x * size.width + math.sin(t * 8 + p.sway) * 24;
      final paint = Paint()
        ..color = p.color.withValues(
            alpha: math.min((1.2 - t).clamp(0.0, 1.0), (1 - progress.value) * 4).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter old) => false;
}
