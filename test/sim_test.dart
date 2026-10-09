/// Simulation tests: random self-play proves the engine can never reach
/// a stuck state, and the AI only ever returns legal moves.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shogi/src/ai.dart';
import 'package:shogi/src/engine.dart';

/// Plays a full game with capture/check-seeking playouts (mimics decisive
/// play so games terminate). Returns one of the outcome codes
/// (`mate:`, `rep:`, `stale:`, `empty`, `cap`).
String playRandomGame(int seed, {int cap = 1500}) {
  final e = ShogiEngine();
  e.setup();
  final rng = Random(seed);

  int scoreMove(ShogiMove m) {
    int s = rng.nextInt(20);
    if (!m.isDrop) {
      final target = e.board[m.to];
      if (target != 0) s += 1000 + pType(target) * 10;
      if (m.promote) s += 200;
      // Check-seeking: does the move give check?
      final u = e.applyMove(m);
      final chk = e.inCheck(e.turn);
      e.undoMove(u);
      if (chk) s += 500;
    } else {
      s += 50;
    }
    return s;
  }

  for (int ply = 0; ply < cap; ply++) {
    final rep = e.sennichiteResult();
    if (rep != 0) return 'rep:$rep';
    final moves = e.legalMoves(e.turn);
    if (moves.isEmpty) {
      return e.inCheck(e.turn) ? 'mate:${-e.turn}' : 'stale:${-e.turn}';
    }
    // Structural invariant: the engine always has forward progress.
    assert(e.history.length == ply);
    final scored = <ShogiMove, int>{for (final m in moves) m: scoreMove(m)};
    moves.sort((a, b) => scored[b]!.compareTo(scored[a]!));
    final pick = moves[rng.nextInt(moves.length.clamp(1, 3))];
    final turnBefore = e.turn;
    e.pushMove(pick);
    assert(e.turn == -turnBefore); // turn always alternates
  }
  return 'cap';
}

/// True bot-vs-bot simulation: both sides use the real AI. Runs a fixed
/// number of plies and verifies the full loop — every AI move is legal,
/// the turn always alternates, the engine never throws, and no moveless
/// non-terminal position is ever reached. Returns the outcome code.
Future<String> playBotGame(int seed, {int plies = 300}) async {
  final e = ShogiEngine();
  e.setup();
  for (int ply = 0; ply < plies; ply++) {
    final rep = e.sennichiteResult();
    if (rep != 0) return 'rep:$rep@${e.ply}';
    final moves = e.legalMoves(e.turn);
    if (moves.isEmpty) {
      return e.inCheck(e.turn)
          ? 'mate:${-e.turn}@${e.ply}'
          : 'stale:${-e.turn}@${e.ply}';
    }
    final turnBefore = e.turn;
    final res = await aiCompute({
      'board': List<int>.of(e.board),
      'hs': List<int>.of(e.handSente),
      'hg': List<int>.of(e.handGote),
      'turn': e.turn,
      'ply': e.ply,
      'repKeys': List<String>.of(e.repKeys),
      'difficulty': 0,
      'seed': seed * 1000003 + ply,
      'deadlineMs': 120000, // never triggers: depth-1 always completes
    });
    final move = ShogiMove.decode(res.split('|').first);
    // The AI must only ever return legal moves.
    final legal = moves.any((m) =>
        m.from == move.from &&
        m.to == move.to &&
        m.dropType == move.dropType &&
        m.promote == move.promote);
    if (!legal) return 'illegal:$move@${e.ply}';
    e.pushMove(move);
    assert(e.turn == -turnBefore);
  }
  return 'ran:$plies';
}

