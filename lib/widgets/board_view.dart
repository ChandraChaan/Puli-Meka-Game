import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/board.dart';
import '../game/game_controller.dart';
import '../game/puli_meka.dart';
import '../theme.dart';

/// Converts board layout units to pixels for a given size.
class BoardGeometry {
  final double unit;
  final double pad;
  final double pieceRadius;

  BoardGeometry._(this.unit, this.pad, this.pieceRadius);

  static const double _radiusFactor = 0.052;
  static const double _padFactor = 0.085;

  /// The largest board that fits in [size].
  factory BoardGeometry.fit(Size size) {
    final unit = math.min(
      size.width / (1 + 2 * _padFactor),
      size.height / (Board.boardHeight + 2 * _padFactor),
    );
    return BoardGeometry._(unit, unit * _padFactor, unit * _radiusFactor);
  }

  Size get size => Size(unit + 2 * pad, unit * Board.boardHeight + 2 * pad);

  Offset point(int i) {
    final p = Board.positions[i];
    return Offset(pad + p.x * unit, pad + p.y * unit);
  }

  /// The point nearest to [pos] if it is close enough to count as a tap.
  int? hitTest(Offset pos) {
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < Board.pointCount; i++) {
      final d = (point(i) - pos).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return bestDist <= pieceRadius * 1.7 ? best : null;
  }
}

/// How long a tiger's leap over a goat takes. The goat is taken halfway.
const Duration jumpDuration = Duration(milliseconds: 440);
const Duration _stepDuration = Duration(milliseconds: 300);

/// The Puli Meka board with animated pieces and move highlights.
class BoardView extends StatefulWidget {
  final List<Piece> pieces;
  final int? selected;
  final List<Move> destinations;
  final Set<int> movable;
  final Set<int> threatened;
  final Move? lastMove;
  final Move? hint;
  final bool showPlacementTargets;
  final ValueChanged<int>? onTapPoint;

  /// Screen-reader description of each point.
  final String Function(int point)? pointLabel;

  /// Extra arrows to draw, used by the rules diagrams.
  final List<(int, int)> arrows;

  /// Changes whenever a move is made, so capture effects replay.
  final int moveNumber;

  /// A tap that was not allowed: the point tapped, and the piece to shake.
  /// [rejectSerial] changes on every rejected tap so the effect replays.
  final int? rejectPoint;
  final int? rejectPiece;
  final int rejectSerial;

  /// The winning side, whose pieces dance once the game is over.
  final Side? celebrate;

  /// Whether the game is over, which dims the losing side.
  final bool gameOver;

  const BoardView({
    super.key,
    required this.pieces,
    this.selected,
    this.destinations = const [],
    this.movable = const {},
    this.threatened = const {},
    this.lastMove,
    this.hint,
    this.showPlacementTargets = false,
    this.onTapPoint,
    this.pointLabel,
    this.arrows = const [],
    this.moveNumber = 0,
    this.rejectPoint,
    this.rejectPiece,
    this.rejectSerial = 0,
    this.celebrate,
    this.gameOver = false,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  /// Chalk lines drawing themselves when the board first appears.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// The board jolting as a tiger lands on a goat.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// A wrong tap: the piece shakes its head and the point flashes red.
  late final AnimationController _reject = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  /// Drives the winners' victory hops.
  late final AnimationController _dance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _reduceMotion = false;
  bool _introStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_introStarted) {
      _introStarted = true;
      if (_reduceMotion) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    }
    _syncDance();
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    final last = widget.lastMove;
    if (widget.moveNumber > old.moveNumber && last != null && last.isCapture && !_reduceMotion) {
      _shake.forward(from: 0);
    }
    if (widget.rejectSerial != old.rejectSerial && widget.rejectPoint != null) {
      _reject.forward(from: 0);
    }
    _syncDance();
  }

