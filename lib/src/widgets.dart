/// Board, piece and komadai widgets — Japanese craft material language.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'engine.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Piece
// ---------------------------------------------------------------------------

/// Pentagonal wedge path for a piece pointing up, inside [rect].
Path piecePath(Rect rect) {
  final cx = rect.center.dx;
  final y = rect.top, h = rect.height, w = rect.width;
  return Path()
    ..moveTo(cx, y + h * 0.03) // tip
    ..lineTo(cx - w * 0.36, y + h * 0.30)
    ..lineTo(cx - w * 0.42, y + h * 0.96)
    ..lineTo(cx + w * 0.42, y + h * 0.96)
    ..lineTo(cx + w * 0.36, y + h * 0.30)
    ..close();
}

class _PiecePainter extends CustomPainter {
  final int piece; // color * type
  final PieceWood wood;
  _PiecePainter({required this.piece, required this.wood});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = pType(piece);
    final promoted = t > ptPawn;
    // Gote pieces point toward sente (down) — rotate the whole piece.
    canvas.save();
    if (pColor(piece) == gote) {
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(pi);
      canvas.translate(-rect.center.dx, -rect.center.dy);
    }
    // Contact shadow.
    final path = piecePath(rect);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.45), 5, false);
    // Lacquered wood fill (subtle vertical shading).
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [wood.hi, wood.base, wood.deep],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, fill);
    // Wood grain flick.
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, size.width * 0.012)
      ..color = wood.grain.withValues(alpha: 0.6);
    final cx = rect.center.dx;
    canvas.drawPath(
      Path()
        ..moveTo(cx - size.width * 0.12, size.height * 0.34)
        ..quadraticBezierTo(cx + size.width * 0.05, size.height * 0.6,
            cx - size.width * 0.06, size.height * 0.9),
      grain,
    );
    // Top-edge light catch.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, size.width * 0.02)
      ..color = wood.hi.withValues(alpha: 0.9);
    canvas.drawPath(
      Path()
        ..moveTo(cx, rect.top + size.height * 0.03)
        ..lineTo(cx - size.width * 0.36, rect.top + size.height * 0.30)
        ..moveTo(cx, rect.top + size.height * 0.03)
        ..lineTo(cx + size.width * 0.36, rect.top + size.height * 0.30),
      edge,
    );
    // Outline.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, size.width * 0.018)
        ..color = wood.deep.withValues(alpha: 0.9),
    );
    // Kanji (the whole canvas is already rotated for gote).
    final kanji = t == ptKing && pColor(piece) == gote
        ? '玉'
        : (kanjiFace[t] ?? '?');
    canvas.save();
    canvas.translate(cx, rect.center.dy + size.height * 0.06);
    final tp = TextPainter(
      text: TextSpan(
        text: kanji,
        style: TextStyle(
          fontSize: size.width * (t == ptTokin ? 0.40 : 0.44),
          fontWeight: FontWeight.w800,
          color: promoted ? ShogiPalette.vermilion : wood.kanji,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    canvas.restore(); // gote rotation
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) =>
      old.piece != piece || old.wood != wood;
}

/// A single lacquered shogi piece.
class ShogiPiece extends StatelessWidget {
  final int piece;
  final double size;
  final PieceWood wood;
  const ShogiPiece(
      {super.key, required this.piece, required this.size, required this.wood});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PiecePainter(piece: piece, wood: wood),
    );
  }
}

// ---------------------------------------------------------------------------
// Board layout + painter
// ---------------------------------------------------------------------------

/// Shared geometry between painter and hit-testing.
class BoardLayout {
  final Size size;
  final bool showCoords;
  late final double margin;
  late final double gridLeft;
  late final double gridTop;
  late final double cell;

  BoardLayout(this.size, {required this.showCoords}) {
    margin = size.width * 0.045;
    final coord = showCoords ? size.width * 0.052 : 0.0;
    final availW = size.width - margin * 2 - coord; // right strip for ranks
    final availH = size.height - margin * 2 - coord; // top strip for files
    final grid = min(availW, availH);
    gridLeft = margin + (availW - grid) / 2;
    gridTop = margin + coord + (availH - grid) / 2;
    cell = grid / 9;
  }

  Rect squareRect(int sq) {
    final r = sq ~/ 9, c = sq % 9;
    return Rect.fromLTWH(
        gridLeft + c * cell, gridTop + r * cell, cell, cell);
  }

  int? squareAt(Offset p) {
    final c = ((p.dx - gridLeft) / cell).floor();
    final r = ((p.dy - gridTop) / cell).floor();
    if (r < 0 || r > 8 || c < 0 || c > 8) return null;
    return r * 9 + c;
  }
}

