/// Board screen: 9x9 shogi on kaya wood, per-side komadai trays,
/// visible bot turns with narration, impasse flow, dialogs.
///
/// All turn state lives in [GameController]; this screen only renders
/// and forwards input.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../controller.dart';
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
  late GameController _ctl;

  // Selection.
  int? _sel;
  int? _selHandType;
  Map<int, List<ShogiMove>> _targets = {};

  // Animation.
  late final AnimationController _animCtrl;
  late final AnimationController _shakeCtrl;
  int? _shakeSq;
  int _lastFx = -1;

  // Dialog guards.
  bool _promoShown = false;
  bool _impasseShown = false;

  SettingsService get _s => SettingsService.I;
  PieceWood get _wood => pieceWoods[_s.pieceStyle] ?? pieceWoods['kaya']!;
  BoardWood get _boardWood => resolveBoardWood(_s);

  @override
  void initState() {
    super.initState();
    _ctl = GameController(widget.config);
    WidgetsBinding.instance.addObserver(this);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _animCtrl.addListener(() => setState(() {}));
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _shakeCtrl.addListener(() => setState(() {}));
    _ctl.addListener(_onCtl);
    if (widget.continueSaved) {
      _ctl.restore();
    } else {
      _ctl.start();
    }
  }

  void _onCtl() {
    if (!mounted) return;
    // Replay the move animation whenever the controller publishes one.
    if (_ctl.fxTick != _lastFx) {
      _lastFx = _ctl.fxTick;
      _animCtrl.forward(from: 0);
      _clearSelection();
    }
    // Promotion dialog.
    if (_ctl.phase == GamePhase.promoAsk && !_promoShown) {
      _promoShown = true;
      _askPromotion();
    } else if (_ctl.phase != GamePhase.promoAsk) {
      _promoShown = false;
    }
    // Impasse dialog.
    if (_ctl.impasseOffer != null && !_impasseShown) {
      _impasseShown = true;
      _showImpasse();
    } else if (_ctl.impasseOffer == null) {
      _impasseShown = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctl.removeListener(_onCtl);
    _ctl.dispose();
    _animCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ctl.setAppPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      _ctl.setAppPaused(false);
    }
  }

  // ------------------------------------------------------------------ input

  void _clearSelection() {
    _sel = null;
    _selHandType = null;
    _targets = {};
  }

  bool get _inputOpen =>
      !_ctl.over &&
      !_ctl.reviewing &&
      _ctl.isHumanTurn &&
      _ctl.phase == GamePhase.idle;

  void _onTapSquare(int sq) {
    if (!_inputOpen) return;
    final moves = _targets[sq];
    if (moves != null && moves.isNotEmpty) {
      if (moves.length == 2) {
        _ctl.askPromotion(moves);
      } else {
        _ctl.humanMove(moves.first);
      }
      return;
    }
    final p = _ctl.engine.board[sq];
    if (p != 0 && pColor(p) == _ctl.engine.turn) {
      final mine =
          _ctl.legalForTurn.where((m) => m.from == sq).toList();
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
      setState(() {});
    } else {
      if (_sel != null || _selHandType != null) {
        _clearSelection();
        setState(() {});
      }
    }
  }

  void _onTapHand(int type) {
    if (!_inputOpen) return;
    final drops = _ctl.legalForTurn
        .where((m) => m.isDrop && m.dropType == type)
        .toList();
    if (drops.isEmpty) {
      _invalid(-1);
      return;
    }
    _sel = null;
    _selHandType = type;
    _targets = {for (final m in drops) m.to: [m]};
    AudioService.I.select();
    setState(() {});
  }

  void _invalid(int sq) {
    if (sq >= 0) {
      _shakeSq = sq;
      _shakeCtrl.forward(from: 0);
    }
    _ctl.invalidTap();
  }

  Future<void> _askPromotion() async {
    final options = _ctl.promoOptions;
    if (options.isEmpty) {
      _ctl.resolvePromotion(false);
      return;
    }
    final piece = _ctl.engine.board[options.first.from];
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PromotionDialog(piece: piece, wood: _wood),
    );
    if (!mounted) return;
    _ctl.resolvePromotion(result);
  }

  Future<void> _showImpasse() async {
    final offer = _ctl.impasseOffer;
    if (offer == null) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ImpasseDialog(
        declarerName: _ctl.nameOf(offer['declarer'] as int),
        senteName: _ctl.nameOf(sente),
        goteName: _ctl.nameOf(gote),
        sentePoints: offer['sentePoints'] as int,
        gotePoints: offer['gotePoints'] as int,
        verdict: offer['verdict'] as String,
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      _ctl.confirmImpasse();
    } else {
      _ctl.clearImpasseOffer();
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _resign() async {
    if (_ctl.over || !_ctl.isHumanTurn) return;
    var ok = true;
    if (_s.confirmResign) {
      ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => _ConfirmDialog(
              title: '投了 Resign?',
              body:
                  'Resign this game? ${_ctl.nameOf(-_ctl.engine.turn)} wins.',
              confirmKanji: '投了',
              confirmLabel: 'Resign',
            ),
          ) ??
          false;
    }
    if (!ok || !mounted) return;
    AudioService.I.click();
    _ctl.resign();
  }

  Future<void> _offerDraw() async {
    if (_ctl.over || !_ctl.isHumanTurn) return;
    final res = _ctl.offerDraw();
    if (res == null) return;
    if (res == 'DIALOG') {
      final me = _ctl.engine.turn;
      final offer = await showDialog<bool>(
            context: context,
            builder: (ctx) => _ConfirmDialog(
              title: '千日手 Draw offer',
              body:
                  '${_ctl.nameOf(me)} offers a draw. Show this to ${_ctl.nameOf(-me)}.',
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
              body:
                  '${_ctl.nameOf(me)} offers a draw. ${_ctl.nameOf(-me)}, accept?',
              confirmKanji: '和',
              confirmLabel: 'Accept draw',
            ),
          ) ??
          false;
      if (accept) _ctl.acceptDraw();
      return;
    }
    // Bot declined message.
    AudioService.I.click();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res, style: const TextStyle(color: Colors.white)),
        backgroundColor: ShogiPalette.lacquer,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _pauseMenu() async {
    if (_ctl.over) return;
    AudioService.I.click();
    unawaited(_ctl.persist());
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
        if (ok) {
          AudioService.I.click();
          _ctl.newGame();
        }
      case 'settings':
        await Navigator.of(context).pushNamed('/settings');
        setState(() {}); // visuals may have changed
        AudioService.I.configure(
          musicOn: _s.musicOn,
          sfxOn: _s.sfxOn,
          volume: _s.volume,
          musicVolume: _s.musicVolume,
        );
      case 'menu':
        unawaited(_ctl.persist());
        unawaited(AudioService.I.menuMusic());
        Navigator.of(context).pop();
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TatamiPainter())),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                _narrationBar(),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Komadai(
                    name: _ctl.config.goteName,
                    hand: _ctl.engine.handGote,
                    color: gote,
                    wood: _wood,
                    interactive: _inputOpen && _ctl.engine.turn == gote,
                    selectedType:
                        _ctl.engine.turn == gote ? _selHandType : null,
                    onTapType: _onTapHand,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ShogiBoard(
                      view: BoardView(
                        board: _ctl.engine.board,
                        wood: _wood,
                        boardWood: _boardWood,
                        selected: _sel,
                        targets: _s.showLegalDots
                            ? _targets.keys.toSet()
                            : const {},
                        captureTargets: _targets.entries
                            .where((e) =>
                                _ctl.engine.board[e.key] != 0 &&
                                pColor(_ctl.engine.board[e.key]) !=
                                    _ctl.engine.turn)
                            .map((e) => e.key)
                            .toSet(),
                        lastFrom: _ctl.lastFrom,
                        lastTo: _ctl.lastTo,
                        checkSquare: _ctl.checkSq,
                        showCoords: _s.showCoordinates,
                        animMove: _ctl.animMove,
                        animPiece: _ctl.animPiece,
                        animT: _animCtrl.value,
                        shakeSquare: _shakeSq,
                        shakeT: _shakeCtrl.value,
                      ),
                      onTapSquare: _onTapSquare,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Komadai(
                    name: _ctl.config.senteName,
                    hand: _ctl.engine.handSente,
                    color: sente,
                    wood: _wood,
                    interactive: _inputOpen && _ctl.engine.turn == sente,
                    selectedType:
                        _ctl.engine.turn == sente ? _selHandType : null,
                    onTapType: _onTapHand,
                  ),
                ),
                const SizedBox(height: 8),
                _actionBar(),
                const SizedBox(height: 10),
              ],
            ),
          ),
          if (_ctl.phase == GamePhase.botThinking) _thinkingChip(),
          if (_ctl.over && !_ctl.reviewing) _gameOverCard(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ShogiPalette.lacquer,
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _playerChip(
              _ctl.config.goteName,
              '後手',
              _ctl.engine.turn == gote && !_ctl.over,
              _ctl.engine.handGote.length,
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
                Text('${(_ctl.engine.ply ~/ 2) + 1}手',
                    style: ShogiType.stat.copyWith(
                        color: ShogiPalette.washi, fontSize: 14)),
                Text(_ctl.clockText(),
                    style: TextStyle(
                        color: ShogiPalette.washi,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          Expanded(
            child: _playerChip(
              _ctl.config.senteName,
              '先手',
              _ctl.engine.turn == sente && !_ctl.over,
              _ctl.engine.handSente.length,
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
                style: TextStyle(
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
                style: TextStyle(
                    color: ShogiPalette.emberGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Narration banner — every move is announced in words.
  Widget _narrationBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ShogiPalette.lacquer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: ShogiPalette.emberGold.withValues(alpha: 0.5)),
      ),
      child: Text(
        _ctl.narration,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ShogiType.title(13, ShogiPalette.washi),
      ),
    );
  }

  Widget _actionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionPlaque('待', 'Undo', Icons.undo, _ctl.undo),
        _actionPlaque('持', 'Impasse', Icons.balance, () {
          AudioService.I.click();
          _ctl.prepareImpasseOffer();
          if (_ctl.impasseOffer == null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Impasse needs both kings deep in enemy territory.',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: ShogiPalette.lacquer,
              duration: Duration(seconds: 2),
            ));
          }
        }),
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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      top: 120,
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
              SizedBox(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_ctl.endTitle,
                          style: ShogiType.kanji(
                              52, ShogiPalette.ink,
                              spacing: 10)),
                      if (_ctl.winner != null)
                        Text('${_ctl.nameOf(_ctl.winner!)} wins',
                            style: ShogiType.title(
                                19, ShogiPalette.vermilion)),
                      const SizedBox(height: 4),
                      Text(_ctl.endReason,
                          textAlign: TextAlign.center,
                          style: ShogiType.body(
                              15, ShogiPalette.ink)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _statPlaque(
                              '手数', '${(_ctl.engine.ply ~/ 2) + 1}'),
                          _statPlaque('時間', _ctl.clockText()),
                          _statPlaque('駒取',
                              '${_ctl.engine.capturedCount()}'),
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
                          _ctl.newGame();
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
                          setState(() => _ctl.reviewing = true);
                        },
                        child: Text('盤面を見る — Review board',
                            style: TextStyle(
                                color: ShogiPalette.vermilion,
                                fontWeight: FontWeight.w600)),
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
            Text('Promote this piece?',
                style: TextStyle(color: ShogiPalette.warmGray)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShogiPiece(piece: piece, size: 54, wood: wood),
                Padding(
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

/// Impasse (jishōgi) declaration dialog with the 24-point count.
class _ImpasseDialog extends StatelessWidget {
  final String declarerName;
  final String senteName;
  final String goteName;
  final int sentePoints;
  final int gotePoints;
  final String verdict; // 'sente' | 'gote' | 'draw'
  const _ImpasseDialog({
    required this.declarerName,
    required this.senteName,
    required this.goteName,
    required this.sentePoints,
    required this.gotePoints,
    required this.verdict,
  });

  @override
  Widget build(BuildContext context) {
    final wins =
        (verdict == 'sente' && declarerName == senteName) ||
            (verdict == 'gote' && declarerName == goteName);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: ShogiMaterials.washiCard(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('持将棋',
                style: ShogiType.kanji(30, ShogiPalette.ink, spacing: 8)),
            Text('Impasse declaration',
                style: TextStyle(color: ShogiPalette.warmGray)),
            const SizedBox(height: 10),
            Text(
              '$declarerName declares impasse — both kings are entrenched. '
              'Counting pieces (rook/bishop/promoted = 5, others = 1):',
              textAlign: TextAlign.center,
              style: ShogiType.body(14, ShogiPalette.ink),
            ),
            const SizedBox(height: 14),
            _countRow(senteName, '先手', sentePoints),
            const SizedBox(height: 8),
            _countRow(goteName, '後手', gotePoints),
            const SizedBox(height: 12),
            Text(
              wins
                  ? '$declarerName has 24+ points with an entered king — wins the impasse.'
                  : 'Neither side meets the win condition (entered king + 24 points) — the game is a draw.',
              textAlign: TextAlign.center,
              style: ShogiType.body(14, ShogiPalette.vermilionDeep),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PlaqueButton(
                  kanji: '決',
                  label: 'Confirm',
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

  Widget _countRow(String name, String tag, int pts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ShogiPalette.kayaAmber.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShogiPalette.kayaDeep),
      ),
      child: Row(
        children: [
          Text(tag,
              style: ShogiType.kanji(16, ShogiPalette.ink, spacing: 2)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: ShogiType.title(15, ShogiPalette.ink)),
          ),
          Text('$pts pts',
              style: ShogiType.title(16, ShogiPalette.vermilion)),
        ],
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
            Text('Paused',
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
