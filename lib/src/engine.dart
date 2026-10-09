/// Shogi rules engine — full 9x9 shogi per RULES.md (source of truth).
///
/// Board: 81 squares, index = row * 9 + col.
/// Row 0 is gote's back rank (top of screen), row 8 is sente's back rank.
/// Col 0 = file 9 (sente's left), col 8 = file 1 (sente's right).
/// Sente (Black, +1) moves "up" (row decreases); gote (White, -1) moves down.
/// A piece int is color * type. Hands hold unpromoted types only.
library;

/// Piece type ids.
const int ptKing = 1;
const int ptRook = 2;
const int ptBishop = 3;
const int ptGold = 4;
const int ptSilver = 5;
const int ptKnight = 6;
const int ptLance = 7;
const int ptPawn = 8;
const int ptDragonKing = 9; // +R
const int ptDragonHorse = 10; // +B
const int ptPromoSilver = 11; // narigin
const int ptPromoKnight = 12; // narikei
const int ptPromoLance = 13; // narikyo
const int ptTokin = 14; // tokin

const int sente = 1;
const int gote = -1;

int pType(int p) => p.abs();
int pColor(int p) => p.sign;

/// Promote an unpromoted type; returns same type if not promotable.
int promoteType(int t) => switch (t) {
      ptRook => ptDragonKing,
      ptBishop => ptDragonHorse,
      ptSilver => ptPromoSilver,
      ptKnight => ptPromoKnight,
      ptLance => ptPromoLance,
      ptPawn => ptTokin,
      _ => t,
    };

/// Demote a promoted type back to its base form.
int demoteType(int t) => switch (t) {
      ptDragonKing => ptRook,
      ptDragonHorse => ptBishop,
      ptPromoSilver => ptSilver,
      ptPromoKnight => ptKnight,
      ptPromoLance => ptLance,
      ptTokin => ptPawn,
      _ => t,
    };

bool isPromotable(int t) =>
    t == ptRook ||
    t == ptBishop ||
    t == ptSilver ||
    t == ptKnight ||
    t == ptLance ||
    t == ptPawn;

/// Gold-like movement (gold + all promoted minor pieces).
bool isGoldLike(int t) =>
    t == ptGold ||
    t == ptPromoSilver ||
    t == ptPromoKnight ||
    t == ptPromoLance ||
    t == ptTokin;

/// Kanji shown on the piece face (unpromoted).
const Map<int, String> kanjiFace = {
  ptKing: '王',
  ptRook: '飛',
  ptBishop: '角',
  ptGold: '金',
  ptSilver: '銀',
  ptKnight: '桂',
  ptLance: '香',
  ptPawn: '歩',
  ptDragonKing: '竜',
  ptDragonHorse: '馬',
  ptPromoSilver: '全',
  ptPromoKnight: '圭',
  ptPromoLance: '杏',
  ptTokin: 'と',
};

/// English names for accessibility / logs.
const Map<int, String> pieceName = {
  ptKing: 'King',
  ptRook: 'Rook',
  ptBishop: 'Bishop',
  ptGold: 'Gold',
  ptSilver: 'Silver',
  ptKnight: 'Knight',
  ptLance: 'Lance',
  ptPawn: 'Pawn',
  ptDragonKing: 'Dragon King',
  ptDragonHorse: 'Dragon Horse',
  ptPromoSilver: 'Promoted Silver',
  ptPromoKnight: 'Promoted Knight',
  ptPromoLance: 'Promoted Lance',
  ptTokin: 'Tokin',
};

/// A move. from == -1 means a drop; dropType is the piece type when dropping.
class ShogiMove {
  final int from;
  final int to;
  final int dropType;
  final bool promote;

  const ShogiMove(this.from, this.to, {this.dropType = 0, this.promote = false});

  bool get isDrop => dropType != 0;

  @override
  String toString() =>
      'ShogiMove(from:$from,to:$to,drop:$dropType,promote:$promote)';

