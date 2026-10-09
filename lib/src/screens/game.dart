/// Board screen: 9x9 shogi on kaya wood, komadai trays, dialogs.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ai.dart';
import '../audio.dart';
import '../engine.dart';
import '../save.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;
  final bool continueSaved;
  const GameScreen(
      {super.key, required this.config, this.continueSaved = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final ShogiEngine _engine = ShogiEngine();
  late GameConfig _config;

  // Selection.
  int? _sel;
  int? _selHandType;
  Map<int, List<ShogiMove>> _targets = {};

  // Board chrome.
  int? _lastFrom;
  int? _lastTo;
  int? _checkSq;
  List<ShogiMove> _legalForTurn = [];

  // Animation.
  late final AnimationController _animCtrl;
  ShogiMove? _animMove;
  int _animPiece = 0;
  late final AnimationController _shakeCtrl;
  int? _shakeSq;

  // Flow.
  bool _thinking = false;
  bool _over = false;
  bool _reviewing = false; // game-over card dismissed, board read-only
  int? _winner; // sente/gote/null
  String _endReason = '';
  String _endTitle = '';
  int _invalidStreak = 0;
  int _elapsed = 0;
  Timer? _clock;
  int _lastBotScore = 0;
  int _botGen = 0; // guards stale bot results

  SettingsService get _s => SettingsService.I;
  PieceWood get _wood => pieceWoods[_s.pieceStyle] ?? pieceWoods['kaya']!;
  BoardWood get _boardWood =>
      boardWoods[_s.boardWood] ?? boardWoods['kaya']!;

  bool get _isBotMode => _config.mode == 'bot';
  int get _humanColor => _config.humanColor;
  bool _isHumanTurn() =>
      !_isBotMode || _engine.turn == _humanColor;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    WidgetsBinding.instance.addObserver(this);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 230));
    _animCtrl.addListener(() => setState(() {}));
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _shakeCtrl.addListener(() => setState(() {}));
    if (widget.continueSaved) {
      _restore();
    } else {
      _newGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _animCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_persist());
      unawaited(AudioService.I.stopMusic());
    } else if (state == AppLifecycleState.resumed) {
      if (!_over) AudioService.I.gameMusic();
    }
  }

  // ------------------------------------------------------------ setup/flow

  void _newGame() {
    _engine.setup(handicap: _config.handicap);
    _lastFrom = null;
    _lastTo = null;
    _checkSq = null;
    _over = false;
    _reviewing = false;
    _winner = null;
    _elapsed = 0;
    _invalidStreak = 0;
    _clearSelection();
    _refreshTurn();
    unawaited(GameSave.clear());
    unawaited(AudioService.I.gameStart());
    unawaited(AudioService.I.gameMusic());
    _startClock();
    _maybeBot();
    setState(() {});
  }

  Future<void> _restore() async {
    final data = await GameSave.load();
    if (data == null) {
      _newGame();
      return;
    }
    _config = GameConfig.fromJson(
        Map<String, dynamic>.from(data['config'] as Map));
    _engine.fromMap(Map<String, dynamic>.from(data['engine'] as Map));
    _lastFrom = data['lastFrom'] as int?;
    _lastTo = data['lastTo'] as int?;
    _elapsed = data['elapsed'] as int? ?? 0;
    _over = false;
    _reviewing = false;
    _clearSelection();
    _refreshTurn();
    unawaited(AudioService.I.gameMusic());
    _startClock();
    _maybeBot();
    setState(() {});
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_over && mounted) setState(() => _elapsed++);
    });
  }

  void _refreshTurn() {
    _legalForTurn = _engine.legalMoves(_engine.turn);
    _checkSq = _engine.inCheck(_engine.turn)
        ? _engine.kingSquare(_engine.turn)
        : null;
  }

  Future<void> _persist() async {
    if (_over) return;
    await GameSave.store({
      'config': _config.toJson(),
      'engine': _engine.toMap(),
      'lastFrom': _lastFrom,
      'lastTo': _lastTo,
      'elapsed': _elapsed,
    });
  }

  // ------------------------------------------------------------------ input

  void _clearSelection() {
    _sel = null;
    _selHandType = null;
    _targets = {};
  }

  void _onTapSquare(int sq) {
    if (_over || _reviewing || _thinking) return;
    if (!_isHumanTurn()) return;
    final moves = _targets[sq];
    if (moves != null && moves.isNotEmpty) {
      if (moves.length == 2) {
        _askPromotion(moves);
      } else {
        _playHumanMove(moves.first);
      }
      return;
    }
    final p = _engine.board[sq];
    if (p != 0 && pColor(p) == _engine.turn) {
      final mine = _legalForTurn.where((m) => m.from == sq).toList();
      if (mine.isEmpty) {
        _invalid(sq);
        return;
      }
      _sel = sq;
      _selHandType = null;
      _targets = {};
      for (final m in mine) {
        _targets.putIfAbsent(m.to, () => []).add(m);
      }
      AudioService.I.select();
      _invalidStreak = 0;
      setState(() {});
    } else {
      if (_sel != null || _selHandType != null) {
        _clearSelection();
        setState(() {});
      }
    }
  }

  void _onTapHand(int type) {
    if (_over || _reviewing || _thinking) return;
    if (!_isHumanTurn()) return;
    final drops =
        _legalForTurn.where((m) => m.isDrop && m.dropType == type).toList();
    if (drops.isEmpty) {
      _invalid(-1);
      return;
    }
    _sel = null;
    _selHandType = type;
    _targets = {for (final m in drops) m.to: [m]};
    AudioService.I.select();
    _invalidStreak = 0;
    setState(() {});
  }

  void _invalid(int sq) {
    _invalidStreak++;
    AudioService.I.invalid();
    if (sq >= 0) {
      _shakeSq = sq;
      _shakeCtrl.forward(from: 0);
    }
    if (_invalidStreak >= 3) {
      _invalidStreak = 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('その手は指せません — check how this piece moves',
              style: TextStyle(color: ShogiPalette.washi)),
          backgroundColor: ShogiPalette.lacquer,
          duration: Duration(seconds: 2),
        ));
      }
    }
    setState(() {});
  }

  Future<void> _askPromotion(List<ShogiMove> options) async {
    final promoteFirst = options.firstWhere((m) => m.promote);
    final keepFirst = options.firstWhere((m) => !m.promote);
    final piece = _engine.board[promoteFirst.from];
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PromotionDialog(piece: piece, wood: _wood),
    );
    if (!mounted) return;
    // Dismissed dialog counts as decline (unless mandatory — but mandatory
    // never reaches the dialog).
    _playHumanMove(result == true ? promoteFirst : keepFirst);
  }

  void _playHumanMove(ShogiMove m) {
    if (m.promote) {
      AudioService.I.promote();
    }
    _commitMove(m);
  }

  // ------------------------------------------------------------------ moves

  void _commitMove(ShogiMove m) {
    final pieceBefore = m.isDrop ? _engine.turn * m.dropType : _engine.board[m.from];
    final wasCapture = !m.isDrop && _engine.board[m.to] != 0;
    _engine.applyMove(m);
    _lastFrom = m.from >= 0 ? m.from : null;
    _lastTo = m.to;
    _clearSelection();
    _invalidStreak = 0;
    _engine.recordPosition();

    // Animation.
    _animMove = m;
    _animPiece = pieceBefore;
    _animCtrl.forward(from: 0);

    // Sounds.
    if (wasCapture) {
      AudioService.I.capture();
    } else if (m.isDrop) {
      AudioService.I.drop();
    } else if (!m.promote) {
      AudioService.I.move();
    }

    _refreshTurn();
    unawaited(_persist());

    // End-of-game checks.
    final rep = _engine.sennichiteResult();
    if (rep != 0) {
      if (rep == 1) {
        _finish(null, '千日手', 'Repetition draw — sennichite');
      } else {
        final loser = rep == 2 ? sente : gote;
        _finish(-loser, '詰み',
            'Perpetual check — ${_name(-loser)} wins');
      }
      setState(() {});
      return;
    }
    if (_engine.isCheckmate(_engine.turn)) {
      final winner = -_engine.turn;
      _finish(winner, '詰み', 'Checkmate — ${_name(winner)} wins');
      setState(() {});
      return;
    }
    if (_engine.inCheck(_engine.turn)) {
      AudioService.I.check();
    }
    setState(() {});
    _maybeBot();
  }

  void _maybeBot() {
    if (_over || !_isBotMode) return;
    if (_engine.turn == _humanColor) return;
    _thinking = true;
    _botGen++;
    final gen = _botGen;
    setState(() {});
    final payload = {
      'board': List<int>.of(_engine.board),
      'hs': List<int>.of(_engine.handSente),
      'hg': List<int>.of(_engine.handGote),
      'turn': _engine.turn,
      'ply': _engine.ply,
      'repKeys': List<String>.of(_engine.repKeys),
      'difficulty': _config.difficulty,
      'seed': DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
    };
    compute(aiCompute, payload).then((encoded) {
      if (!mounted || _over || gen != _botGen) return;
      _thinking = false;
      final parts = encoded.split('|');
      _lastBotScore = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final move = ShogiMove.decode(parts[0]);
      // Sanity: the AI must only play legal moves.
      final ok = _engine
          .legalMoves(_engine.turn)
          .any((m) =>
              m.from == move.from &&
              m.to == move.to &&
              m.dropType == move.dropType &&
              m.promote == move.promote);
      if (!ok) {
        // Fallback: first legal move (should never happen).
        final legal = _engine.legalMoves(_engine.turn);
        if (legal.isEmpty) return;
        _commitMove(legal.first);
        return;
      }
      if (move.promote) AudioService.I.promote();
      _commitMove(move);
    });
  }

  void _finish(int? winner, String title, String reason) {
    _over = true;
    _winner = winner;
    _endTitle = title;
    _endReason = reason;
    _clock?.cancel();
    _thinking = false;
    _botGen++; // invalidate any in-flight bot search
    unawaited(GameSave.clear());
    if (winner == null) {
      AudioService.I.draw();
    } else if (!_isBotMode || winner == _humanColor) {
      AudioService.I.win();
    } else {
      AudioService.I.lose();
    }
  }

  String _name(int color) =>
      color == sente ? _config.senteName : _config.goteName;

  // ---------------------------------------------------------------- actions

  void _undo() {
    if (_over || _thinking || _engine.history.isEmpty) return;
    if (!_s.allowUndo) return;
    final before = _engine.ply;
    if (_isBotMode) {
      // Undo a full round: the bot's reply (if any), then the human's move.
      _popPly();
      if (_engine.history.isNotEmpty && _engine.turn != _humanColor) {
        _popPly();
      }
    } else {
      _popPly();
    }
    if (_engine.ply == before) return; // nothing undone
    _lastFrom = null;
    _lastTo = null;
    _clearSelection();
    _refreshTurn();
    unawaited(_persist());
    setState(() {});
  }

  void _popPly() {
    final u = _engine.history.removeLast();
    _engine.undoMove(u);
    _engine.truncateRepetition(_engine.repKeys.length - 1);
  }

  Future<void> _resign() async {
    if (_over || _thinking) return;
    final me = _engine.turn;
    if (!_isHumanTurn()) return;
    var ok = true;
    if (_s.confirmResign) {
      ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => _ConfirmDialog(
              title: '投了 Resign?',
              body: 'Resign this game? ${_name(-me)} wins.',
              confirmKanji: '投了',
              confirmLabel: 'Resign',
            ),
          ) ??
          false;
    }
    if (!ok || !mounted) return;
    AudioService.I.lose();
    _finish(-me, '投了', 'Resignation — ${_name(-me)} wins');
    setState(() {});
  }

  Future<void> _offerDraw() async {
    if (_over || _thinking) return;
    if (!_isHumanTurn()) return;
    final me = _engine.turn;
    if (_isBotMode) {
      // Bot accepts only when clearly losing.
      if (_lastBotScore < -400) {
        _finish(null, '和', 'Draw agreed — the bot accepts');
      } else {
        AudioService.I.click();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bot declines the draw — the fight continues!',
                style: TextStyle(color: ShogiPalette.washi)),
            backgroundColor: ShogiPalette.lacquer,
            duration: Duration(seconds: 2),
          ));
        }
      }
      setState(() {});
      return;
    }
    final offer = await showDialog<bool>(
          context: context,
          builder: (ctx) => _ConfirmDialog(
            title: '千日手 Draw offer',
            body: '${_name(me)} offers a draw. Show this to ${_name(-me)}.',
            confirmKanji: '申',
            confirmLabel: 'Offer draw',
          ),
        ) ??
        false;
    if (!offer || !mounted) return;
    final accept = await showDialog<bool>(
          context: context,
          builder: (ctx) => _ConfirmDialog(
            title: '和 Draw?',
            body: '${_name(me)} offers a draw. ${_name(-me)}, accept?',
            confirmKanji: '和',
            confirmLabel: 'Accept draw',
          ),
        ) ??
        false;
    if (accept) {
      _finish(null, '和', 'Draw by mutual agreement');
      setState(() {});
    }
  }

  Future<void> _pauseMenu() async {
    if (_over) return;
    AudioService.I.click();
    unawaited(_persist());
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => const _PauseDialog(),
    );
    if (!mounted) return;
    switch (action) {
      case 'resume':
        break;
      case 'restart':
        final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => const _ConfirmDialog(
                title: '最初から Restart?',
                body: 'Start a new game with the same settings?',
                confirmKanji: '再',
                confirmLabel: 'Restart',
              ),
            ) ??
            false;
        if (ok) _newGame();
      case 'settings':
        await Navigator.of(context).pushNamed('/settings');
        setState(() {}); // visuals may have changed
        unawaited(AudioService.I.refresh());
      case 'menu':
        unawaited(_persist());
        unawaited(AudioService.I.menuMusic());
        Navigator.of(context).pop();
    }
  }

  // ------------------------------------------------------------------ build

  String _clockText() {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Tatami backdrop.
          Positioned.fill(
            child: CustomPaint(painter: TatamiPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 6),
                // Gote komadai.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Komadai(
                    hand: _engine.handGote,
                    color: gote,
                    wood: _wood,
                    interactive:
                        _isHumanTurn() && _engine.turn == gote && !_over,
                    selectedType:
                        _engine.turn == gote ? _selHandType : null,
                    onTapType: _onTapHand,
                  ),
                ),
                const SizedBox(height: 6),
                // Board.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ShogiBoard(
                      view: BoardView(
                        board: _engine.board,
                        wood: _wood,
                        boardWood: _boardWood,
                        selected: _sel,
                        targets: _s.showLegalDots
                            ? _targets.keys.toSet()
                            : const {},
                        captureTargets: _targets.entries
                            .where((e) =>
                                _engine.board[e.key] != 0 &&
                                pColor(_engine.board[e.key]) !=
                                    _engine.turn)
                            .map((e) => e.key)
                            .toSet(),
                        lastFrom: _lastFrom,
                        lastTo: _lastTo,
                        checkSquare: _checkSq,
                        showCoords: _s.showCoordinates,
                        animMove: _animMove,
                        animPiece: _animPiece,
                        animT: _animCtrl.value,
                        shakeSquare: _shakeSq,
                        shakeT: _shakeCtrl.value,
                      ),
                      onTapSquare: _onTapSquare,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Sente komadai.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Komadai(
                    hand: _engine.handSente,
                    color: sente,
                    wood: _wood,
                    interactive:
                        _isHumanTurn() && _engine.turn == sente && !_over,
                    selectedType:
                        _engine.turn == sente ? _selHandType : null,
                    onTapType: _onTapHand,
                  ),
                ),
                const SizedBox(height: 8),
                _actionBar(),
                const SizedBox(height: 10),
              ],
            ),
          ),
          if (_thinking) _thinkingChip(),
          if (_over && !_reviewing) _gameOverCard(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: ShogiPalette.lacquer,
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _playerChip(
              _config.goteName,
              '後手',
              _engine.turn == gote && !_over,
              _engine.handGote.length,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ShogiPalette.kayaDeep,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: ShogiPalette.emberGold, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(_engine.ply ~/ 2) + 1}手',
                    style: ShogiType.stat.copyWith(
                        color: ShogiPalette.washi, fontSize: 14)),
                Text(_clockText(),
                    style: const TextStyle(
                        color: ShogiPalette.washi,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          Expanded(
            child: _playerChip(
              _config.senteName,
              '先手',
              _engine.turn == sente && !_over,
              _engine.handSente.length,
            ),
          ),
          const SizedBox(width: 6),
          DiscButton(icon: Icons.pause, onTap: _pauseMenu, size: 42),
        ],
      ),
    );
  }

  Widget _playerChip(
      String name, String tag, bool active, int captured) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: active ? ShogiPalette.vermilion : ShogiPalette.lacquerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: active
                ? ShogiPalette.emberGold
                : const Color(0xFF3A332C),
            width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag,
              style: ShogiType.kanji(14, ShogiPalette.washi, spacing: 1)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ShogiPalette.washi,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('×$captured',
                style: const TextStyle(
                    color: ShogiPalette.emberGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionPlaque('待', 'Undo', Icons.undo, _undo),
        _actionPlaque('和', 'Draw', Icons.handshake, _offerDraw),
        _actionPlaque('投', 'Resign', Icons.flag, _resign),
      ],
    );
  }

  Widget _actionPlaque(
      String kanji, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        onTap();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: ShogiMaterials.plaqueButton(radius: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(kanji,
                style: ShogiType.kanji(16, ShogiPalette.lacquer, spacing: 1)),
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: ShogiPalette.lacquer),
            const SizedBox(width: 4),
            Text(label,
                style: ShogiType.title(13, ShogiPalette.lacquer)),
          ],
        ),
      ),
    );
  }

  Widget _thinkingChip() {
    return Positioned(
      top: 86,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: ShogiMaterials.lacquerPanel(radius: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ShogiPalette.emberGold),
              ),
              const SizedBox(width: 8),
              Text('考え中…',
                  style:
                      ShogiType.kanji(15, ShogiPalette.washi, spacing: 3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameOverCard() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 340,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: ShogiMaterials.washiCard(),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                            painter: WashiPainter(seed: 9)),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_endTitle,
                              style: ShogiType.kanji(
                                  52, ShogiPalette.ink,
                                  spacing: 10)),
                          if (_winner != null)
                            Text('${_name(_winner!)} wins',
                                style: ShogiType.title(
                                    19, ShogiPalette.vermilion)),
                          const SizedBox(height: 4),
                          Text(_endReason,
                              textAlign: TextAlign.center,
                              style: ShogiType.body(
                                  15, ShogiPalette.ink)),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              _statPlaque(
                                  '手数', '${(_engine.ply ~/ 2) + 1}'),
                              _statPlaque('時間', _clockText()),
                              _statPlaque('駒取',
                                  '${_engine.capturedCount()}'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          PlaqueButton(
                            kanji: '再',
                            label: 'Rematch',
                            primary: true,
                            width: 220,
                            onTap: () {
                              AudioService.I.click();
                              _newGame();
                            },
                          ),
                          const SizedBox(height: 10),
                          PlaqueButton(
                            kanji: '帰',
                            label: 'Main menu',
                            width: 220,
                            onTap: () {
                              AudioService.I.click();
                              unawaited(AudioService.I.menuMusic());
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              AudioService.I.click();
                              setState(() => _reviewing = true);
                            },
                            child: const Text('盤面を見る — Review board',
                                style: TextStyle(
                                    color: ShogiPalette.vermilion,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -18,
                  right: -8,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: const SealStamp(kanji: '終', size: 52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statPlaque(String label, String value) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ShogiPalette.kayaAmber.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShogiPalette.kayaDeep, width: 1),
      ),
      child: Column(
        children: [
          Text(label,
              style: ShogiType.caption.copyWith(fontSize: 11)),
          Text(value, style: ShogiType.stat),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class _PromotionDialog extends StatelessWidget {
  final int piece;
  final PieceWood wood;
  const _PromotionDialog({required this.piece, required this.wood});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: ShogiMaterials.washiCard(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('成りますか？',
                style: ShogiType.kanji(26, ShogiPalette.ink, spacing: 4)),
            const SizedBox(height: 2),
            const Text('Promote this piece?',
                style: TextStyle(color: ShogiPalette.warmGray)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShogiPiece(piece: piece, size: 54, wood: wood),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward,
                      color: ShogiPalette.vermilion),
                ),
                ShogiPiece(
                    piece: pColor(piece) *
                        promoteType(pType(piece)),
                    size: 54,
                    wood: wood),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PlaqueButton(
                  kanji: '成',
                  label: 'Promote',
                  primary: true,
                  width: 130,
                  onTap: () {
                    AudioService.I.click();
                    Navigator.of(context).pop(true);
                  },
                ),
                PlaqueButton(
                  kanji: '不成',
                  label: 'Keep',
                  width: 130,
                  onTap: () {
                    AudioService.I.click();
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmKanji;
  final String confirmLabel;
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmKanji,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: ShogiMaterials.washiCard(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: ShogiType.kanji(24, ShogiPalette.ink, spacing: 3)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: ShogiType.body(14, ShogiPalette.ink)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PlaqueButton(
                  kanji: confirmKanji,
                  label: confirmLabel,
                  primary: true,
                  width: 130,
                  onTap: () {
                    AudioService.I.click();
                    Navigator.of(context).pop(true);
                  },
                ),
                PlaqueButton(
                  kanji: '戻',
                  label: 'Cancel',
                  width: 130,
                  onTap: () {
                    AudioService.I.click();
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PauseDialog extends StatelessWidget {
  const _PauseDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: ShogiMaterials.washiCard(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('休止中',
                style: ShogiType.kanji(30, ShogiPalette.ink, spacing: 8)),
            const Text('Paused',
                style: TextStyle(color: ShogiPalette.warmGray)),
            const SizedBox(height: 16),
            PlaqueButton(
              kanji: '続',
              label: 'Resume',
              primary: true,
              width: 200,
              onTap: () {
                AudioService.I.click();
                Navigator.of(context).pop('resume');
              },
            ),
            const SizedBox(height: 10),
            PlaqueButton(
              kanji: '再',
              label: 'Restart',
              width: 200,
              onTap: () {
                AudioService.I.click();
                Navigator.of(context).pop('restart');
              },
            ),
            const SizedBox(height: 10),
            PlaqueButton(
              kanji: '設',
              label: 'Settings',
              width: 200,
              onTap: () {
                AudioService.I.click();
                Navigator.of(context).pop('settings');
              },
            ),
            const SizedBox(height: 10),
            PlaqueButton(
              kanji: '帰',
              label: 'Main menu',
              width: 200,
              onTap: () {
                AudioService.I.click();
                Navigator.of(context).pop('menu');
              },
            ),
          ],
        ),
      ),
    );
  }
}


