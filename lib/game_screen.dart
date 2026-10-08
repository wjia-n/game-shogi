import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Mini (goro) shogi on 5x5. Pieces: 1=K 2=R 3=B 4=G 5=S 6=P.
/// +color = black (sente, moves up), -color = white. No promotion.
class ShogiMove {
  final int from; // -1 = drop
  final int to;
  final int drop; // piece type when dropping
  const ShogiMove(this.from, this.to, [this.drop = 0]);
}

class MiniShogi {
  List<int> b = List.filled(25, 0);
  List<int> handB = [], handW = [];
  int turn = 1;

  static const kanji = {1: '王', 2: '飛', 3: '角', 4: '金', 5: '銀', 6: '歩'};
  static const value = {1: 0, 2: 500, 3: 450, 4: 300, 5: 250, 6: 100};

  void reset() {
    b = List.filled(25, 0);
    // white back rank (row 0), white pawns (row 1)
    const back = [2, 3, 5, 4, 1];
    for (int c = 0; c < 5; c++) {
      b[c] = -back[c];
      b[5 + c] = -6;
      b[15 + c] = 6;
      b[20 + c] = back[c];
    }
    handB = []; handW = []; turn = 1;
  }

  MiniShogi clone() {
    final m = MiniShogi();
    m.b = List.of(b);
    m.handB = List.of(handB);
    m.handW = List.of(handW);
    m.turn = turn;
    return m;
  }

  List<int> _hand(int color) => color == 1 ? handB : handW;

  /// Pseudo-legal moves for color (king safety NOT checked).
  List<ShogiMove> pseudoMoves(int color) {
    final moves = <ShogiMove>[];
    for (int i = 0; i < 25; i++) {
      final p = b[i];
      if (p == 0 || p.sign != color) continue;
      final t = p.abs(), r = i ~/ 5, c = i % 5;
      // orient: for black forward = -1 row; for white forward = +1 row.
      final fw = color == 1 ? -1 : 1;
      void stepTo(int nr, int nc) {
        if (nr < 0 || nr > 4 || nc < 0 || nc > 4) return;
        final q = b[nr * 5 + nc];
        if (q == 0 || q.sign != color) moves.add(ShogiMove(i, nr * 5 + nc));
      }
      void slide(List<List<int>> dirs) {
        for (final d in dirs) {
          int nr = r + d[0], nc = c + d[1];
          while (nr >= 0 && nr <= 4 && nc >= 0 && nc <= 4) {
            final q = b[nr * 5 + nc];
            if (q == 0) {
              moves.add(ShogiMove(i, nr * 5 + nc));
            } else {
              if (q.sign != color) moves.add(ShogiMove(i, nr * 5 + nc));
              break;
            }
            nr += d[0]; nc += d[1];
          }
        }
      }
      switch (t) {
        case 1: // king: one step any direction
          for (final d in [[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]]) {
            stepTo(r + d[0], c + d[1]);
          }
          break;
        case 2: slide([[-1,0],[1,0],[0,-1],[0,1]]); break;
        case 3: slide([[-1,-1],[-1,1],[1,-1],[1,1]]); break;
        case 4: // gold: orthogonal + forward diagonals
          for (final d in [[fw,-1],[fw,0],[fw,1],[-1,0],[1,0],[0,-1],[0,1]]) {
            stepTo(r + d[0], c + d[1]);
          }
          break;
        case 5: // silver: diagonals + straight forward
          for (final d in [[fw,-1],[fw,0],[fw,1],[-fw,-1],[-fw,1]]) {
            stepTo(r + d[0], c + d[1]);
          }
          break;
        case 6: // pawn: one step forward (captures straight ahead)
          stepTo(r + fw, c);
          break;
      }
    }
    // drops
    final hand = _hand(color);
    final types = hand.toSet();
    for (final tp in types) {
      for (int sq = 0; sq < 25; sq++) {
        if (b[sq] != 0) continue;
        final r = sq ~/ 5, c = sq % 5;
        if (tp == 6) {
          if ((color == 1 && r == 0) || (color == -1 && r == 4)) continue; // no-move rank
          bool nifu = false;
          for (int rr = 0; rr < 5; rr++) {
            if (b[rr * 5 + c] == color * 6) { nifu = true; break; }
          }
          if (nifu) continue;
        }
        moves.add(ShogiMove(-1, sq, tp));
      }
    }
    return moves;
  }

