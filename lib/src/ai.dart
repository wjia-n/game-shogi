/// Shogi bot: depth-limited alpha-beta search with quiescence.
///
/// Runs inside [compute] (see [aiCompute]) so the UI never janks.
/// Difficulties: 0 = Beginner, 1 = Skilled, 2 = Master.
library;

import 'dart:math';

import 'engine.dart';

// Material values in centipawns (from side-to-move perspective).
const Map<int, int> _value = {
  ptKing: 0,
  ptRook: 1000,
  ptBishop: 900,
  ptGold: 600,
  ptSilver: 500,
  ptKnight: 400,
  ptLance: 400,
  ptPawn: 100,
  ptDragonKing: 1200,
  ptDragonHorse: 1100,
  ptPromoSilver: 600,
  ptPromoKnight: 600,
  ptPromoLance: 600,
  ptTokin: 600,
};

/// Extra value for pieces in hand (drops are flexible).
const int _handBonus = 60;

/// Advancement bonus per rank advanced (pawns/silvers/knights/lances).
const int _advanceBonus = 12;

int _evaluate(ShogiEngine e, int color) {
  int s = 0;
  for (int i = 0; i < 81; i++) {
    final p = e.board[i];
    if (p == 0) continue;
    final t = pType(p);
    int v = _value[t] ?? 0;
    if (t == ptPawn || t == ptSilver || t == ptKnight || t == ptLance) {
      final r = i ~/ 9;
      final advanced = pColor(p) == sente ? (8 - r) : r;
      v += advanced * _advanceBonus;
    }
    s += pColor(p) == color ? v : -v;
  }
  for (final t in e.handSente) {
    final v = (_value[t] ?? 0) + _handBonus;
    s += color == sente ? v : -v;
  }
  for (final t in e.handGote) {
    final v = (_value[t] ?? 0) + _handBonus;
    s -= color == sente ? v : -v;
  }
  // King shelter: own pieces adjacent to own king are good.
  for (final kColor in [sente, gote]) {
    int k = -1;
    for (int i = 0; i < 81; i++) {
      if (e.board[i] == kColor * ptKing) {
        k = i;
        break;
      }
    }
    if (k < 0) continue;
    final kr = k ~/ 9, kc = k % 9;
    int shelter = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = kr + dr, nc = kc + dc;
        if (nr < 0 || nr > 8 || nc < 0 || nc > 8) continue;
        final q = e.board[nr * 9 + nc];
        if (q != 0 && pColor(q) == kColor) shelter++;
      }
    }
    s += kColor == color ? shelter * 15 : -shelter * 15;
  }
  return s;
}

/// MVV-LVA-ish ordering score (higher = search first).
int _orderScore(ShogiEngine e, ShogiMove m) {
  int s = 0;
  if (!m.isDrop) {
    final target = e.board[m.to];
    if (target != 0) {
      final victim = _value[pType(target)] ?? 0;
      final attacker = _value[pType(e.board[m.from])] ?? 1;
      s += 10000 + victim * 10 - attacker;
    }
  } else {
    s += 2000 + (_value[m.dropType] ?? 0);
  }
  if (m.promote) s += 5000;
  return s;
}

class _Timeout implements Exception {}

class _Searcher {
  final ShogiEngine e;
  final Stopwatch clock = Stopwatch();
  final int deadlineMs;
  final Set<String> pathKeys;
  int nodes = 0;

  _Searcher(this.e, this.deadlineMs, this.pathKeys);

  void _checkTime() {
    if ((nodes & 1023) == 0 && clock.elapsedMilliseconds > deadlineMs) {
      throw _Timeout();
    }
  }

