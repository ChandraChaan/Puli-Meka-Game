/// Geometry of the traditional 23-point Puli Meka board.
///
/// The board is a triangle crossed by a rectangle, exactly as it is drawn
/// with chalk on village floors across Rayalaseema:
///
///                     0
///     1 ---- 2 -- 3 -- 4 -- 5 ---- 6
///     |     /    /      \    \     |
///     7 -- 8 -- 9 ------ 10 -- 11 -- 12
///     |   /    /          \     \    |
///    13 - 14 - 15 -------- 16 -- 17 - 18
///        /    /              \     \
///      19 -- 20 ------------- 21 -- 22
library;

/// A point on the board in layout units: x is in [0, 1] and y is in
/// [0, [boardHeight]].
class BoardPoint {
  final double x;
  final double y;
  const BoardPoint(this.x, this.y);
}

/// A tiger jump from one point, over [over], landing on [to].
class Jump {
  final int over;
  final int to;
  const Jump(this.over, this.to);
}

class Board {
  Board._();

  static const int pointCount = 23;

  /// Height of the board relative to its width.
  static const double boardHeight = 1.3;

  /// Every straight line drawn on the board, as ordered point sequences.
  /// Pieces step between consecutive points; tigers jump over the middle of
  /// three consecutive points.
  static const List<List<int>> lines = [
    // Four lines fanning out from the apex.
    [0, 2, 8, 14, 19],
    [0, 3, 9, 15, 20],
    [0, 4, 10, 16, 21],
    [0, 5, 11, 17, 22],
    // Horizontal rows.
    [1, 2, 3, 4, 5, 6],
    [7, 8, 9, 10, 11, 12],
    [13, 14, 15, 16, 17, 18],
    [19, 20, 21, 22],
    // Outer edges of the side wings.
    [1, 7, 13],
    [6, 12, 18],
  ];

  /// Where the three tigers start: the apex and the two points below it.
  static const List<int> tigerStart = [0, 3, 4];

  static final List<List<int>> neighbours = _buildNeighbours();
  static final List<List<Jump>> jumps = _buildJumps();
  static final List<BoardPoint> positions = _buildPositions();

  static List<List<int>> _buildNeighbours() {
    final result = List.generate(pointCount, (_) => <int>[]);
    for (final line in lines) {
      for (var i = 0; i + 1 < line.length; i++) {
        result[line[i]].add(line[i + 1]);
        result[line[i + 1]].add(line[i]);
      }
    }
    return [for (final n in result) List.unmodifiable(n..sort())];
  }

  static List<List<Jump>> _buildJumps() {
    final result = List.generate(pointCount, (_) => <Jump>[]);
    for (final line in lines) {
      for (var i = 0; i + 2 < line.length; i++) {
        result[line[i]].add(Jump(line[i + 1], line[i + 2]));
        result[line[i + 2]].add(Jump(line[i + 1], line[i]));
      }
    }
    return [for (final j in result) List.unmodifiable(j)];
  }

  static List<BoardPoint> _buildPositions() {
    // Rows sit below the apex; the four apex lines spread out in proportion
    // to their distance from it.
    const rowY = [0.55, 0.8, 1.05, 1.3];
    const baseSpacing = 0.28;
    final result = <BoardPoint>[const BoardPoint(0.5, 0)];
    for (var row = 0; row < 4; row++) {
      final y = rowY[row];
      final spread = y / boardHeight;
      final hasWings = row < 3;
      if (hasWings) result.add(BoardPoint(0, y));
      for (var k = 0; k < 4; k++) {
        result.add(BoardPoint(0.5 + (k - 1.5) * baseSpacing * spread, y));
      }
      if (hasWings) result.add(BoardPoint(1, y));
    }
    return List.unmodifiable(result);
  }
}
