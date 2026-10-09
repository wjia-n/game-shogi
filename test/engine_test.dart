/// Engine rules tests — RULES.md §13 (T1–T18) plus regression tests for
/// audit findings (lance check direction, bishop/rook setup, undo, impasse).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shogi/src/engine.dart';

ShogiEngine fresh() {
  final e = ShogiEngine();
  e.setup();
  return e;
}

/// Finds a legal move matching from/to (optionally promotion choice).
ShogiMove? findMove(ShogiEngine e, int color, int from, int to,
    {bool? promote}) {
  for (final m in e.legalMoves(color)) {
    if (m.from == from && m.to == to && (promote == null || m.promote == promote)) {
      return m;
    }
  }
  return null;
}

void main() {
  group('setup (T1, T18)', () {
    test('T1: 20 pieces per side, hands empty, sente to move', () {
      final e = fresh();
      final s = e.board.where((p) => p > 0).length;
      final g = e.board.where((p) => p < 0).length;
      expect(s, 20);
      expect(g, 20);
      expect(e.handSente, isEmpty);
      expect(e.handGote, isEmpty);
      expect(e.turn, sente);
    });

    test('T1: authoritative starting squares', () {
      final e = fresh();
      expect(e.board[8 * 9 + 4], sente * ptKing);
      expect(e.board[0 * 9 + 4], gote * ptKing);
      // Sente: bishop file 8 (col 1), rook file 2 (col 7).
      expect(e.board[7 * 9 + 1], sente * ptBishop);
      expect(e.board[7 * 9 + 7], sente * ptRook);
      // Gote mirrors through the center: bishop file 2, rook file 8.
      expect(e.board[1 * 9 + 7], gote * ptBishop);
      expect(e.board[1 * 9 + 1], gote * ptRook);
      for (int c = 0; c < 9; c++) {
        expect(e.board[6 * 9 + c], sente * ptPawn);
        expect(e.board[2 * 9 + c], gote * ptPawn);
      }
    });

    test('T18: 2-piece handicap removes gote rook+bishop, gote first', () {
      final e = ShogiEngine();
      e.setup(handicap: '2piece');
      expect(e.board[1 * 9 + 1], 0); // rook square
      expect(e.board[1 * 9 + 7], 0); // bishop square
      expect(e.board.where((p) => p < 0).length, 18);
      expect(e.turn, gote);
    });

    test('lance handicap removes one gote lance', () {
      final e = ShogiEngine();
      e.setup(handicap: 'lance');
      expect(e.board[0 * 9 + 8], 0);
      expect(e.turn, gote);
    });
  });

  group('movement (T2–T6)', () {
    test('T2: pawn steps forward one; not two', () {
      final e = fresh();
      expect(findMove(e, sente, 6 * 9 + 2, 5 * 9 + 2), isNotNull);
      expect(findMove(e, sente, 6 * 9 + 2, 4 * 9 + 2), isNull);
    });

    test('T3: knight jumps over pieces, forward only', () {
      final e = fresh();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 4] = sente * ptKing;
      e.board[0 * 9 + 4] = gote * ptKing;
      e.board[5 * 9 + 4] = sente * ptKnight;
      e.board[6 * 9 + 4] = sente * ptPawn; // jumped-over piece
      e.board[6 * 9 + 3] = sente * ptPawn;
      e.board[6 * 9 + 5] = sente * ptPawn;
      final moves =
          e.legalMoves(sente).where((m) => m.from == 5 * 9 + 4).toList();
      final tos = moves.map((m) => m.to).toSet();
      // Knight jumps two forward + one sideways even with pieces between.
      expect(tos.contains(3 * 9 + 3), isTrue);
      expect(tos.contains(3 * 9 + 5), isTrue);
      // No sideways / backward moves.
      for (final m in moves) {
        expect(m.to ~/ 9 < 5, isTrue);
      }
    });

    test('T4: lance blocked, then slides when clear', () {
      final e = fresh();
      var moves =
          e.legalMoves(sente).where((m) => m.from == 8 * 9 + 0).toList();
      // Blocked by own pawn at (6,0): only (7,0).
      expect(moves.map((m) => m.to).toSet(), {7 * 9 + 0});
      e.board[6 * 9 + 0] = 0;
      moves = e.legalMoves(sente).where((m) => m.from == 8 * 9 + 0).toList();
      // (2,0) holds a gote pawn: the lance captures it, then stops.
      expect(
          moves.map((m) => m.to).toSet(),
          {
            7 * 9 + 0,
            6 * 9 + 0,
            5 * 9 + 0,
            4 * 9 + 0,
            3 * 9 + 0,
            2 * 9 + 0,
          });
    });

    test('T5: gold has exactly 6 destinations from center', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[4 * 9 + 4] = sente * ptGold;
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      final tos = e
          .legalMoves(sente)
          .where((m) => m.from == 4 * 9 + 4)
          .map((m) => m.to)
          .toSet();
      expect(tos.length, 6);
      expect(tos.contains(5 * 9 + 3), isFalse); // rear diagonals excluded
      expect(tos.contains(5 * 9 + 5), isFalse);
    });

    test('T6: silver has exactly 5 destinations from center', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[4 * 9 + 4] = sente * ptSilver;
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      final tos = e
          .legalMoves(sente)
          .where((m) => m.from == 4 * 9 + 4)
          .map((m) => m.to)
          .toSet();
      expect(tos.length, 5);
    });
  });

  group('promotion (T7–T9)', () {
    test('T7: optional promotion offers both choices', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      e.board[3 * 9 + 4] = sente * ptSilver;
      final moves = e
          .legalMoves(sente)
          .where((m) => m.from == 3 * 9 + 4 && m.to == 2 * 9 + 4)
          .toList();
      expect(moves.length, 2);
      expect(moves.any((m) => m.promote), isTrue);
      expect(moves.any((m) => !m.promote), isTrue);
    });

    test('T8: pawn to last rank auto-promotes (no choice)', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      e.board[1 * 9 + 4] = sente * ptPawn;
      final moves = e
          .legalMoves(sente)
          .where((m) => m.from == 1 * 9 + 4 && m.to == 0 * 9 + 4)
          .toList();
      expect(moves.length, 1);
      expect(moves.first.promote, isTrue);
      e.pushMove(moves.first);
      expect(e.board[0 * 9 + 4], sente * ptTokin);
    });

    test('T9: knight to last two ranks must promote', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      e.board[2 * 9 + 3] = sente * ptKnight;
      final moves = e
          .legalMoves(sente)
          .where((m) => m.from == 2 * 9 + 3)
          .toList();
      expect(moves, isNotEmpty);
      expect(moves.every((m) => m.promote), isTrue);
    });
  });

  group('captures & drops (T10, T11, T13)', () {
    test('T10: capture changes sides; promoted captures demote', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      e.board[4 * 9 + 4] = sente * ptSilver;
      e.board[3 * 9 + 4] = gote * ptPawn;
      e.pushMove(findMove(e, sente, 4 * 9 + 4, 3 * 9 + 4)!);
      expect(e.handSente, contains(ptPawn));

      // Captured dragon horse becomes a bishop in hand.
      final e2 = ShogiEngine();
      e2.board = List.filled(81, 0);
      e2.board[8 * 9 + 0] = sente * ptKing;
      e2.board[0 * 9 + 8] = gote * ptKing;
      e2.board[4 * 9 + 4] = sente * ptSilver;
      e2.board[3 * 9 + 4] = gote * ptDragonHorse;
      e2.pushMove(findMove(e2, sente, 4 * 9 + 4, 3 * 9 + 4)!);
      expect(e2.handSente, contains(ptBishop));
      expect(e2.handSente, isNot(contains(ptDragonHorse)));
    });

    test('T11: nifu — no pawn drop on a file with own unpromoted pawn',
        () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      e.board[4 * 9 + 4] = sente * ptPawn; // file 5
      e.handSente = [ptPawn];
      e.turn = sente;
      final drops = e.legalMoves(sente).where((m) => m.isDrop).toList();
      expect(drops, isNotEmpty);
      for (final d in drops) {
        expect(d.to % 9 == 4, isFalse, reason: 'nifu on file 5');
      }
      // Tokin on the file does NOT count as nifu.
      e.board[4 * 9 + 4] = sente * ptTokin;
      final drops2 = e.legalMoves(sente).where((m) => m.isDrop).toList();
      expect(drops2.any((d) => d.to % 9 == 4), isTrue);
    });

    test('T13: pawn/lance/knight drops barred from dead ranks', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 8] = gote * ptKing;
      e.handSente = [ptPawn, ptLance, ptKnight];
      e.turn = sente;
      final drops = e.legalMoves(sente).where((m) => m.isDrop).toList();
      for (final d in drops) {
        final r = d.to ~/ 9;
        if (d.dropType == ptPawn || d.dropType == ptLance) {
          expect(r == 0, isFalse);
        } else {
          expect(r <= 1, isFalse);
        }
      }
    });
  });

  group('check / mate (T14, T15) + lance regression', () {
    test('T14: bishop check is detected and announced via inCheck', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[2 * 9 + 2] = gote * ptKing;
      e.board[5 * 9 + 5] = sente * ptBishop;
      expect(e.inCheck(gote), isTrue);
      expect(e.inCheck(sente), isFalse);
    });

    test('lance check direction: attacks forward only (audit regression)',
        () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 4] = gote * ptKing;
      e.board[3 * 9 + 4] = sente * ptLance; // below gote king, attacks up
      expect(e.inCheck(gote), isTrue);
      // King behind the lance is NOT attacked.
      e.board[0 * 9 + 4] = 0;
      e.board[5 * 9 + 4] = gote * ptKing;
      expect(e.inCheck(gote), isFalse);
    });

    test('T15: checkmate ends the game', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 4] = sente * ptKing;
      e.board[0 * 9 + 4] = gote * ptKing;
      e.board[1 * 9 + 4] = sente * ptRook; // checking rook, adjacent
      e.board[1 * 9 + 3] = sente * ptGold; // covers (0,3) + defends rook
      e.board[1 * 9 + 5] = sente * ptGold; // covers (0,5) + defends rook
      e.turn = gote;
      expect(e.inCheck(gote), isTrue);
      expect(e.isCheckmate(gote), isTrue);
    });
  });

  group('uchifuzume (T12)', () {
    test('T12: pawn drop delivering checkmate is illegal', () {
      // Mating net: pawn drops on (1,4); every king flight is covered and
      // the pawn is defended, so the drop is mate -> uchifuzume -> illegal.
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 0] = sente * ptKing;
      e.board[0 * 9 + 4] = gote * ptKing;
      e.board[1 * 9 + 2] = sente * ptSilver; // covers (0,3)
      e.board[1 * 9 + 6] = sente * ptSilver; // covers (0,5)
      e.board[2 * 9 + 3] = sente * ptGold; // covers (1,3), defends (1,4)
      e.board[2 * 9 + 5] = sente * ptGold; // covers (1,5), defends (1,4)
      e.handSente = [ptPawn];
      e.turn = sente;
      final drops = e
          .legalMoves(sente)
          .where((m) => m.isDrop && m.dropType == ptPawn)
          .toList();
      // The mating drop on (1,4) must be absent…
      expect(drops.any((d) => d.to == 1 * 9 + 4), isFalse);
      // …but other pawn drops remain legal.
      expect(drops.any((d) => d.to != 1 * 9 + 4), isTrue);
    });
  });

  group('repetition (T16, T17)', () {
    test('T16: fourfold repetition without checks is a draw', () {
      final e = fresh(); // initial position recorded
      ShogiMove mv(int from, int to) =>
          findMove(e, e.turn, from, to, promote: false)!;
      for (int cycle = 0; cycle < 3; cycle++) {
        e.pushMove(mv(8 * 9 + 3, 7 * 9 + 3)); // sente gold out
        if (cycle < 2) expect(e.sennichiteResult(), 0);
        e.pushMove(mv(0 * 9 + 5, 1 * 9 + 5)); // gote gold out
        if (cycle < 2) expect(e.sennichiteResult(), 0);
        e.pushMove(mv(7 * 9 + 3, 8 * 9 + 3)); // sente gold back
        if (cycle < 2) expect(e.sennichiteResult(), 0);
        e.pushMove(mv(1 * 9 + 5, 0 * 9 + 5)); // gote gold back
        if (cycle < 2) expect(e.sennichiteResult(), 0);
      }
      expect(e.sennichiteResult(), 1); // draw, not a perpetual-check loss
    });

    test('T17: repetition by perpetual check loses for the checker', () {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 4] = sente * ptKing;
      e.board[0 * 9 + 4] = gote * ptKing;
      e.board[7 * 9 + 4] = gote * ptRook; // checking sente every cycle
      e.turn = sente;
      for (int i = 0; i < 4; i++) {
        e.recordPosition();
      }
      expect(e.sennichiteResult(), 3); // gote (the checker) loses
    });
  });

  group('undo + history ownership', () {
    test('pushMove/popMove round-trips exactly', () {
      final e = fresh();
      final key0 = e.positionKey();
      final m = findMove(e, sente, 6 * 9 + 2, 5 * 9 + 2)!;
      e.pushMove(m);
      expect(e.history, hasLength(1));
      expect(e.positionKey(), isNot(key0));
      expect(e.popMove(), isTrue);
      expect(e.positionKey(), key0);
      expect(e.turn, sente);
      expect(e.ply, 0);
      expect(e.history, isEmpty);
      expect(e.popMove(), isFalse); // nothing left
    });
  });

  group('impasse (jishogi)', () {
    ShogiEngine enteredPosition() {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[2 * 9 + 4] = sente * ptKing; // entered
      e.board[6 * 9 + 4] = gote * ptKing; // entered
      return e;
    }

    test('not eligible at game start', () {
      expect(fresh().bothKingsEntered(), isFalse);
    });

    test('eligible when both kings entered', () {
      expect(enteredPosition().bothKingsEntered(), isTrue);
    });

    test('point counting: R/B/promoted=5, others=1, king=0', () {
      final e = enteredPosition();
      e.board[4 * 9 + 4] = sente * ptRook; // 5
      e.board[4 * 9 + 5] = sente * ptTokin; // 5
      e.board[4 * 9 + 6] = sente * ptPawn; // 1
      e.handSente = [ptPawn, ptGold]; // 1 + 1
      expect(e.impassePoints(sente), 13);
      expect(e.impassePoints(gote), 0);
    });

    test('adjudication: 24+ with entered king wins, else draw', () {
      final e = enteredPosition();
      e.handSente = [ptRook, ptRook, ptRook, ptRook, ptRook]; // 25
      expect(e.adjudicateImpasse(sente), 'sente');
      final e2 = enteredPosition();
      e2.handSente = [ptRook, ptRook]; // 10
      expect(e2.adjudicateImpasse(sente), 'draw');
    });
  });

  group('narration', () {
    test('describeMove formats moves and drops', () {
      // Square (4,4): file 5, rank letter e.
      expect(
          ShogiEngine.describeMove(
              const ShogiMove(-1, 4 * 9 + 4, dropType: ptPawn),
              sente * ptPawn),
          'P*5e');
      // Pawn (6,4)->(5,4): file 5, rank d.
      expect(
          ShogiEngine.describeMove(
              const ShogiMove(6 * 9 + 4, 5 * 9 + 4), sente * ptPawn),
          'P-5d');
      // Promoting silver: to (2,4) -> file 5, rank g.
      expect(
          ShogiEngine.describeMove(
              ShogiMove(3 * 9 + 4, 2 * 9 + 4, promote: true),
              sente * ptSilver),
          '+S-5g');
    });
  });
}