/// View-model for the board painter.
class BoardView {
  final List<int> board;
  final int? selected;
  final Set<int> targets;
  final Set<int> captureTargets;
  final int? lastFrom;
  final int? lastTo;
  final int? checkSquare;
  final bool showCoords;
  final PieceWood wood;
  final BoardWood boardWood;
  // Move animation.
  final ShogiMove? animMove;
  final int animPiece; // piece int being animated (pre-move value)
  final double animT; // 0..1
  // Invalid-move shake.
  final int? shakeSquare;
  final double shakeT; // 0..1
  const BoardView({
    required this.board,
    required this.wood,
    required this.boardWood,
    this.selected,
    this.targets = const {},
    this.captureTargets = const {},
    this.lastFrom,
    this.lastTo,
    this.checkSquare,
    this.showCoords = true,
    this.animMove,
    this.animPiece = 0,
    this.animT = 1,
    this.shakeSquare,
    this.shakeT = 1,
  });
}

class ShogiBoard extends StatelessWidget {
  final BoardView view;
  final ValueChanged<int> onTapSquare;
  const ShogiBoard({super.key, required this.view, required this.onTapSquare});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);
            // Center the square area.
            final dx = (constraints.maxWidth - side) / 2;
            final dy = (constraints.maxHeight - side) / 2;
            final layout = BoardLayout(Size(side, side),
                showCoords: view.showCoords);
            final sq = layout.squareAt(local - Offset(dx, dy));
            if (sq != null) onTapSquare(sq);
          },
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: CustomPaint(
                size: Size(side, side),
                painter: _TranslatingBoardPainter(view),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Board painter: draws slab, grid, highlights and pieces.
class _TranslatingBoardPainter extends CustomPainter {
  final BoardView view;
  _TranslatingBoardPainter(this.view);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = BoardLayout(size, showCoords: view.showCoords);
    final bw = view.boardWood;
    final slab = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(slab, Paint()..color = bw.edge);
    // Drop shadow under slab.
    // (Shadow drawn first so the slab sits on the tatami.)
    final face = RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 5, size.width - 10, size.height - 10),
        const Radius.circular(7));
    canvas.drawRRect(face, Paint()..color = bw.face);
    final rng = Random(11);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = bw.edge.withValues(alpha: 0.20);
    for (int i = 0; i < 12; i++) {
      final y = 8 + rng.nextDouble() * (size.height - 16);
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y + 6), grain);
    }
    // Coordinates.
    if (view.showCoords) {
      const ranks = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
      for (int c = 0; c < 9; c++) {
        _label(canvas, '${9 - c}', layout, c, -1);
      }
      for (int r = 0; r < 9; r++) {
        _label(canvas, ranks[r], layout, 9, r);
      }
    }
    // Grid.
    final gridPaint = Paint()
      ..color = bw.grid
      ..strokeWidth = max(1, layout.cell * 0.022);
    for (int i = 0; i <= 9; i++) {
      final x = layout.gridLeft + i * layout.cell;
      canvas.drawLine(Offset(x, layout.gridTop),
          Offset(x, layout.gridTop + layout.cell * 9), gridPaint);
      final y = layout.gridTop + i * layout.cell;
      canvas.drawLine(Offset(layout.gridLeft, y),
          Offset(layout.gridLeft + layout.cell * 9, y), gridPaint);
    }
    final hoshi = Paint()..color = bw.grid;
    for (final s in [2 * 9 + 2, 2 * 9 + 6, 6 * 9 + 2, 6 * 9 + 6]) {
      canvas.drawCircle(layout.squareRect(s).center,
          max(2, layout.cell * 0.045), hoshi);
    }
    // Last move wash.
    final wash = Paint()
      ..color = ShogiPalette.emberGold.withValues(alpha: 0.28);
    for (final s in [view.lastFrom, view.lastTo]) {
      if (s != null) canvas.drawRect(layout.squareRect(s), wash);
    }
    if (view.selected != null) {
      final rc = layout.squareRect(view.selected!);
      canvas.drawRect(
          rc, Paint()..color = ShogiPalette.vermilion.withValues(alpha: 0.18));
      canvas.drawRect(
          rc,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = ShogiPalette.vermilion);
    }
    if (view.checkSquare != null) {
      final rc = layout.squareRect(view.checkSquare!);
      final glow = Paint()
        ..color = ShogiPalette.vermilion.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(rc.center, layout.cell * 0.44, glow);
      canvas.drawCircle(
          rc.center,
          layout.cell * 0.44,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = ShogiPalette.vermilion);
    }
    for (final s in view.targets) {
      final rc = layout.squareRect(s);
      if (view.captureTargets.contains(s)) {
        canvas.drawCircle(
            rc.center,
            layout.cell * 0.44,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = ShogiPalette.vermilion.withValues(alpha: 0.85));
      } else {
        canvas.drawCircle(rc.center, layout.cell * 0.13,
            Paint()..color = ShogiPalette.vermilion.withValues(alpha: 0.8));
      }
    }
    // Pieces.
    final animatingTo =
        (view.animT < 1 && view.animMove != null) ? view.animMove!.to : -1;
    for (int i = 0; i < 81; i++) {
      if (i == animatingTo) continue;
      final p = view.board[i];
      if (p == 0) continue;
      final rc = layout.squareRect(i).deflate(layout.cell * 0.07);
      Offset off = Offset.zero;
      if (view.shakeSquare == i && view.shakeT < 1) {
        off = Offset(sin(view.shakeT * pi * 4) * (1 - view.shakeT) * 7, 0);
      }
      _pieceAt(canvas, rc.shift(off), p);
    }
    // Move animation overlay.
    final am = view.animMove;
    if (am != null && view.animT < 1 && view.animPiece != 0) {
      final t = Curves.easeOut.transform(view.animT);
      if (am.isDrop) {
        final rc =
            layout.squareRect(am.to).deflate(layout.cell * 0.07);
        final s = 0.55 + 0.45 * t;
        final scaled = Rect.fromCenter(
            center: rc.center, width: rc.width * s, height: rc.height * s);
        canvas.save();
        canvas.translate(scaled.left, scaled.top);
        canvas.saveLayer(
            Offset.zero & scaled.size,
            Paint()..color = Colors.white.withValues(alpha: t.clamp(0, 1)));
        _PiecePainter(piece: view.animPiece, wood: view.wood)
            .paint(canvas, scaled.size);
        canvas.restore();
        canvas.restore();
      } else {
        final from = layout.squareRect(am.from).center;
        final to = layout.squareRect(am.to).center;
        final pos = from + (to - from) * t;
        final lift = sin(t * pi) * layout.cell * 0.18;
        final half = layout.cell * 0.43 * (1 + 0.12 * sin(t * pi));
        final rc = Rect.fromCenter(
            center: Offset(pos.dx, pos.dy - lift),
            width: half * 2,
            height: half * 2);
        _pieceAt(canvas, rc, view.animPiece);
      }
    }
  }

  void _pieceAt(Canvas canvas, Rect rc, int piece) {
    canvas.save();
    canvas.translate(rc.left, rc.top);
    _PiecePainter(piece: piece, wood: view.wood)
        .paint(canvas, Size(rc.width, rc.height));
    canvas.restore();
  }

  void _label(
      Canvas canvas, String text, BoardLayout layout, int c, int r) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: layout.cell * 0.30,
              fontWeight: FontWeight.w700,
              color: view.boardWood.grid.withValues(alpha: 0.85))),
      textDirection: TextDirection.ltr,
    )..layout();
    if (r == -1) {
      // file label above column c
      final x = layout.gridLeft + c * layout.cell + layout.cell / 2;
      tp.paint(canvas,
          Offset(x - tp.width / 2, layout.gridTop - layout.cell * 0.44));
    } else {
      // rank label right of row r
      final y = layout.gridTop + r * layout.cell + layout.cell / 2;
      tp.paint(
          canvas,
          Offset(layout.gridLeft + layout.cell * 9 + layout.cell * 0.10,
              y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Komadai (piece stand)
// ---------------------------------------------------------------------------

/// Lacquered tray holding a player's captured pieces (tap to drop).
class Komadai extends StatelessWidget {
  final List<int> hand; // unpromoted types
  final int color;
  final int? selectedType;
  final bool interactive;
  final ValueChanged<int> onTapType;
  final PieceWood wood;
  final String? name;
  const Komadai({
    super.key,
    required this.hand,
    required this.color,
    required this.onTapType,
    required this.wood,
    this.selectedType,
    this.interactive = false,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final t in hand) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    // Display order: R B G S N L P.
    const order = [
      ptRook, ptBishop, ptGold, ptSilver, ptKnight, ptLance, ptPawn
    ];
    final types = order.where(counts.containsKey).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: ShogiMaterials.lacquerPanel(radius: 10),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                color == sente ? '先手' : '後手',
                style: ShogiType.kanji(16, ShogiPalette.washi, spacing: 2),
              ),
              if (name != null && name!.isNotEmpty)
                SizedBox(
                  width: 64,
                  child: Text(
                    name!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ShogiPalette.emberGold, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          if (types.isEmpty)
            Text('—',
                style: ShogiType.body(14, ShogiPalette.warmGray)),
          for (final t in types)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: interactive ? () => onTapType(t) : null,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: selectedType == t
                      ? BoxDecoration(
                          border: Border.all(
                              color: ShogiPalette.vermilion, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: ShogiPalette.vermilion
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        )
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ShogiPiece(
                          piece: color * t, size: 40, wood: wood),
                      if (counts[t]! > 1)
                        Positioned(
                          right: -4,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: ShogiPalette.vermilion,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '×${counts[t]}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