  int _kingSq(int color) {
    for (int i = 0; i < 25; i++) {
      if (b[i] == color * 1) return i;
    }
    return -1;
  }

  bool inCheck(int color) {
    final k = _kingSq(color);
    if (k < 0) return true;
    for (final m in pseudoMoves(-color)) {
      if (m.to == k) return true;
    }
    return false;
  }

  /// Applies a move; returns captured piece type (0 none). No legality check.
  int apply(ShogiMove m) {
    int captured = 0;
    if (m.drop > 0) {
      _hand(turn).remove(m.drop);
      b[m.to] = turn * m.drop;
    } else {
      final p = b[m.from];
      if (b[m.to] != 0) {
        captured = b[m.to].abs();
        _hand(turn).add(captured);
      }
      b[m.to] = p;
      b[m.from] = 0;
    }
    turn = -turn;
    return captured;
  }

  List<ShogiMove> legalMoves(int color) {
    final out = <ShogiMove>[];
    for (final m in pseudoMoves(color)) {
      final c = clone()..turn = color;
      c.apply(m);
      if (!c.inCheck(color)) out.add(m);
    }
    return out;
  }

  bool get isCheckmate => inCheck(turn) && legalMoves(turn).isEmpty;
  bool get isStalemate => !inCheck(turn) && legalMoves(turn).isEmpty;

  int evaluate(int color) {
    int s = 0;
    for (final p in b) {
      if (p != 0) s += (value[p.abs()] ?? 0) * p.sign * color;
    }
    for (final p in handB) {
      s += (value[p] ?? 0) * color;
    }
    for (final p in handW) {
      s -= (value[p] ?? 0) * color;
    }
    return s;
  }
}

/// 1-ply bot with jitter.
ShogiMove botPick(MiniShogi g, Random rng) {
  final color = g.turn;
  final moves = g.legalMoves(color);
  ShogiMove best = moves.first;
  int bs = -1 << 30;
  for (final m in moves) {
    final c = g.clone()..turn = color;
    c.apply(m);
    int s = c.evaluate(color) + rng.nextInt(60);
    if (c.inCheck(-color)) s += 40;
    if (c.isCheckmate) s += 100000;
    // don't hang the king
    if (c.inCheck(color)) s -= 50000;
    if (s > bs) { bs = s; best = m; }
  }
  return best;
}

class ShogiScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const ShogiScreen({super.key, required this.players, required this.callbacks});

  @override
  State<ShogiScreen> createState() => _ShogiScreenState();
}

class _ShogiScreenState extends State<ShogiScreen> {
  final g = MiniShogi();
  final rng = Random();
  bool over = false;
  int? sel; // selected board square
  int? selDrop; // selected hand piece type
  Map<int, ShogiMove> targets = {}; // to-square -> move
  bool inCheckNow = false;

  List<Player> get ps => widget.players;
  int get turnIdx => g.turn == 1 ? 0 : 1;

  @override
  void initState() {
    super.initState();
    g.reset();
    _refreshCheck();
    _maybeBot();
  }

  void _refreshCheck() => inCheckNow = g.inCheck(g.turn);

  void _maybeBot() {
    if (over || !mounted) return;
    if (ps[turnIdx].isBot) {
      Future.delayed(Duration(milliseconds: 600 + rng.nextInt(400)), () {
        if (!mounted || over || !ps[turnIdx].isBot) return;
        _playMove(botPick(g, rng));
      });
    }
  }

  void _playMove(ShogiMove m) {
    if (over) return;
    g.apply(m);
    Sfx.move();
    sel = null; selDrop = null; targets = {};
    _refreshCheck();
    if (g.isCheckmate) {
      _finish(ps[turnIdx == 0 ? 1 : 0], '👑 Checkmate!');
      return;
    }
    if (g.isStalemate) {
      _finish(null, '🤝 Stalemate — an honorable draw!');
      return;
    }
    widget.callbacks.setActivePlayer(turnIdx);
    setState(() {});
    _maybeBot();
  }

