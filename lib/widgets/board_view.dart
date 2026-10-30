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
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final geo = BoardGeometry.fit(constraints.biggest);
      final r = geo.pieceRadius;
      final last = widget.lastMove;
      return Center(
        child: SizedBox.fromSize(
          size: geo.size,
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
                    painter: _BoardPainter(geo, last, widget.arrows),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HighlightPainter(
                      geo: geo,
                      pulse: _pulse,
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
                  AnimatedPositioned(
                    key: ValueKey(piece.id),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    left: geo.point(piece.point).dx - r,
                    top: geo.point(piece.point).dy - r,
                    width: r * 2,
                    height: r * 2,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: PieceToken(
                          isTiger: piece.isTiger,
                          lifted: piece.point == widget.selected,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// A round playing piece: a tiger or a goat.
class PieceToken extends StatelessWidget {
  final bool isTiger;
  final bool lifted;
  const PieceToken({super.key, required this.isTiger, this.lifted = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.2, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale * (lifted ? 1.12 : 1),
        child: child,
      ),
      child: LayoutBuilder(builder: (context, c) {
        final d = c.biggest.shortestSide;
        return DecoratedBox(
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
  }
}

/// A goat being snatched: it fades and a red ring bursts outwards.
class _CaptureBurst extends StatelessWidget {
  final Offset center;
  final double radius;
  const _CaptureBurst({super.key, required this.center, required this.radius});

  @override
  Widget build(BuildContext context) {
    final size = radius * 5;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOut,
          builder: (context, t, _) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: radius * 2 * (1 + t * 1.4),
                height: radius * 2 * (1 + t * 1.4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.kumkum.withValues(alpha: 1 - t),
                    width: radius * 0.3 * (1 - t) + 1,
                  ),
                ),
              ),
              Opacity(
                opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -radius * 1.2 * t),
                  child: SizedBox(
                    width: radius * 2,
                    height: radius * 2,
                    child: const PieceToken(isTiger: false),
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

class _BoardPainter extends CustomPainter {
  final BoardGeometry geo;
  final Move? lastMove;
  final List<(int, int)> arrows;

  _BoardPainter(this.geo, this.lastMove, this.arrows);

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
    for (final l in Board.lines) {
      final a = geo.point(l.first);
      final b = geo.point(l.last);
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
    final pointPaint = Paint()..color = AppColors.chalk;
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
      old.geo.unit != geo.unit || old.lastMove != lastMove || old.arrows != arrows;
}

class _HighlightPainter extends CustomPainter {
  final BoardGeometry geo;
  final Animation<double> pulse;
  final int? selected;
  final List<Move> destinations;
  final Set<int> movable;
  final Set<int> threatened;
  final Set<int> placementTargets;
  final Move? hint;

  _HighlightPainter({
    required this.geo,
    required this.pulse,
    required this.selected,
    required this.destinations,
    required this.movable,
    required this.threatened,
    required this.placementTargets,
    required this.hint,
  }) : super(repaint: pulse);

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
  }

  @override
  bool shouldRepaint(_HighlightPainter old) => true;
}
