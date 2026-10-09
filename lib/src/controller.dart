/// GameController — engine-owned turn state machine + watchdog.
///
/// The engine (not UI timers) owns turn phases and advances the game.
/// A watchdog timer recovers any phase found without forward progress,
/// so stuck states are impossible by construction.
///
/// Every move — human or bot — flows through [commitMove], which pushes
/// the move into the engine, publishes a narration line ("Sente plays
/// P-2f"), bumps [fxTick] so the UI animates it visibly, then settles the
/// resulting position (repetition, checkmate, bot reply).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai.dart';
import 'audio.dart';
import 'engine.dart';
import 'save.dart';
import 'settings.dart';

enum GamePhase { idle, botThinking, promoAsk, animating, over }

class GameController extends ChangeNotifier {
  final ShogiEngine engine = ShogiEngine();
  GameConfig config;

  GamePhase phase = GamePhase.idle;
  String narration = '';
  int fxTick = 0; // bumped on every move so the UI replays the animation
  ShogiMove? animMove;
  int animPiece = 0;

  int? lastFrom;
  int? lastTo;
  int? checkSq;
  List<ShogiMove> legalForTurn = [];

  bool over = false;
  bool reviewing = false;
  int? winner; // sente / gote / null (draw)
  String endTitle = '';
  String endReason = '';

  int invalidStreak = 0;
  int elapsed = 0;
  int lastBotScore = 0;

  // Promotion choice pending (UI shows the dialog while phase == promoAsk).
  List<ShogiMove> promoOptions = [];

  // Impasse result pending confirmation.
  Map<String, dynamic>? impasseOffer;

  Timer? _clock;
  Timer? _watchdog;
  int _botGen = 0;
  bool _botRunning = false;
  DateTime _phaseSince = DateTime.now();
  bool _disposed = false;

  SettingsService get _s => SettingsService.I;
  bool get isBotMode => config.mode == 'bot';
  int get humanColor => config.humanColor;
  bool get isHumanTurn =>
      !isBotMode || engine.turn == humanColor;

  String nameOf(int color) =>
      color == sente ? config.senteName : config.goteName;

  GameController(this.config);

  // ------------------------------------------------------------ lifecycle