  /// Compact serialization for isolate transfer.
  String encode() => '$from,$to,$dropType,${promote ? 1 : 0}';

  static ShogiMove decode(String s) {
    final parts = s.split(',');
    return ShogiMove(int.parse(parts[0]), int.parse(parts[1]),
        dropType: int.parse(parts[2]), promote: parts[3] == '1');
  }
}

class ShogiUndo {
  final ShogiMove move;
  final int prevTurn;
  final int movedPiece; // original piece int on `from` (0 for drops)
  final int capturedPiece; // original piece int on `to` (0 if none)
  ShogiUndo(this.move, this.prevTurn, this.movedPiece, this.capturedPiece);
}

/// Full shogi game state + rules. Deterministic; no UI.
class ShogiEngine {
  List<int> board = List.filled(81, 0);
  List<int> handSente = [];
  List<int> handGote = [];
  int turn = sente;
  int ply = 0;

  /// Move history for undo.
  final List<ShogiUndo> history = [];

  /// Position keys after each applied move (for sennichite).
  List<String> repKeys = [];
  final Map<String, int> repCounts = {};

  /// Whether the side to move was in check at each recorded position.
  List<bool> repCheck = [];

  ShogiEngine();

  List<int> _hand(int color) => color == sente ? handSente : handGote;

  // ---------------------------------------------------------------- setup

  /// handicap: 'even', 'lance', '2piece', '4piece', '6piece'.
  /// In handicap games White's pieces are removed and White moves first.
  void setup({String handicap = 'even'}) {
    board = List.filled(81, 0);
    handSente = [];
    handGote = [];
    history.clear();
    repKeys.clear();
    repCounts.clear();
    repCheck.clear();
    ply = 0;

    final removeWhite = <int>{}; // squares to leave empty for white
    if (handicap != 'even') {
      // White back rank squares: row 0, col c. Lance file 1 -> col 8.
      int w(int c) => c; // row 0 col c
      switch (handicap) {
        case 'lance':
          removeWhite.add(w(8));
        case '2piece':
          removeWhite.addAll([9 + 1, 9 + 7]); // row1 col1 rook, col7 bishop
        case '4piece':
          removeWhite.addAll([9 + 1, 9 + 7, w(0), w(8)]);
        case '6piece':
          removeWhite.addAll([9 + 1, 9 + 7, w(0), w(8), w(1), w(7)]);
      }
    }

    // Authoritative starting position (verified): sente bishop on file 8
    // (col 1) and rook on file 2 (col 7); gote mirrors through the center:
    // bishop on file 2 (col 7), rook on file 8 (col 1).
    const back = [ptLance, ptKnight, ptSilver, ptGold, ptKing, ptGold, ptSilver, ptKnight, ptLance];
    for (int c = 0; c < 9; c++) {
      // gote (top)
      final gBack = 0 * 9 + c;
      if (!removeWhite.contains(gBack)) board[gBack] = gote * back[c];
      final gRook = 1 * 9 + 1; // file 8
      final gBishop = 1 * 9 + 7; // file 2
      if (c == 1 && !removeWhite.contains(gRook)) board[gRook] = gote * ptRook;
      if (c == 7 && !removeWhite.contains(gBishop)) board[gBishop] = gote * ptBishop;
      board[2 * 9 + c] = gote * ptPawn;
      // sente (bottom)
      board[6 * 9 + c] = sente * ptPawn;
      if (c == 1) board[7 * 9 + 1] = sente * ptBishop; // file 8
      if (c == 7) board[7 * 9 + 7] = sente * ptRook; // file 2
      board[8 * 9 + c] = sente * back[c];
    }
    turn = handicap == 'even' ? sente : gote;
    recordPosition(); // the initial position counts for sennichite
  }

  // ------------------------------------------------------- move generation