  void _finish(Player? winner, String headline) {
    over = true;
    if (winner != null) {
      Sfx.win();
    } else {
      Sfx.lose();
    }
    widget.callbacks.finish(winner: winner, headline: headline,
        subline: winner == null ? 'Nobody\'s king fell today.' : '${winner.name} captures the crown!');
  }

  void _onSquare(int i) {
    if (over || ps[turnIdx].isBot) return;
    // tap a highlighted target
    if (targets.containsKey(i)) { _playMove(targets[i]!); return; }
    final p = g.b[i];
    if (p != 0 && p.sign == g.turn) {
      // select own piece
      final legal = g.legalMoves(g.turn).where((m) => m.from == i);
      sel = i; selDrop = null;
      targets = {for (final m in legal) m.to: m};
      Sfx.tap();
      setState(() {});
    } else if (selDrop != null && p == 0) {
      final m = g.legalMoves(g.turn).firstWhere(
          (m) => m.from == -1 && m.to == i && m.drop == selDrop,
          orElse: () => const ShogiMove(-2, -2));
      if (m.from != -2) _playMove(m);
    } else {
      sel = null; selDrop = null; targets = {};
      setState(() {});
    }
  }

  void _onHandTap(int tp) {
    if (over || ps[turnIdx].isBot) return;
    final legal = g.legalMoves(g.turn).where((m) => m.from == -1 && m.drop == tp);
    if (legal.isEmpty) return;
    sel = null; selDrop = tp;
    targets = {for (final m in legal) m.to: m};
    Sfx.tap();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Column(
      children: [
        TurnBanner(player: ps[turnIdx],
            action: over ? 'done!' : (inCheckNow ? 'is in CHECK! ⚠️' : 'to move')),
        ScoreChips(players: ps, activeIndex: turnIdx),
        _handTray(t, -1), // white hand on top
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8C87A),
                  borderRadius: t.radius,
                  border: Border.all(color: t.primary.withValues(alpha: .4), width: 3),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
                  itemCount: 25,
                  itemBuilder: (_, i) {
                    final p = g.b[i];
                    final isSel = sel == i;
                    final isTarget = targets.containsKey(i);
                    final isLastDrop = selDrop != null && isTarget;
                    return GestureDetector(
                      onTap: () => _onSquare(i),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSel
                              ? t.accent.withValues(alpha: .55)
                              : isTarget
                                  ? (isLastDrop ? t.secondary.withValues(alpha: .5) : t.primary.withValues(alpha: .45))
                                  : const Color(0xFFF3DEA8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB98A3E), width: 1),
                        ),
                        child: Center(
                          child: p == 0
                              ? (isTarget
                                  ? Icon(Icons.add_circle_outline, color: t.primary, size: 22)
                                  : null)
                              : RotatedBox(
                                  quarterTurns: p < 0 ? 2 : 0,
                                  child: Text(MiniShogi.kanji[p.abs()]!,
                                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B1A08))),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        _handTray(t, 1), // black hand at bottom
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Text('👑 Capture pieces, then drop them back as your own!',
              style: TextStyle(color: t.muted, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _handTray(GameTheme t, int color) {
    final hand = color == 1 ? g.handB : g.handW;
    final counts = <int, int>{};
    for (final p in hand) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final mine = (g.turn == color) && !ps[turnIdx].isBot && !over;
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
      child: Row(
        children: [
          Text(color == 1 ? '⬛' : '⬜', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          if (counts.isEmpty)
            Text('no captured pieces', style: TextStyle(color: t.muted, fontSize: 12)),
          for (final e in counts.entries)
            GestureDetector(
              onTap: mine ? () => _onHandTap(e.key) : null,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selDrop == e.key && g.turn == color
                      ? t.accent.withValues(alpha: .5)
                      : t.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.primary.withValues(alpha: .4)),
                ),
                child: RotatedBox(
                  quarterTurns: color < 0 ? 2 : 0,
                  child: Text('${MiniShogi.kanji[e.key]} ×${e.value}',
                      style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          const Spacer(),
          if (inCheckNow && g.turn == color)
            const Text('⚠️ CHECK!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }
}