  void _syncDance() {
    final dance = widget.celebrate != null && !_reduceMotion;
    if (dance && !_dance.isAnimating) {
      _dance.repeat();
    } else if (!dance && _dance.isAnimating) {
      _dance
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _intro.dispose();
    _shake.dispose();
    _reject.dispose();
    _dance.dispose();
    super.dispose();
  }

  /// Sideways jolt of the whole board, starting when the goat is taken.
  Offset _shakeOffset(double r) {
    const start = 0.35; // About when the tiger is over the goat.
    final t = ((_shake.value - start) / (1 - start)).clamp(0.0, 1.0);
    if (t == 0 || t == 1) return Offset.zero;
    final fade = 1 - t;
    return Offset(
      math.sin(t * math.pi * 7) * r * 0.22 * fade,
      math.cos(t * math.pi * 5) * r * 0.12 * fade,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final geo = BoardGeometry.fit(constraints.biggest);
      final r = geo.pieceRadius;
      final last = widget.lastMove;
      final tigers = [for (final p in widget.pieces) if (p.isTiger) p.id]..sort();
      return Center(
        child: SizedBox.fromSize(
          size: geo.size,
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) =>
                Transform.translate(offset: _shakeOffset(r), child: child),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.onTapPoint == null
                  ? null
                  : (d) {
                      final p = geo.hitTest(d.localPosition);
                      if (p != null) widget.onTapPoint!(p);
                    },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BoardPainter(geo, last, widget.arrows, _intro),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HighlightPainter(
                        geo: geo,
                        pulse: _pulse,
                        reject: _reject,
                        rejectPoint: widget.rejectPoint,
                        selected: widget.selected,
                        destinations: widget.destinations,
                        movable: widget.movable,
                        threatened: widget.threatened,
                        hint: widget.hint,
                        placementTargets: widget.showPlacementTargets
                            ? {
                                for (var i = 0; i < Board.pointCount; i++)
                                  if (!widget.pieces.any((p) => p.point == i)) i,
                              }
                            : const {},
                      ),
                    ),
                  ),
                  if (last != null && last.isCapture)
                    _CaptureBurst(
                      key: ValueKey('burst${widget.moveNumber}'),
                      center: geo.point(last.captured),
                      radius: r,
                    ),
                  if (widget.pointLabel != null)
                    for (var i = 0; i < Board.pointCount; i++)
                      Positioned(
                        left: geo.point(i).dx - r,
                        top: geo.point(i).dy - r,
                        width: r * 2,
                        height: r * 2,
                        child: Semantics(
                          button: true,
                          label: widget.pointLabel!(i),
                          onTap: widget.onTapPoint == null ? null : () => widget.onTapPoint!(i),
                        ),
                      ),
                  for (final piece in widget.pieces)
                    _BoardPiece(
                      key: ValueKey(piece.id),
                      piece: piece,
                      geo: geo,
                      lifted: piece.point == widget.selected,
                      leaping: last != null &&
                          last.isCapture &&
                          last.to == piece.point &&
                          piece.isTiger,
                      // Tigers drop in one by one as a new game is laid out.
                      entryDelay: piece.isTiger && widget.moveNumber == 0
                          ? Duration(milliseconds: 350 + 160 * tigers.indexOf(piece.id))
                          : Duration.zero,
                      reduceMotion: _reduceMotion,
                      reject: piece.point == widget.rejectPiece ? _reject : null,
                      dance: widget.celebrate != null &&
                              (widget.celebrate == Side.tiger) == piece.isTiger
                          ? _dance
                          : null,
                      dancePhase: (piece.point % 5) / 5,
                      dimmed: widget.gameOver &&
                          widget.celebrate != null &&
                          (widget.celebrate == Side.tiger) != piece.isTiger,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// A piece on the board. It slides along a line for a step, leaps in an arc
/// over a captured goat, drops in when placed, and shakes on a wrong tap.
class _BoardPiece extends StatefulWidget {
  final Piece piece;
  final BoardGeometry geo;
  final bool lifted;
  final bool leaping;
  final Duration entryDelay;
  final bool reduceMotion;
  final Animation<double>? reject;
  final Animation<double>? dance;
  final double dancePhase;
  final bool dimmed;

  const _BoardPiece({
    super.key,
    required this.piece,
    required this.geo,
    required this.lifted,
    required this.leaping,
    required this.entryDelay,
    required this.reduceMotion,
    required this.reject,
    required this.dance,
    required this.dancePhase,
    required this.dimmed,
  });

  @override
  State<_BoardPiece> createState() => _BoardPieceState();
}

class _BoardPieceState extends State<_BoardPiece> with TickerProviderStateMixin {
  late int _from = widget.piece.point;
  late int _to = widget.piece.point;
  bool _leap = false;

  late final AnimationController _move = AnimationController(vsync: this, value: 1);
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _enter.value = 1;
    } else if (widget.entryDelay == Duration.zero) {
      _enter.forward();
    } else {
      Future<void>.delayed(widget.entryDelay, () {
        if (mounted) _enter.forward();
      });
    }
  }

  @override
  void didUpdateWidget(_BoardPiece old) {
    super.didUpdateWidget(old);
    // Pieces are moved in place, so compare with where this one was headed.
    final point = widget.piece.point;
    if (point != _to) {
      _from = _to;
      _to = point;
      _leap = widget.leaping;
      _move.duration = widget.reduceMotion
          ? const Duration(milliseconds: 1)
          : _leap
              ? jumpDuration
              : _stepDuration;
      _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geo = widget.geo;
    final r = geo.pieceRadius;
    final reject = widget.reject;
    final dance = widget.dance;
    return AnimatedBuilder(
      animation: Listenable.merge([_move, _enter, if (reject != null) reject, if (dance != null) dance]),
      builder: (context, child) {
        final raw = _move.value;
        final t = (_leap ? Curves.easeInOutSine : Curves.easeInOutCubic).transform(raw);
        final ground = Offset.lerp(geo.point(_from), geo.point(_to), t)!;

        // Height above the board, in pixels.
        var lift = 0.0;
        var scale = 1.0;
        if (_leap && raw < 1) {
          final arc = math.sin(math.pi * raw);
          lift = arc * (geo.point(_to) - geo.point(_from)).distance * 0.32;
          scale = 1 + 0.22 * arc;
        }

        // Dropping in when placed: fall from above and bounce.
        final e = _enter.value;
        lift += (1 - Curves.bounceOut.transform(e)) * r * 2.4;
        final opacity = (e * 5).clamp(0.0, 1.0);

        var dx = 0.0;
        if (reject != null && reject.value > 0 && reject.value < 1) {
          final v = reject.value;
          dx = math.sin(v * math.pi * 6) * (1 - v) * r * 0.4;
        }

        if (dance != null) {
          final hop = math.sin(2 * math.pi * (dance.value + widget.dancePhase));
          lift += math.max(0, hop) * r * 0.55;
          scale *= 1 + math.max(0, hop) * 0.06;
        }

        final shadowAlpha = (lift / (r * 3)).clamp(0.0, 1.0);
        return Positioned(
          left: ground.dx - r,
          top: ground.dy - r,
          width: r * 2,
          height: r * 2,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: opacity * (widget.dimmed ? 0.5 : 1),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (lift > 0.5)
                      // Shadow left on the board while the piece is in the air.
                      Positioned.fill(
                        child: Transform.scale(
                          scaleX: 1 - 0.3 * shadowAlpha,
                          scaleY: 0.45 * (1 - 0.3 * shadowAlpha),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.35 * (1 - shadowAlpha * 0.5)),
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(dx, -lift),
                        child: Transform.scale(scale: scale, child: child),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: PieceToken(isTiger: widget.piece.isTiger, lifted: widget.lifted, animateIn: false),
    );
  }
}

/// A round playing piece: a tiger or a goat.
class PieceToken extends StatelessWidget {
  final bool isTiger;
  final bool lifted;

  /// Whether the token pops in when first shown.
  final bool animateIn;

  const PieceToken({super.key, required this.isTiger, this.lifted = false, this.animateIn = true});

  @override
  Widget build(BuildContext context) {
    final token = AnimatedScale(
      scale: lifted ? 1.14 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      child: LayoutBuilder(builder: (context, c) {
        final d = c.biggest.shortestSide;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: isTiger
                  ? const [Color(0xFFFFD180), AppColors.tigerOrange, AppColors.tigerDeep]
                  : const [Colors.white, AppColors.goatCream, Color(0xFFD7C4A0)],
              stops: const [0, 0.55, 1],
            ),
            border: Border.all(
              color: isTiger ? const Color(0xFF4E2100) : const Color(0xFF6D4C2F),
              width: math.max(1.5, d * 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: lifted ? d * 0.35 : d * 0.15,
                offset: Offset(0, lifted ? d * 0.15 : d * 0.06),
              ),
            ],
          ),
          child: Center(
            child: Text(
              isTiger ? '🐯' : '🐐',
              style: TextStyle(fontSize: d * 0.55, height: 1.1),
              textScaler: TextScaler.noScaling,
            ),
          ),
        );
      }),
    );
    if (!animateIn) return token;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.2, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: token,
    );
  }
}

/// A goat being snatched. It stands until the leaping tiger is over it,
/// then is tossed up and fades while a red ring and dust burst outwards.
class _CaptureBurst extends StatelessWidget {
  final Offset center;
  final double radius;
  const _CaptureBurst({super.key, required this.center, required this.radius});

  static const _total = Duration(milliseconds: 1100);

  @override
  Widget build(BuildContext context) {
    final size = radius * 6;
    // The fraction of [_total] at which the tiger is over the goat.
    final hit = jumpDuration.inMilliseconds / 2 / _total.inMilliseconds;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: _total,
          builder: (context, raw, _) {
            final t = Curves.easeOut.transform(((raw - hit) / (1 - hit)).clamp(0.0, 1.0));
            final started = raw >= hit;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (started) ...[
                  Container(
                    width: radius * 2 * (1 + t * 1.6),
                    height: radius * 2 * (1 + t * 1.6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.kumkum.withValues(alpha: 1 - t),
                        width: radius * 0.3 * (1 - t) + 1,
                      ),
                    ),
                  ),
                  // Puffs of dust thrown out from the impact.
                  for (var i = 0; i < 8; i++)
                    Transform.translate(
                      offset: Offset.fromDirection(
                        i * math.pi / 4 + 0.3,
                        radius * (0.6 + 1.9 * t),
                      ),
                      child: Container(
                        width: radius * 0.32 * (1 - t) + 1,
                        height: radius * 0.32 * (1 - t) + 1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (i.isEven ? AppColors.chalk : AppColors.turmeric)
                              .withValues(alpha: (1 - t) * 0.9),
                        ),
                      ),
                    ),
                ],
                Opacity(
                  opacity: (1 - t * 1.3).clamp(0.0, 1.0),
                  child: Transform.translate(
                    // Knocked up and away, spinning.
                    offset: Offset(radius * 0.9 * t, -radius * 2.2 * t + radius * 1.4 * t * t),
                    child: Transform.rotate(
                      angle: t * math.pi * 0.9,
                      child: SizedBox(
                        width: radius * 2,
                        height: radius * 2,
                        child: const PieceToken(isTiger: false, animateIn: false),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final BoardGeometry geo;
  final Move? lastMove;
  final List<(int, int)> arrows;

  /// 0 to 1 as the chalk lines are drawn in.
  final Animation<double> reveal;

  _BoardPainter(this.geo, this.lastMove, this.arrows, this.reveal) : super(repaint: reveal);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(geo.unit * 0.05));

    // Red-oxide floor.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.1,
          colors: [Color(0xFFA63A25), AppColors.redOxide, Color(0xFF6A2215)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );

    // Muggulu-style double border with dots.
    final borderPaint = Paint()
      ..color = AppColors.chalk.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = geo.unit * 0.006;
    final inset = geo.pad * 0.28;
    canvas.drawRRect(rr.deflate(inset), borderPaint);
    canvas.drawRRect(rr.deflate(inset * 1.8), borderPaint);
    final dotPaint = Paint()..color = AppColors.chalk.withValues(alpha: 0.35);
    final inner = rect.deflate(inset * 1.4);
    const dots = 14;
    for (var i = 0; i <= dots; i++) {
      final x = inner.left + inner.width * i / dots;
      canvas.drawCircle(Offset(x, inner.top), geo.unit * 0.006, dotPaint);
      canvas.drawCircle(Offset(x, inner.bottom), geo.unit * 0.006, dotPaint);
    }

    // Chalk lines: a soft halo, then the line itself.
    final halo = Paint()
      ..color = AppColors.chalk.withValues(alpha: 0.12)
      ..strokeWidth = geo.unit * 0.03
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = AppColors.chalk.withValues(alpha: 0.92)
      ..strokeWidth = geo.unit * 0.011
      ..strokeCap = StrokeCap.round;
    final shown = Curves.easeOutCubic.transform(reveal.value);
    for (var i = 0; i < Board.lines.length; i++) {
      final l = Board.lines[i];
      // Each line starts a little after the one before.
      final stagger = i / Board.lines.length * 0.5;
      final f = ((shown - stagger) / 0.5).clamp(0.0, 1.0);
      if (f == 0) continue;
      final a = geo.point(l.first);
      final b = Offset.lerp(a, geo.point(l.last), f)!;
      canvas.drawLine(a, b, halo);
      canvas.drawLine(a, b, line);
    }

    // Trail of the last move.
    final m = lastMove;
    if (m != null && !m.isPlacement) {
      final trail = Paint()
        ..color = AppColors.turmeric.withValues(alpha: 0.75)
        ..strokeWidth = geo.unit * 0.022
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(geo.point(m.from), geo.point(m.to), trail);
      canvas.drawCircle(
        geo.point(m.from),
        geo.pieceRadius * 0.35,
        Paint()..color = AppColors.turmeric.withValues(alpha: 0.6),
      );
    }

    // Points.
    final pointPaint = Paint()..color = AppColors.chalk.withValues(alpha: shown);
    for (var i = 0; i < Board.pointCount; i++) {
      canvas.drawCircle(geo.point(i), geo.unit * 0.02, pointPaint);
    }

    for (final (from, to) in arrows) {
      _drawArrow(canvas, geo.point(from), geo.point(to));
    }
  }

  void _drawArrow(Canvas canvas, Offset a, Offset b) {
    final paint = Paint()
      ..color = AppColors.turmeric
      ..strokeWidth = geo.unit * 0.018
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dir = (b - a) / (b - a).distance;
    final normal = Offset(-dir.dy, dir.dx);
    final bulge = (b - a).distance * 0.25;
    final start = a + dir * geo.pieceRadius * 1.1;
    final end = b - dir * geo.pieceRadius * 1.1;
    final control = (a + b) / 2 + normal * bulge;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
      paint,
    );
    final tangent = (end - control) / (end - control).distance;
    final side = Offset(-tangent.dy, tangent.dx);
    final head = geo.pieceRadius * 0.6;
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo((end - tangent * head + side * head * 0.6).dx,
            (end - tangent * head + side * head * 0.6).dy)
        ..lineTo((end - tangent * head - side * head * 0.6).dx,
            (end - tangent * head - side * head * 0.6).dy)
        ..close(),
      Paint()..color = AppColors.turmeric,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.geo.unit != geo.unit ||
      old.lastMove != lastMove ||
      old.arrows != arrows ||
      old.reveal != reveal;
}

class _HighlightPainter extends CustomPainter {
  final BoardGeometry geo;
  final Animation<double> pulse;
  final Animation<double> reject;
  final int? rejectPoint;
  final int? selected;
  final List<Move> destinations;
  final Set<int> movable;
  final Set<int> threatened;
  final Set<int> placementTargets;
  final Move? hint;

  _HighlightPainter({
    required this.geo,
    required this.pulse,
    required this.reject,
    required this.rejectPoint,
    required this.selected,
    required this.destinations,
    required this.movable,
    required this.threatened,
    required this.placementTargets,
    required this.hint,
  }) : super(repaint: Listenable.merge([pulse, reject]));

  @override
  void paint(Canvas canvas, Size size) {
    final r = geo.pieceRadius;
    final t = Curves.easeInOut.transform(pulse.value);

    Paint ring(Color c, double width, [double alpha = 1]) => Paint()
      ..color = c.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    for (final p in placementTargets) {
      canvas.drawCircle(
          geo.point(p), r * (0.5 + 0.08 * t), ring(AppColors.chalk, r * 0.1, 0.35 + 0.25 * t));
    }

    for (final p in movable) {
      if (p == selected) continue;
      canvas.drawCircle(
          geo.point(p), r * 1.18, ring(AppColors.turmeric, r * 0.12, 0.35 + 0.35 * t));
    }

    final s = selected;
    if (s != null) {
      canvas.drawCircle(
        geo.point(s),
        r * 1.45,
        Paint()
          ..color = AppColors.turmeric.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
      );
      canvas.drawCircle(geo.point(s), r * 1.22, ring(AppColors.turmeric, r * 0.16));
    }

    for (final m in destinations) {
      final c = geo.point(m.to);
      if (m.isCapture) {
        canvas.drawCircle(
            c, r * (0.55 + 0.15 * t), Paint()..color = AppColors.kumkum.withValues(alpha: 0.85));
        canvas.drawCircle(geo.point(m.captured), r * 1.25, ring(AppColors.kumkum, r * 0.16));
      } else {
        canvas.drawCircle(
            c, r * (0.38 + 0.1 * t), Paint()..color = AppColors.leafLight.withValues(alpha: 0.9));
        canvas.drawCircle(c, r * (0.75 + 0.15 * t), ring(AppColors.leafLight, r * 0.08, 0.6));
      }
    }

    for (final p in threatened) {
      canvas.drawCircle(
          geo.point(p), r * (1.15 + 0.15 * t), ring(AppColors.kumkum, r * 0.14, 0.5 + 0.5 * t));
    }

    final h = hint;
    if (h != null) {
      final hp = ring(AppColors.hint, r * 0.18, 0.6 + 0.4 * t);
      if (!h.isPlacement) canvas.drawCircle(geo.point(h.from), r * 1.3, hp);
      canvas.drawCircle(geo.point(h.to), r * (0.7 + 0.2 * t), hp);
      canvas.drawCircle(geo.point(h.to), r * 0.3, Paint()..color = AppColors.hint);
    }

    // A wrong tap: a red cross that flashes and fades.
    final rp = rejectPoint;
    final rv = reject.value;
    if (rp != null && rv > 0 && rv < 1) {
      final c = geo.point(rp);
      final a = (1 - rv) * 0.9;
      final size = r * (0.45 + 0.15 * rv);
      final cross = Paint()
        ..color = AppColors.kumkum.withValues(alpha: a)
        ..strokeWidth = r * 0.18
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + Offset(-size, -size), c + Offset(size, size), cross);
      canvas.drawLine(c + Offset(size, -size), c + Offset(-size, size), cross);
      canvas.drawCircle(c, r * (0.9 + 0.4 * rv), ring(AppColors.kumkum, r * 0.1, a * 0.7));
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) => true;
}