  int _quiesce(int alpha, int beta, int color, int depth) {
    nodes++;
    _checkTime();
    if (!e.inCheck(color) && !e.hasLegalMove(color)) {
      // Not in check and (per shogi rules) always has a move; guard anyway.
    }
    final standPat = _evaluate(e, color);
    if (depth <= 0) return standPat;
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;

    // Tactical moves: captures and promotions only.
    final moves = e.pseudoMoves(color, includeDrops: false).where((m) {
      if (m.isDrop) return false;
      return e.board[m.to] != 0 || m.promote;
    }).toList();
    moves.sort((a, b) => _orderScore(e, b).compareTo(_orderScore(e, a)));
    for (final m in moves) {
      final u = e.applyMove(m);
      final legal = !e.inCheck(color);
      int score;
      if (!legal) {
        e.undoMove(u);
        continue;
      }
      if (e.isCheckmate(-color)) {
        e.undoMove(u);
        return 100000 - e.ply;
      }
      score = -_quiesce(-beta, -alpha, -color, depth - 1);
      e.undoMove(u);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int _search(int alpha, int beta, int color, int depth) {
    nodes++;
    _checkTime();
    if (depth <= 0) return _quiesce(alpha, beta, color, 4);

    // Draw by repetition inside the search tree: treat as 0.
    final key = e.positionKey();
    if (pathKeys.contains(key)) return 0;
    pathKeys.add(key);

    final moves = e.legalMoves(color);
    pathKeys.remove(key);
    if (moves.isEmpty) {
      // No legal moves: checkmate if in check (stalemate ~ loss per rules).
      return e.inCheck(color) ? -100000 + e.ply : 0;
    }
    moves.sort((a, b) => _orderScore(e, b).compareTo(_orderScore(e, a)));
    int best = -1 << 30;
    for (final m in moves) {
      final u = e.applyMove(m);
      pathKeys.add(e.positionKey());
      final score = -_search(-beta, -alpha, -color, depth - 1);
      pathKeys.remove(e.positionKey());
      e.undoMove(u);
      if (score > best) best = score;
      if (best >= beta) return beta;
      if (best > alpha) alpha = best;
    }
    return best;
  }

  /// Score of the chosen move from the last [searchRoot] call
  /// (side-to-move perspective, centipawns).
  int lastScore = 0;

  /// Iterative deepening root search. Returns the best move found.
  ShogiMove searchRoot(int maxDepth, Random rng,
      {bool randomize = false, int topN = 1}) {
    final color = e.turn;
    var moves = e.legalMoves(color);
    if (moves.isEmpty) {
      throw StateError('no legal moves');
    }
    // Never walk into an immediate third repetition at the root.
    final safe = moves.where((m) {
      final u = e.applyMove(m);
      final k = e.positionKey();
      final n = e.repCounts[k] ?? 0;
      e.undoMove(u);
      return n < 3;
    }).toList();
    if (safe.isNotEmpty) moves = safe;

    moves.sort((a, b) => _orderScore(e, b).compareTo(_orderScore(e, a)));
    clock.start();
    final scored = <ShogiMove, int>{};
    try {
      for (int depth = 1; depth <= maxDepth; depth++) {
        // Search in current order; keep best-first for the next iteration.
        int alpha = -1 << 30;
        final round = <ShogiMove, int>{};
        for (final m in moves) {
          final u = e.applyMove(m);
          int score;
          if (e.isCheckmate(-color)) {
            score = 100000 - e.ply;
          } else {
            pathKeys.add(e.positionKey());
            score = -_search(-1000000, -alpha, -color, depth - 1);
            pathKeys.remove(e.positionKey());
          }
          e.undoMove(u);
          round[m] = score;
          if (score > alpha) alpha = score;
        }
        scored
          ..clear()
          ..addAll(round);
        moves.sort((a, b) => round[b]!.compareTo(round[a]!));
      }
    } on _Timeout {
      // Keep the best fully-evaluated result so far.
    }
    if (scored.isEmpty) {
      // Timed out during depth 1: fall back to ordered first move.
      lastScore = 0;
      return moves.first;
    }
    final ranked = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    final pick = randomize
        ? ranked.take(topN).toList()[rng.nextInt(min(topN, ranked.length))]
        : ranked.first;
    lastScore = scored[pick] ?? 0;
    return pick;
  }
}

/// Payload: a map with `board`, `hs`, `hg`, `turn`, `repKeys`,
/// `difficulty` and `seed` entries.
/// Returns a string of the form `move|score` — the chosen move
/// ([ShogiMove.encode]) plus its search score from the side-to-move
/// perspective (centipawns).
Future<String> aiCompute(Map<String, dynamic> payload) async {
  final e = ShogiEngine();
  e.board = List<int>.from(payload['board'] as List);
  e.handSente = List<int>.from(payload['hs'] as List);
  e.handGote = List<int>.from(payload['hg'] as List);
  e.turn = payload['turn'] as int;
  e.ply = payload['ply'] as int? ?? 0;
  final repKeys = List<String>.from(payload['repKeys'] as List? ?? []);
  e.repCounts.clear();
  for (final k in repKeys) {
    e.repCounts[k] = (e.repCounts[k] ?? 0) + 1;
  }
  final difficulty = payload['difficulty'] as int? ?? 1;
  final rng = Random(payload['seed'] as int? ?? 12345);
  final pathKeys = repKeys.toSet();
  // Test override: smaller per-move time budget for fast simulations.
  final deadlineOverride = payload['deadlineMs'] as int?;

  ShogiMove pick;
  int score = 0;
  switch (difficulty) {
    case 0: // Beginner: depth 1, pick among top 5, 10% fully random.
      if (rng.nextDouble() < 0.10) {
        final moves = e.legalMoves(e.turn);
        pick = moves[rng.nextInt(moves.length)];
      } else {
        final s = _Searcher(e, deadlineOverride ?? 600, pathKeys);
        pick = s.searchRoot(1, rng, randomize: true, topN: 5);
        score = s.lastScore;
      }
    case 2: // Master: iterative deepening, quiescence, ~2.5s budget.
      final s = _Searcher(e, deadlineOverride ?? 2500, pathKeys);
      pick = s.searchRoot(6, rng);
      score = s.lastScore;
    case 1: // Skilled: depth 3 within ~1s.
    default:
      final s = _Searcher(e, deadlineOverride ?? 1000, pathKeys);
      pick = s.searchRoot(3, rng);
      score = s.lastScore;
  }
  return '${pick.encode()}|$score';
}