  static const _kingSteps = [
    [-1, -1], [-1, 0], [-1, 1],
    [0, -1],           [0, 1],
    [1, -1],  [1, 0],  [1, 1],
  ];
  static const _ortho = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
  ];
  static const _diag = [
    [-1, -1], [-1, 1], [1, -1], [1, 1],
  ];

  bool _inZone(int sq, int color) {
    final r = sq ~/ 9;
    return color == sente ? r <= 2 : r >= 6;
  }

  int _lastRank(int color) => color == sente ? 0 : 8;

  /// Pseudo-legal moves (king safety NOT checked). Includes drops.
  List<ShogiMove> pseudoMoves(int color, {bool includeDrops = true}) {
    final moves = <ShogiMove>[];
    final fw = color == sente ? -1 : 1;

    void stepTo(int from, int r, int c, {bool promoteOption = false, bool mustPromote = false}) {
      if (r < 0 || r > 8 || c < 0 || c > 8) return;
      final to = r * 9 + c;
      final q = board[to];
      if (q != 0 && pColor(q) == color) return;
      if (!promoteOption) {
        moves.add(ShogiMove(from, to));
        return;
      }
      final dest = to;
      if (mustPromote) {
        moves.add(ShogiMove(from, dest, promote: true));
      } else {
        moves.add(ShogiMove(from, dest, promote: false));
        moves.add(ShogiMove(from, dest, promote: true));
      }
    }

    void slide(int from, int r, int c, List<List<int>> dirs,
        {bool promoteOption = false}) {
      for (final d in dirs) {
        int nr = r + d[0], nc = c + d[1];
        while (nr >= 0 && nr <= 8 && nc >= 0 && nc <= 8) {
          final to = nr * 9 + nc;
          final q = board[to];
          if (q == 0 || pColor(q) != color) {
            if (!promoteOption) {
              moves.add(ShogiMove(from, to));
            } else if (_inZone(from, color) || _inZone(to, color)) {
              moves.add(ShogiMove(from, to, promote: false));
              moves.add(ShogiMove(from, to, promote: true));
            } else {
              moves.add(ShogiMove(from, to));
            }
          }
          if (q != 0) break;
          nr += d[0];
          nc += d[1];
        }
      }
    }

    for (int i = 0; i < 81; i++) {
      final p = board[i];
      if (p == 0 || pColor(p) != color) continue;
      final t = pType(p);
      final r = i ~/ 9, c = i % 9;
      final promotable = isPromotable(t);
      // Mandatory promotion: pawn/lance to last rank, knight to last two ranks.
      bool mustPromoteDest(int nr) {
        if (!promotable) return false;
        if (t == ptPawn || t == ptLance) return nr == _lastRank(color);
        if (t == ptKnight) {
          return color == sente ? nr <= 1 : nr >= 7;
        }
        return false;
      }

      void stepGen(List<List<int>> deltas) {
        for (final d in deltas) {
          final nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr > 8 || nc < 0 || nc > 8) continue;
          final inZ = _inZone(i, color) || _inZone(nr * 9 + nc, color);
          stepTo(i, nr, nc,
              promoteOption: promotable && inZ,
              mustPromote: mustPromoteDest(nr));
        }
      }

      switch (t) {
        case ptKing:
          stepGen(_kingSteps);
        case ptGold:
          stepGen([
            [fw, -1], [fw, 0], [fw, 1],
            [0, -1], [0, 1],
            [-fw, 0],
          ]);
        case ptSilver:
          stepGen([
            [fw, -1], [fw, 0], [fw, 1],
            [-fw, -1], [-fw, 1],
          ]);
        case ptKnight:
          stepGen([
            [2 * fw, -1],
            [2 * fw, 1],
          ]);
        case ptPawn:
          stepGen([
            [fw, 0]
          ]);
        case ptLance:
          slide(i, r, c, [
            [fw, 0]
          ], promoteOption: true);
        case ptRook:
          slide(i, r, c, _ortho, promoteOption: true);
        case ptBishop:
          slide(i, r, c, _diag, promoteOption: true);
        case ptDragonKing:
          slide(i, r, c, _ortho);
          stepGen(_kingSteps.where((d) => d[0] != 0 && d[1] != 0).toList());
        case ptDragonHorse:
          slide(i, r, c, _diag);
          stepGen(_ortho);
        default:
          // promoted minor pieces move like gold
          stepGen([
            [fw, -1], [fw, 0], [fw, 1],
            [0, -1], [0, 1],
            [-fw, 0],
          ]);
      }
    }

    // Drops.
    if (includeDrops) {
      final hand = _hand(color);
      final types = hand.toSet().toList()..sort();
      for (final tp in types) {
        for (int sq = 0; sq < 81; sq++) {
          if (board[sq] != 0) continue;
          final rr = sq ~/ 9, cc = sq % 9;
          if (tp == ptPawn) {
            if (rr == _lastRank(color)) continue; // no-move rank
            bool nifu = false;
            for (int k = 0; k < 9; k++) {
              final q = board[k * 9 + cc];
              if (q == color * ptPawn) {
                nifu = true;
                break;
              }
            }
            if (nifu) continue;
          } else if (tp == ptLance) {
            if (rr == _lastRank(color)) continue;
          } else if (tp == ptKnight) {
            if (color == sente ? rr <= 1 : rr >= 7) continue;
          }
          moves.add(ShogiMove(-1, sq, dropType: tp));
        }
      }
    }
    return moves;
  }

  // ------------------------------------------------------------ apply/undo

  /// Applies a move WITHOUT touching history/repetition (used by search).
  ShogiUndo applyMove(ShogiMove m) {
    final me = turn;
    int movedPiece = 0;
    int capturedPiece = 0;
    if (m.isDrop) {
      _hand(me).remove(m.dropType);
      board[m.to] = me * m.dropType;
    } else {
      movedPiece = board[m.from];
      capturedPiece = board[m.to];
      if (capturedPiece != 0) {
        // Captured pieces demote and join the captor's hand.
        _hand(me).add(demoteType(pType(capturedPiece)));
      }
      board[m.from] = 0;
      board[m.to] =
          m.promote ? me * promoteType(pType(movedPiece)) : movedPiece;
    }
    turn = -me;
    ply++;
    return ShogiUndo(m, me, movedPiece, capturedPiece);
  }

  /// Real-game move: applies the move, records undo history and the new
  /// position for repetition tracking. The engine owns ALL turn state —
  /// the UI must use this (never [applyMove] directly) for real moves.
  ShogiUndo pushMove(ShogiMove m) {
    final u = applyMove(m);
    history.add(u);
    recordPosition();
    return u;
  }

  /// Undoes the most recent real move (inverse of [pushMove]).
  /// Returns false when there is nothing to undo.
  bool popMove() {
    if (history.isEmpty) return false;
    final u = history.removeLast();
    undoMove(u);
    truncateRepetition(repKeys.length - 1);
    return true;
  }

  void undoMove(ShogiUndo u) {
    turn = u.prevTurn;
    ply--;
    final m = u.move;
    if (m.isDrop) {
      board[m.to] = 0;
      _hand(turn).add(m.dropType);
    } else {
      board[m.from] = u.movedPiece;
      board[m.to] = u.capturedPiece;
      if (u.capturedPiece != 0) {
        _hand(turn).remove(demoteType(pType(u.capturedPiece)));
      }
    }
  }

  // ----------------------------------------------------------------- attack

  int _kingSquare(int color) {
    for (int i = 0; i < 81; i++) {
      if (board[i] == color * ptKing) return i;
    }
    return -1;
  }

  /// Public accessor for the king's square (-1 if missing).
  int kingSquare(int color) => _kingSquare(color);

  /// True if [sq] is attacked by any piece of [byColor].
  bool isAttacked(int sq, int byColor) {
    final r = sq ~/ 9, c = sq % 9;
    final fw = byColor == sente ? -1 : 1; // attacker's forward

    bool onBoard(int nr, int nc) => nr >= 0 && nr <= 8 && nc >= 0 && nc <= 8;
    bool isAttacker(int nr, int nc, bool Function(int t) test) {
      if (!onBoard(nr, nc)) return false;
      final q = board[nr * 9 + nc];
      return q != 0 && pColor(q) == byColor && test(pType(q));
    }

    // King adjacency (incl. dragon extras handled via their own types below).
    for (final d in _kingSteps) {
      if (isAttacker(r + d[0], c + d[1], (t) => t == ptKing)) return true;
    }
    // Pawn: attacks one square forward from the attacker's perspective, so
    // the attacking pawn sits one step *behind* the target square.
    if (isAttacker(r - fw, c, (t) => t == ptPawn)) return true;
    // Knight jumps: attacker sits two forward-steps behind.
    if (isAttacker(r - 2 * fw, c - 1, (t) => t == ptKnight)) return true;
    if (isAttacker(r - 2 * fw, c + 1, (t) => t == ptKnight)) return true;
    // Gold-like steps (absolute deltas, forward = f).
    final f = byColor == sente ? -1 : 1;
    for (final d in [
      [f, -1], [f, 0], [f, 1],
      [0, -1], [0, 1],
      [-f, 0],
    ]) {
      if (isAttacker(r - d[0], c - d[1], isGoldLike)) return true;
    }
    // Silver steps.
    for (final d in [
      [f, -1], [f, 0], [f, 1],
      [-f, -1], [-f, 1],
    ]) {
      if (isAttacker(r - d[0], c - d[1], (t) => t == ptSilver)) return true;
    }
    // Dragon king / dragon horse extra king-steps.
    for (final d in _kingSteps) {
      final nr = r + d[0], nc = c + d[1];
      if (!onBoard(nr, nc)) continue;
      final q = board[nr * 9 + nc];
      if (q == 0 || pColor(q) != byColor) continue;
      final t = pType(q);
      if (t == ptDragonKing) return true;
      if (t == ptDragonHorse && ((d[0] == 0) != (d[1] == 0))) {
        return true; // orthogonal extra step only
      }
    }
    // Sliding rays.
    bool ray(List<int> dir, bool Function(int t) canSlide) {
      int nr = r + dir[0], nc = c + dir[1];
      while (onBoard(nr, nc)) {
        final q = board[nr * 9 + nc];
        if (q != 0) {
          return pColor(q) == byColor && canSlide(pType(q));
        }
        nr += dir[0];
        nc += dir[1];
      }
      return false;
    }

    for (final d in _ortho) {
      if (ray(d, (t) => t == ptRook || t == ptDragonKing)) return true;
    }
    for (final d in _diag) {
      if (ray(d, (t) => t == ptBishop || t == ptDragonHorse)) return true;
    }
    // Lance: slides forward only, from the attacker's perspective. A sente
    // lance sits on sente's side of the target (higher row index) and
    // attacks upward; a gote lance sits below it and attacks downward.
    {
      final dir = byColor == sente ? [1, 0] : [-1, 0];
      int nr = r + dir[0], nc = c + dir[1];
      while (onBoard(nr, nc)) {
        final q = board[nr * 9 + nc];
        if (q != 0) {
          if (pColor(q) == byColor && pType(q) == ptLance) return true;
          break;
        }
        nr += dir[0];
        nc += dir[1];
      }
    }
    return false;
  }

  bool inCheck(int color) {
    final k = _kingSquare(color);
    if (k < 0) return true; // king missing: treat as check (shouldn't happen)
    return isAttacked(k, -color);
  }

  // ------------------------------------------------------------------ legal

  /// Legal moves for [color]. When [stopAtFirst] is true, returns as soon as
  /// one legal move is found (for checkmate tests).
  List<ShogiMove> legalMoves(int color, {bool stopAtFirst = false}) {
    final out = <ShogiMove>[];
    for (final m in pseudoMoves(color)) {
      final u = applyMove(m);
      final ok = !inCheck(color);
      bool uchifuzume = false;
      if (ok && m.isDrop && m.dropType == ptPawn) {
        // Uchifuzume: pawn drop delivering checkmate is illegal.
        if (inCheck(-color) && !hasLegalMove(-color)) uchifuzume = true;
      }
      undoMove(u);
      if (ok && !uchifuzume) {
        out.add(m);
        if (stopAtFirst) return out;
      }
    }
    return out;
  }

  bool hasLegalMove(int color) => legalMoves(color, stopAtFirst: true).isNotEmpty;

  bool isCheckmate(int color) => inCheck(color) && !hasLegalMove(color);

  // -------------------------------------------------------------- repetition

  /// Position key: board + hands + side to move.
  String positionKey() {
    final sb = StringBuffer();
    for (final p in board) {
      sb.write(p);
      sb.write(',');
    }
    sb.write('|');
    final hs = List.of(handSente)..sort();
    final hg = List.of(handGote)..sort();
    sb.write(hs.join(','));
    sb.write('|');
    sb.write(hg.join(','));
    sb.write('|');
    sb.write(turn);
    return sb.toString();
  }

  /// Record the current position (call after each real move).
  void recordPosition() {
    final key = positionKey();
    repKeys.add(key);
    repCheck.add(inCheck(turn));
    repCounts[key] = (repCounts[key] ?? 0) + 1;
  }

  /// After undo, truncate repetition history to [keep] entries.
  void truncateRepetition(int keep) {
    while (repKeys.length > keep) {
      final k = repKeys.removeLast();
      repCheck.removeLast();
      final n = (repCounts[k] ?? 1) - 1;
      if (n <= 0) {
        repCounts.remove(k);
      } else {
        repCounts[k] = n;
      }
    }
  }

  /// Sennichite result for the current position key:
  /// 0 = none, 1 = draw, 2 = sente loses (perpetual check), 3 = gote loses.
  int sennichiteResult() {
    final key = positionKey();
    if ((repCounts[key] ?? 0) < 4) return 0;
    // Find the 4 occurrences; sides to move alternate.
    final idx = <int>[];
    for (int i = 0; i < repKeys.length; i++) {
      if (repKeys[i] == key) idx.add(i);
    }
    if (idx.length < 4) return 0;
    final occ = idx.sublist(idx.length - 4);
    // All four occurrences share the same side to move (it's part of the key).
    // Perpetual check: the side to move is in check in all 4 occurrences,
    // meaning the opponent gave check on every cycle -> the checker loses.
    final sideToMove = int.parse(key.split('|').last);
    final victimInCheck = occ.every((i) => repCheck[i]);
    if (victimInCheck) {
      return sideToMove == sente ? 3 : 2; // 3 = gote loses, 2 = sente loses
    }
    return 1; // plain sennichite draw
  }

  // --------------------------------------------------------------- impasse

  /// True when [color]'s king has entered the opponent's camp (the
  /// promotion zone on the far side).
  bool kingEntered(int color) {
    final k = _kingSquare(color);
    if (k < 0) return false;
    final r = k ~/ 9;
    return color == sente ? r <= 2 : r >= 6;
  }

  /// True when BOTH kings have entered the opposing camps — the position
  /// is eligible for an impasse (jishōgi) declaration, RULES.md §7.5.
  bool bothKingsEntered() => kingEntered(sente) && kingEntered(gote);

  /// Jishōgi point count for [color], RULES.md §8: rook, bishop and
  /// promoted pieces count 5 each; every other piece except the king
  /// counts 1; the king counts 0. Pieces on the board AND in hand count.
  int impassePoints(int color) {
    int pts = 0;
    int count(int t) {
      if (t == ptKing) return 0;
      if (t == ptRook || t == ptBishop || t > ptPawn) return 5;
      return 1;
    }

    for (int i = 0; i < 81; i++) {
      final p = board[i];
      if (p != 0 && pColor(p) == color) pts += count(pType(p));
    }
    for (final t in _hand(color)) {
      pts += count(t);
    }
    return pts;
  }

  /// Adjudicates a declared impasse per RULES.md §8/§10.4.
  /// Returns 'sente' / 'gote' when the declarer meets the win condition
  /// (king entered + ≥ 24 points), otherwise 'draw'.
  String adjudicateImpasse(int declarer) {
    if (kingEntered(declarer) && impassePoints(declarer) >= 24) {
      return declarer == sente ? 'sente' : 'gote';
    }
    return 'draw';
  }

  // ------------------------------------------------------------- serialization

  Map<String, dynamic> toMap() => {
        'board': List<int>.of(board),
        'hs': List<int>.of(handSente),
        'hg': List<int>.of(handGote),
        'turn': turn,
        'ply': ply,
        'repKeys': List<String>.of(repKeys),
        'repCheck': List<bool>.of(repCheck),
      };

  void fromMap(Map<String, dynamic> m) {
    board = List<int>.from(m['board'] as List);
    handSente = List<int>.from(m['hs'] as List);
    handGote = List<int>.from(m['hg'] as List);
    turn = m['turn'] as int;
    ply = m['ply'] as int;
    history.clear();
    repKeys = List<String>.from(m['repKeys'] as List);
    repCheck = List<bool>.from(m['repCheck'] as List);
    repCounts.clear();
    for (final k in repKeys) {
      repCounts[k] = (repCounts[k] ?? 0) + 1;
    }
  }

  ShogiEngine clone() {
    final e = ShogiEngine();
    e.board = List.of(board);
    e.handSente = List.of(handSente);
    e.handGote = List.of(handGote);
    e.turn = turn;
    e.ply = ply;
    return e;
  }

  // ------------------------------------------------------------------ helpers

  /// One-letter piece code for narration (promoted pieces get a '+' prefix).
  static String pieceCode(int t) {
    const base = {
      ptKing: 'K',
      ptRook: 'R',
      ptBishop: 'B',
      ptGold: 'G',
      ptSilver: 'S',
      ptKnight: 'N',
      ptLance: 'L',
      ptPawn: 'P',
    };
    final b = demoteType(t);
    final plus = isPromotable(b) && t != b ? '+' : '';
    return '$plus${base[b] ?? '?'}';
  }

  /// Square label in file + rank-letter form from sente's perspective,
  /// e.g. file 2, sixth rank from sente -> "2f".
  static String fileRankLabel(int sq) {
    final r = sq ~/ 9, c = sq % 9;
    final rank = String.fromCharCode(97 + (8 - r)); // a..i from sente
    return '${9 - c}$rank';
  }

  /// Human-readable narration for a move, e.g. "P-2f", "B*5e", "+S-3c".
  /// [movedPiece] is the piece int as it stood before the move
  /// (mover * dropType for drops).
  static String describeMove(ShogiMove m, int movedPiece) {
    final sq = fileRankLabel(m.to);
    if (m.isDrop) return '${pieceCode(pType(movedPiece))}*$sq';
    final code = pieceCode(pType(movedPiece));
    final promo = m.promote ? '+' : '';
    return '$promo$code-$sq';
  }

  /// File (1-9, right-to-left from sente) and rank kanji for a square.
  static String squareLabel(int sq) {
    final r = sq ~/ 9, c = sq % 9;
    const ranks = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return '${9 - c}${ranks[r]}';
  }

  /// Count captured pieces (in both hands) for stats.
  int capturedCount() => handSente.length + handGote.length;
}
