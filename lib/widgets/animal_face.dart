/// Cartoon tiger and goat faces, painted in code, that blink, twitch their
/// ears, follow the enemy with their eyes and show how they feel.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AnimalMood {
  /// Relaxed, looking around.
  calm,

  /// Picked up by the player: eyes wide open.
  alert,

  /// A goat that a tiger can jump: wide eyes, raised brows, trembling.
  scared,

  /// A tiger that can capture: narrowed eyes and a sly look.
  hunting,

  /// A tiger in hand or mid-pounce: mouth open, fangs out.
  roar,

  /// Winners: eyes closed in a big smile.
  happy,

  /// Losers, and tigers with no move: drooping brows.
  sad,

  /// A goat being carried off.
  dizzy,
}

class AnimalFace extends StatefulWidget {
  final bool isTiger;
  final AnimalMood mood;

  /// Where the animal is looking, as a direction (length up to 1).
  final Offset look;

  /// Whether it blinks and twitches on its own.
  final bool lively;

  const AnimalFace({
    super.key,
    required this.isTiger,
    this.mood = AnimalMood.calm,
    this.look = Offset.zero,
    this.lively = true,
  });

  @override
  State<AnimalFace> createState() => _AnimalFaceState();
}

class _AnimalFaceState extends State<AnimalFace> with SingleTickerProviderStateMixin {
  static final _random = math.Random();

  // Each animal gets its own rhythm so a herd doesn't blink in unison.
  final double _phase = _random.nextDouble();
  final bool _twitcher = _random.nextBool();
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 3400 + _random.nextInt(1800)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AnimalFace old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final run = widget.lively && !still;
    if (run && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!run && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _clamp(widget.look)),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, look, _) => CustomPaint(
          size: Size.infinite,
          painter: _FacePainter(
            isTiger: widget.isTiger,
            mood: widget.mood,
            look: look,
            clock: _clock,
            phase: _phase,
            twitcher: _twitcher,
          ),
        ),
      ),
    );
  }

  static Offset _clamp(Offset o) {
    final d = o.distance;
    return d > 1 ? o / d : o;
  }
}

class _FacePainter extends CustomPainter {
  final bool isTiger;
  final AnimalMood mood;
  final Offset look;
  final AnimationController clock;
  final double phase;
  final bool twitcher;

  _FacePainter({
    required this.isTiger,
    required this.mood,
    required this.look,
    required this.clock,
    required this.phase,
    required this.twitcher,
  }) : super(repaint: clock);

  // Colours.
  static const _tigerLight = Color(0xFFFFCC80);
  static const _tigerMid = Color(0xFFFB8C00);
  static const _tigerDeep = Color(0xFFD84F00);
  static const _tigerLine = Color(0xFF3B1A05);
  static const _cream = Color(0xFFFFF8E7);
  static const _goatLight = Colors.white;
  static const _goatMid = Color(0xFFF3E5C8);
  static const _goatDeep = Color(0xFFD7C4A0);
  static const _goatLine = Color(0xFF6D4C2F);
  static const _horn = Color(0xFF8D6E63);
  static const _hornLight = Color(0xFFBCAAA4);
  static const _pink = Color(0xFFF8BBD0);

  /// Position in the idle cycle, 0 to 1.
  double get _t => (clock.value + phase) % 1.0;

  /// How open the eyes are: 1 normally, closing briefly once a cycle.
  double get _eyeOpen {
    const start = 0.12, length = 0.05;
    final w = _t - start;
    if (w < 0 || w > length) return 1;
    return 1 - 0.9 * math.sin(math.pi * w / length);
  }

  /// A quick ear flick, for some animals, once a cycle.
  double get _twitch {
    if (!twitcher) return 0;
    const start = 0.55, length = 0.06;
    final w = _t - start;
    if (w < 0 || w > length) return 0;
    return math.sin(math.pi * 2 * w / length) * 0.22;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    // Gentle breathing, and a shiver when scared.
    final breath = 1 + 0.018 * math.sin(_t * math.pi * 4);
    var shiver = 0.0;
    if (mood == AnimalMood.scared && clock.isAnimating) {
      shiver = math.sin((clock.lastElapsedDuration?.inMilliseconds ?? 0) / 22.0) * u * 0.035;
    }
    canvas.translate(shiver, 0);
    canvas.scale(breath);

    if (isTiger) {
      _tiger(canvas, u);
    } else {
      _goat(canvas, u);
    }
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _headPaint(double u, List<Color> colors) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: colors,
      stops: const [0, 0.6, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: u));