  void start() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _watch());
    newGame();
  }

  void newGame() {
    engine.setup(handicap: config.handicap);
    lastFrom = null;
    lastTo = null;
    over = false;
    reviewing = false;
    winner = null;
    endTitle = '';
    endReason = '';
    invalidStreak = 0;
    elapsed = 0;
    impasseOffer = null;
    _botGen++; // invalidate any in-flight bot search
    _botRunning = false;
    _refreshTurn();
    _setPhase(GamePhase.idle);
    narration = '${nameOf(engine.turn)} to move';
    unawaited(GameSave.clear());
    unawaited(AudioService.I.gameStart());
    unawaited(AudioService.I.gameMusic());
    _startClock();
    notifyListeners();
    _afterMoveSettled(initial: true);
  }

  Future<void> restore() async {
    final data = await GameSave.load();
    if (data == null || _disposed) {
      newGame();
      return;
    }
    try {
      config = GameConfig.fromJson(
          Map<String, dynamic>.from(data['config'] as Map));
      engine.fromMap(Map<String, dynamic>.from(data['engine'] as Map));
    } catch (_) {
      newGame();
      return;
    }
    lastFrom = data['lastFrom'] as int?;
    lastTo = data['lastTo'] as int?;
    elapsed = data['elapsed'] as int? ?? 0;
    over = false;
    reviewing = false;
    _refreshTurn();
    _setPhase(GamePhase.idle);
    narration = '${nameOf(engine.turn)} to move';
    unawaited(AudioService.I.gameMusic());
    _startClock();
    notifyListeners();
    _afterMoveSettled(initial: true);
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!over && !_disposed) {
        elapsed++;
        notifyListeners();
      }
    });
  }

  void setAppPaused(bool paused) {
    if (paused) {
      unawaited(persist());
      unawaited(AudioService.I.onAppPaused());
    } else {
      if (!over) unawaited(AudioService.I.onAppResumed());
    }
  }

  Future<void> persist() async {
    if (over || _disposed) return;
    await GameSave.store({
      'config': config.toJson(),
      'engine': engine.toMap(),
      'lastFrom': lastFrom,
      'lastTo': lastTo,
      'elapsed': elapsed,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _watchdog?.cancel();
    _botGen++;
    super.dispose();
  }

  // ----------------------------------------------------------------- phases

  void _setPhase(GamePhase p) {
    phase = p;
    _phaseSince = DateTime.now();
  }

  void _refreshTurn() {
    legalForTurn = engine.legalMoves(engine.turn);
    checkSq =
        engine.inCheck(engine.turn) ? engine.kingSquare(engine.turn) : null;
  }

  /// Watchdog: recovers any phase that lost its forward progress.
  void _watch() {
    if (_disposed || over) return;
    final stuckFor = DateTime.now().difference(_phaseSince);
    switch (phase) {
      case GamePhase.botThinking:
        // A bot search that never returned (or was never started).
        if (!_botRunning && stuckFor > const Duration(seconds: 6)) {
          _botTurn();
        }
      case GamePhase.idle:
        // Bot's turn with no search running — the trigger was missed.
        if (!isHumanTurn) _botTurn();
      case GamePhase.animating:
        // Animation settle never fired.
        if (stuckFor > const Duration(seconds: 4)) {
          _afterMoveSettled();
        }
      case GamePhase.promoAsk:
        // Modal dialog — the user must answer; nothing to recover.
        break;
      case GamePhase.over:
        break;
    }
  }

  // ------------------------------------------------------------------- moves

  /// Human commits a move (already validated against [legalForTurn]).
  void humanMove(ShogiMove m) {
    if (over || reviewing) return;
    if (!isHumanTurn) return;
    if (phase != GamePhase.idle) return;
    if (m.promote) unawaited(AudioService.I.promote());
    _commitMove(m, byBot: false);
  }

  /// Human asks for the promotion choice dialog.
  void askPromotion(List<ShogiMove> options) {
    if (over || phase != GamePhase.idle || !isHumanTurn) return;
    promoOptions = options;
    _setPhase(GamePhase.promoAsk);
    notifyListeners();
  }

  /// Resolves the pending promotion dialog. Dismissal counts as decline
  /// (RULES.md §12.9); mandatory promotion never reaches the dialog.
  void resolvePromotion(bool? promote) {
    if (phase != GamePhase.promoAsk || promoOptions.isEmpty) return;
    final opts = promoOptions;
    promoOptions = [];
    final pick = promote == true
        ? opts.firstWhere((m) => m.promote)
        : opts.firstWhere((m) => !m.promote);
    _setPhase(GamePhase.idle);
    if (pick.promote) unawaited(AudioService.I.promote());
    _commitMove(pick, byBot: false);
  }

  void _commitMove(ShogiMove m, {required bool byBot}) {
    final mover = engine.turn;
    final movedPiece =
        m.isDrop ? mover * m.dropType : engine.board[m.from];
    final wasCapture = !m.isDrop && engine.board[m.to] != 0;
    engine.pushMove(m);
    lastFrom = m.from >= 0 ? m.from : null;
    lastTo = m.to;
    invalidStreak = 0;

    // Visible animation hook for the UI.
    animMove = m;
    animPiece = movedPiece;
    fxTick++;

    // Narration — every move is announced, never silently auto-played.
    final label = ShogiEngine.describeMove(m, movedPiece);
    final verb = m.isDrop ? 'drops' : 'plays';
    narration = '${nameOf(mover)} $verb $label';

    if (wasCapture) {
      unawaited(AudioService.I.capture());
    } else if (m.isDrop) {
      unawaited(AudioService.I.drop());
    } else if (!m.promote) {
      unawaited(AudioService.I.move());
    }

    _refreshTurn();
    unawaited(persist());

    _setPhase(GamePhase.animating);
    notifyListeners();
    // Let the move animation + narration breathe before settling.
    Future.delayed(
        Duration(milliseconds: byBot ? 700 : 380), _afterMoveSettled);
  }

  /// Settles the position after a move: end-of-game checks, then the next
  /// turn (bot reply if needed). Idempotent — safe to call twice.
  void _afterMoveSettled({bool initial = false}) {
    if (_disposed || over) return;
    if (!initial && phase != GamePhase.animating && phase != GamePhase.idle) {
      return;
    }
    // Repetition / perpetual check.
    final rep = engine.sennichiteResult();
    if (rep != 0) {
      if (rep == 1) {
        finish(null, '千日手', 'Repetition draw — sennichite');
      } else {
        final loser = rep == 2 ? sente : gote;
        finish(-loser, '詰み', 'Perpetual check — ${nameOf(-loser)} wins');
      }
      return;
    }
    if (engine.isCheckmate(engine.turn)) {
      final w = -engine.turn;
      finish(w, '詰み', 'Checkmate — ${nameOf(w)} wins');
      return;
    }
    if (!engine.hasLegalMove(engine.turn)) {
      // Stalemate is a loss per RULES.md §12.7 (no passing; a player with
      // no legal move loses). This also guarantees the bot is never asked
      // to move from a moveless position — no stuck states, ever.
      final w = -engine.turn;
      finish(w, '詰み', 'No legal moves — ${nameOf(w)} wins');
      return;
    }
    if (!initial && engine.inCheck(engine.turn)) {
      unawaited(AudioService.I.check());
      narration = '$narration — check!';
    }
    _setPhase(GamePhase.idle);
    notifyListeners();
    if (!isHumanTurn) _botTurn();
  }

  // --------------------------------------------------------------------- bot

  void _botTurn() {
    if (_disposed || over) return;
    if (isHumanTurn) return;
    if (_botRunning) return;
    _botRunning = true;
    _botGen++;
    final gen = _botGen;
    _setPhase(GamePhase.botThinking);
    narration = '${nameOf(engine.turn)} is thinking…';
    notifyListeners();

    // A beat of visible "thinking" — bot turns are never instant.
    Future.delayed(const Duration(milliseconds: 650), () {
      if (_disposed || over || gen != _botGen) {
        _botRunning = false;
        return;
      }
      final payload = {
        'board': List<int>.of(engine.board),
        'hs': List<int>.of(engine.handSente),
        'hg': List<int>.of(engine.handGote),
        'turn': engine.turn,
        'ply': engine.ply,
        'repKeys': List<String>.of(engine.repKeys),
        'difficulty': config.difficulty,
        'seed': DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      };
      compute(aiCompute, payload).then((encoded) {
        _botRunning = false;
        if (_disposed || over || gen != _botGen) return;
        final parts = encoded.split('|');
        lastBotScore = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        final move = ShogiMove.decode(parts[0]);
        // Sanity: the AI must only play legal moves.
        final ok = engine.legalMoves(engine.turn).any((m) =>
            m.from == move.from &&
            m.to == move.to &&
            m.dropType == move.dropType &&
            m.promote == move.promote);
        if (!ok) {
          // Fallback: first legal move (should never happen).
          final legal = engine.legalMoves(engine.turn);
          if (legal.isEmpty) return;
          if (move.promote || legal.first.promote) {
            unawaited(AudioService.I.promote());
          }
          _commitMove(legal.first, byBot: true);
          return;
        }
        if (move.promote) unawaited(AudioService.I.promote());
        _commitMove(move, byBot: true);
      }).catchError((_) {
        _botRunning = false;
        // Search failed — the watchdog will retry shortly.
      });
    });
  }

  // ------------------------------------------------------------------ finish

  void finish(int? win, String title, String reason) {
    if (over) return;
    over = true;
    winner = win;
    endTitle = title;
    endReason = reason;
    _setPhase(GamePhase.over);
    _clock?.cancel();
    _botGen++; // invalidate any in-flight bot search
    _botRunning = false;
    unawaited(GameSave.clear());
    if (win == null) {
      unawaited(AudioService.I.draw());
    } else if (!isBotMode || win == humanColor) {
      unawaited(AudioService.I.win());
    } else {
      unawaited(AudioService.I.lose());
    }
    notifyListeners();
  }

  String clockText() {
    final m = elapsed ~/ 60;
    final s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ----------------------------------------------------------------- actions

  void invalidTap() {
    invalidStreak++;
    unawaited(AudioService.I.invalid());
    if (invalidStreak >= 3) {
      invalidStreak = 0;
      narration = 'その手は指せません — check how this piece moves';
    }
    notifyListeners();
  }

  /// Undo: one full round in bot mode (bot reply + human move), one ply in 2p.
  void undo() {
    if (over || phase != GamePhase.idle) return;
    if (!_s.allowUndo) return;
    if (!isHumanTurn) return;
    final before = engine.ply;
    if (isBotMode) {
      engine.popMove();
      if (engine.history.isNotEmpty && engine.turn != humanColor) {
        engine.popMove();
      }
    } else {
      engine.popMove();
    }
    if (engine.ply == before) return;
    lastFrom = null;
    lastTo = null;
    animMove = null;
    narration = '${nameOf(engine.turn)} to move';
    _refreshTurn();
    unawaited(persist());
    notifyListeners();
  }

  void resign() {
    if (over || phase == GamePhase.over) return;
    if (!isHumanTurn) return;
    final me = engine.turn;
    unawaited(AudioService.I.lose());
    finish(-me, '投了', 'Resignation — ${nameOf(-me)} wins');
  }

  /// Draw offer. In bot mode the bot accepts only when clearly losing.
  /// Returns a message for the UI snackbar, or null when a dialog flow ran.
  String? offerDraw() {
    if (over || !isHumanTurn || phase != GamePhase.idle) return null;
    if (isBotMode) {
      if (lastBotScore < -400) {
        finish(null, '和', 'Draw agreed — ${nameOf(-humanColor)} accepts');
      } else {
        return 'Bot declines the draw — the fight continues!';
      }
      return null;
    }
    return 'DIALOG'; // 2p: UI runs the offer/accept dialogs
  }

  void acceptDraw() => finish(null, '和', 'Draw by mutual agreement');

  // ----------------------------------------------------------------- impasse

  /// Impasse (jishōgi) declaration, RULES.md §7.5: available when both
  /// kings have entered the opposing camps.
  bool get canDeclareImpasse =>
      !over &&
      phase == GamePhase.idle &&
      isHumanTurn &&
      engine.bothKingsEntered();

  /// Builds the impasse offer (counts for both sides) for the UI dialog.
  void prepareImpasseOffer() {
    if (!canDeclareImpasse) return;
    impasseOffer = {
      'declarer': engine.turn,
      'sentePoints': engine.impassePoints(sente),
      'gotePoints': engine.impassePoints(gote),
      'verdict': engine.adjudicateImpasse(engine.turn),
    };
    notifyListeners();
  }

  void clearImpasseOffer() {
    impasseOffer = null;
    notifyListeners();
  }

  /// Resolves a confirmed impasse declaration per RULES.md §8/§10.4.
  void confirmImpasse() {
    final offer = impasseOffer;
    if (offer == null) return;
    impasseOffer = null;
    final declarer = offer['declarer'] as int;
    final sp = offer['sentePoints'] as int;
    final gp = offer['gotePoints'] as int;
    final verdict = offer['verdict'] as String;
    final detail =
        'Impasse count — ${nameOf(sente)} $sp pts, ${nameOf(gote)} $gp pts';
    if (verdict == 'sente') {
      finish(sente, '持将棋', '$detail. ${nameOf(sente)} wins the impasse');
    } else if (verdict == 'gote') {
      finish(gote, '持将棋', '$detail. ${nameOf(gote)} wins the impasse');
    } else {
      finish(null, '持将棋', '$detail. Neither side reaches 24 — draw');
    }
    assert(declarer == sente || declarer == gote);
  }
}