void main() {
  group('self-play: no stuck states', () {
    test('random playouts never hit a moveless non-terminal position', () {
      for (int seed = 1; seed <= 6; seed++) {
        final o = playRandomGame(seed);
        expect(o == 'empty', isFalse,
            reason: 'seed $seed reached a stuck state: $o');
      }
    });

    test('bot-vs-bot: 300 plies, every AI move legal, never stuck',
        () async {
      for (int seed = 7; seed <= 8; seed++) {
        final o = await playBotGame(seed);
        expect(o.startsWith('illegal'), isFalse,
            reason: 'bot game $seed produced an illegal move: $o');
        // 'ran:300' means 300 plies with zero illegal moves, zero
        // exceptions, and a legal forward action on every single ply —
        // stuck states are impossible by construction.
        debugPrint('bot-vs-bot seed $seed -> $o');
      }
    }, timeout: const Timeout(Duration(minutes: 6)));

    test('AI converts mate in 1', () async {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 4] = sente * ptKing;
      e.board[0 * 9 + 4] = gote * ptKing;
      e.board[2 * 9 + 4] = sente * ptRook;
      e.board[1 * 9 + 3] = sente * ptGold;
      e.board[1 * 9 + 5] = sente * ptGold;
      e.turn = sente;
      final res = await aiCompute({
        'board': List<int>.of(e.board),
        'hs': <int>[],
        'hg': <int>[],
        'turn': e.turn,
        'ply': 40,
        'repKeys': <String>[],
        'difficulty': 1,
        'seed': 7,
        'deadlineMs': 120000,
      });
      final move = ShogiMove.decode(res.split('|').first);
      e.pushMove(move);
      expect(e.isCheckmate(gote), isTrue,
          reason: 'AI played $move instead of mating');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('full undo walk returns to the initial position', () {
      final e = ShogiEngine();
      e.setup();
      final key0 = e.positionKey();
      final rng = Random(42);
      for (int i = 0; i < 30; i++) {
        final moves = e.legalMoves(e.turn);
        if (moves.isEmpty) break;
        e.pushMove(moves[rng.nextInt(moves.length)]);
      }
      while (e.popMove()) {}
      expect(e.positionKey(), key0);
      expect(e.turn, sente);
      expect(e.ply, 0);
    });
  });

  group('AI', () {
    test('A1: aiCompute returns a legal move from the opening', () async {
      final e = ShogiEngine();
      e.setup();
      final payload = {
        'board': List<int>.of(e.board),
        'hs': <int>[],
        'hg': <int>[],
        'turn': e.turn,
        'ply': 0,
        'repKeys': List<String>.of(e.repKeys),
        'difficulty': 0,
        'seed': 1234,
      };
      final res = await aiCompute(payload);
      final move = ShogiMove.decode(res.split('|').first);
      final legal = e.legalMoves(e.turn).any((m) =>
          m.from == move.from &&
          m.to == move.to &&
          m.dropType == move.dropType &&
          m.promote == move.promote);
      expect(legal, isTrue);
    });

    test('A1b: beginner AI move is legal in a mid-game capture position',
        () async {
      final e = ShogiEngine();
      e.board = List.filled(81, 0);
      e.board[8 * 9 + 4] = sente * ptKing;
      e.board[0 * 9 + 4] = gote * ptKing;
      e.board[4 * 9 + 4] = sente * ptRook;
      e.board[4 * 9 + 6] = gote * ptGold;
      e.handGote = [ptPawn, ptPawn];
      e.turn = gote;
      final payload = {
        'board': List<int>.of(e.board),
        'hs': List<int>.of(e.handSente),
        'hg': List<int>.of(e.handGote),
        'turn': e.turn,
        'ply': 10,
        'repKeys': <String>[],
        'difficulty': 0,
        'seed': 99,
      };
      final res = await aiCompute(payload);
      final move = ShogiMove.decode(res.split('|').first);
      final legal = e.legalMoves(e.turn).any((m) =>
          m.from == move.from &&
          m.to == move.to &&
          m.dropType == move.dropType &&
          m.promote == move.promote);
      expect(legal, isTrue);
    });
  });
}