  // ---------------------------------------------------------------- Tiger

  void _tiger(Canvas c, double u) {
    final line = math.max(1.2, u * 0.09);

    // Ears, behind the head.
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.translate(s * 0.66 * u, -0.74 * u);
      c.rotate(s * 0.25 + (s > 0 ? _twitch : 0));
      c.drawCircle(Offset.zero, 0.34 * u, _fill(_tigerDeep));
      c.drawCircle(Offset.zero, 0.34 * u, _stroke(_tigerLine, line * 0.8));
      c.drawCircle(Offset(0, 0.04 * u), 0.18 * u, _fill(_cream));
      c.restore();
    }

    final head = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: u));
    c.drawPath(head, _headPaint(u, const [_tigerLight, _tigerMid, _tigerDeep]));

    // Stripes, kept inside the head.
    c.save();
    c.clipPath(head);
    final stripe = _fill(_tigerLine);
    Path tri(List<Offset> pts) => Path()..addPolygon([for (final p in pts) p * u], true);
    c.drawPath(tri(const [Offset(-0.09, -1.0), Offset(0.09, -1.0), Offset(0, -0.56)]), stripe);
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          tri([Offset(s * 0.22, -0.97), Offset(s * 0.38, -0.9), Offset(s * 0.2, -0.64)]), stripe);
      c.drawPath(tri([Offset(s * 1.0, -0.1), Offset(s * 1.0, 0.1), Offset(s * 0.62, 0.0)]), stripe);
      c.drawPath(
          tri([Offset(s * 0.95, 0.28), Offset(s * 0.88, 0.46), Offset(s * 0.6, 0.3)]), stripe);
    }
    c.restore();
    c.drawCircle(Offset.zero, u, _stroke(_tigerLine, line));

    // White cheeks and chin.
    final muzzle = _fill(_cream);
    for (final s in [-1.0, 1.0]) {
      c.drawOval(
          Rect.fromCenter(center: Offset(s * 0.2 * u, 0.4 * u), width: 0.46 * u, height: 0.38 * u),
          muzzle);
    }
    c.drawOval(
        Rect.fromCenter(center: Offset(0, 0.64 * u), width: 0.38 * u, height: 0.24 * u), muzzle);

    _eyes(c, u, iris: const Color(0xFFFFB300), round: true, line: _tigerLine);
    _brows(c, u, _tigerLine);

    // Mouth.
    if (mood == AnimalMood.roar) {
      c.drawOval(
        Rect.fromCenter(center: Offset(0, 0.55 * u), width: 0.4 * u, height: 0.36 * u),
        _fill(const Color(0xFF7B1F1F)),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(0, 0.64 * u), width: 0.22 * u, height: 0.12 * u),
        _fill(const Color(0xFFE57373)),
      );
      for (final s in [-1.0, 1.0]) {
        c.drawPath(
          Path()
            ..addPolygon([
              Offset(s * 0.15 * u, 0.4 * u),
              Offset(s * 0.06 * u, 0.4 * u),
              Offset(s * 0.1 * u, 0.55 * u),
            ], true),
          _fill(Colors.white),
        );
      }
    } else {
      final mouth = _stroke(_tigerLine, u * 0.055);
      c.drawLine(Offset(0, 0.3 * u), Offset(0, 0.42 * u), mouth);
      final drop = switch (mood) {
        AnimalMood.happy => 0.1,
        AnimalMood.sad => -0.06,
        _ => 0.04,
      };
      for (final s in [-1.0, 1.0]) {
        c.drawPath(
          Path()
            ..moveTo(0, 0.42 * u)
            ..quadraticBezierTo(s * 0.06 * u, (0.46 + drop) * u, s * 0.15 * u, 0.44 * u),
          mouth,
        );
      }
    }

    // Nose.
    c.drawPath(
      Path()
        ..moveTo(-0.15 * u, 0.17 * u)
        ..quadraticBezierTo(0, 0.1 * u, 0.15 * u, 0.17 * u)
        ..quadraticBezierTo(0.05 * u, 0.32 * u, 0, 0.32 * u)
        ..quadraticBezierTo(-0.05 * u, 0.32 * u, -0.15 * u, 0.17 * u),
      _fill(const Color(0xFF5D2A1A)),
    );
    c.drawCircle(Offset(-0.05 * u, 0.16 * u), 0.03 * u, _fill(Colors.white.withValues(alpha: 0.6)));

    // Whiskers.
    final whisker = _stroke(Colors.white.withValues(alpha: 0.85), math.max(0.6, u * 0.025));
    for (final s in [-1.0, 1.0]) {
      for (var k = 0; k < 3; k++) {
        c.drawLine(
          Offset(s * 0.36 * u, (0.36 + k * 0.07) * u),
          Offset(s * 0.86 * u, (0.26 + k * 0.13) * u),
          whisker,
        );
      }
    }
  }

  // ----------------------------------------------------------------- Goat

  void _goat(Canvas c, double u) {
    final line = math.max(1.2, u * 0.08);

    // Horns, behind the head.
    for (final s in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(s * 0.26 * u, -0.7 * u)
        ..quadraticBezierTo(s * 0.26 * u, -1.36 * u, s * 0.74 * u, -1.2 * u);
      c.drawPath(horn, _stroke(_goatLine, 0.28 * u));
      c.drawPath(horn, _stroke(_horn, 0.2 * u));
      c.drawPath(horn, _stroke(_hornLight, 0.07 * u));
    }

    // Floppy ears, sticking out sideways.
    final flop = math.sin(_t * math.pi * 2) * 0.05;
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.translate(s * 0.95 * u, -0.2 * u);
      c.rotate(s * (0.38 + flop + (s > 0 ? _twitch : 0)));
      final ear = Rect.fromCenter(center: Offset.zero, width: 0.74 * u, height: 0.32 * u);
      c.drawOval(ear, _fill(_goatMid));
      c.drawOval(ear, _stroke(_goatLine, line * 0.8));
      c.drawOval(
        Rect.fromCenter(center: Offset(s * 0.06 * u, 0), width: 0.5 * u, height: 0.15 * u),
        _fill(_pink),
      );
      c.restore();
    }

    // Beard, hanging below the chin.
    final beard = Path()
      ..moveTo(-0.14 * u, 0.86 * u)
      ..quadraticBezierTo(-0.08 * u, 1.22 * u, 0.0, 1.32 * u)
      ..quadraticBezierTo(0.08 * u, 1.22 * u, 0.14 * u, 0.86 * u)
      ..close();
    c.drawPath(beard, _fill(const Color(0xFFE8DCC4)));
    c.drawPath(beard, _stroke(_goatLine, line * 0.7));

    c.drawCircle(Offset.zero, u, _headPaint(u, const [_goatLight, _goatMid, _goatDeep]));

    // A tuft of darker hair on the forehead.
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: u)));
    final tuft = Path()..moveTo(-0.3 * u, -1.0 * u);
    for (var i = 0; i < 3; i++) {
      final x0 = (-0.3 + i * 0.2) * u;
      tuft.quadraticBezierTo(x0 + 0.1 * u, -0.52 * u, x0 + 0.2 * u, -0.66 * u);
    }
    tuft
      ..lineTo(0.3 * u, -1.0 * u)
      ..close();
    c.drawPath(tuft, _fill(const Color(0xFFC9A57E)));
    c.restore();
    c.drawCircle(Offset.zero, u, _stroke(_goatLine, line));

    // Rosy cheeks.
    for (final s in [-1.0, 1.0]) {
      c.drawCircle(Offset(s * 0.6 * u, 0.24 * u), 0.12 * u, _fill(_pink.withValues(alpha: 0.6)));
    }

    _eyes(c, u, iris: const Color(0xFFFBC02D), round: false, line: _goatLine);
    _brows(c, u, _goatLine);

    // Muzzle, nostrils and mouth.
    c.drawOval(
      Rect.fromCenter(center: Offset(0, 0.5 * u), width: 0.64 * u, height: 0.44 * u),
      _fill(const Color(0xFFF6D5C8)),
    );
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.translate(s * 0.1 * u, 0.42 * u);
      c.rotate(s * 0.5);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 0.1 * u, height: 0.06 * u),
        _fill(const Color(0xFF8D5A4A)),
      );
      c.restore();
    }
    final mouth = _stroke(_goatLine, u * 0.05);
    switch (mood) {
      case AnimalMood.scared || AnimalMood.dizzy:
        c.drawOval(
          Rect.fromCenter(center: Offset(0, 0.6 * u), width: 0.12 * u, height: 0.14 * u),
          _fill(const Color(0xFF7B1F1F)),
        );
      default:
        final curve = switch (mood) {
          AnimalMood.happy => 0.74,
          AnimalMood.sad => 0.56,
          _ => 0.66,
        };
        c.drawPath(
          Path()
            ..moveTo(-0.13 * u, 0.6 * u)
            ..quadraticBezierTo(0, curve * u, 0.13 * u, 0.6 * u),
          mouth,
        );
    }

    if (mood == AnimalMood.scared) {
      // A bead of sweat.
      final drop = Path()
        ..moveTo(0.74 * u, -0.66 * u)
        ..quadraticBezierTo(0.9 * u, -0.4 * u, 0.74 * u, -0.36 * u)
        ..quadraticBezierTo(0.6 * u, -0.4 * u, 0.74 * u, -0.66 * u);
      c.drawPath(drop, _fill(const Color(0xFF81D4FA)));
      c.drawPath(drop, _stroke(const Color(0xFF0277BD), u * 0.03));
    }
  }

  // ----------------------------------------------------------------- Eyes

  void _eyes(Canvas c, double u, {required Color iris, required bool round, required Color line}) {
    for (final s in [-1.0, 1.0]) {
      final centre = Offset(s * 0.36 * u, -0.12 * u);
      switch (mood) {
        case AnimalMood.happy:
          c.drawPath(
            Path()
              ..moveTo(centre.dx - 0.14 * u, centre.dy + 0.04 * u)
              ..quadraticBezierTo(
                  centre.dx, centre.dy - 0.14 * u, centre.dx + 0.14 * u, centre.dy + 0.04 * u),
            _stroke(line, u * 0.07),
          );
          continue;
        case AnimalMood.dizzy:
          final p = _stroke(line, u * 0.06);
          const k = 0.1;
          c.drawLine(centre + Offset(-k * u, -k * u), centre + Offset(k * u, k * u), p);
          c.drawLine(centre + Offset(k * u, -k * u), centre + Offset(-k * u, k * u), p);
          continue;
        default:
      }

      final big = mood == AnimalMood.scared || mood == AnimalMood.alert || mood == AnimalMood.roar;
      final w = (big ? 0.38 : 0.32) * u;
      final h = (big ? 0.34 : 0.27) * u;
      final open = mood == AnimalMood.scared ? 1.0 : _eyeOpen;

      c.save();
      c.translate(centre.dx, centre.dy);
      c.scale(1, open);
      final eye = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      final eyePath = Path()..addOval(eye);
      c.save();
      c.clipPath(eyePath);
      if (mood == AnimalMood.hunting || mood == AnimalMood.sad) {
        // Heavy upper lids: slanted down towards the nose when hunting,
        // towards the outside when sad.
        final inner = mood == AnimalMood.hunting ? 0.05 : -0.08;
        final outer = mood == AnimalMood.hunting ? -0.06 : 0.04;
        c.clipPath(Path()
          ..moveTo(-s * w, inner * u)
          ..lineTo(s * w, outer * u)
          ..lineTo(s * w, h)
          ..lineTo(-s * w, h)
          ..close());
      }
      c.drawOval(eye, _fill(Colors.white));
      final pupilShift = Offset(look.dx * 0.07 * u, look.dy * 0.05 * u);
      final irisR = (mood == AnimalMood.scared ? 0.1 : 0.12) * u;
      c.drawCircle(pupilShift, irisR, _fill(iris));
      if (round) {
        c.drawCircle(
            pupilShift, irisR * (mood == AnimalMood.hunting ? 0.45 : 0.55), _fill(Colors.black));
      } else {
        // Goats have sideways, letterbox pupils.
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pupilShift, width: irisR * 1.5, height: irisR * 0.5),
            Radius.circular(irisR * 0.25),
          ),
          _fill(Colors.black),
        );
      }
      c.drawCircle(pupilShift + Offset(-0.04 * u, -0.04 * u), 0.03 * u,
          _fill(Colors.white.withValues(alpha: 0.9)));
      c.restore();
      c.drawOval(eye, _stroke(line, math.max(0.8, u * 0.035)));
      c.restore();
    }
  }

  void _brows(Canvas c, double u, Color line) {
    final (inner, outer) = switch (mood) {
      AnimalMood.hunting || AnimalMood.roar => (-0.24, -0.38),
      AnimalMood.scared => (-0.46, -0.36),
      AnimalMood.sad => (-0.36, -0.28),
      _ => (double.nan, double.nan),
    };
    if (inner.isNaN) return;
    final p = _stroke(line, u * 0.06);
    for (final s in [-1.0, 1.0]) {
      c.drawLine(Offset(s * 0.18 * u, inner * u), Offset(s * 0.52 * u, outer * u), p);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.mood != mood || old.look != look || old.isTiger != isTiger;
}
