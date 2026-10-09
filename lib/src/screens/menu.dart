/// Main menu: 将棋 title, hero pieces, mode/difficulty/handicap, settings, help.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio.dart';
import '../engine.dart';
import '../save.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _mode = 'bot'; // 'bot' | '2p'
  int _difficulty = 1;
  String _handicap = 'even';
  bool _hasSave = false;
  String _playerName = 'You';
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(AudioService.I.menuMusic());
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _hasSave = await GameSave.has();
    _playerName = p.getString('shogi_playerName') ?? 'You';
    _nameCtrl.text = _playerName;
    _difficulty = p.getInt('shogi_difficulty') ?? 1;
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('shogi_difficulty', _difficulty);
    await p.setString('shogi_playerName', _playerName);
  }

  void _start({required bool cont}) {
    unawaited(_savePrefs());
    AudioService.I.click();
    if (cont) {
      Navigator.of(context).pushNamed('/game',
          arguments: {'continue': true, 'config': _config()});
    } else {
      Navigator.of(context)
          .pushNamed('/game', arguments: {'config': _config()}).then((_) {
        _refreshSave();
      });
    }
  }

  GameConfig _config() {
    final human = _playerName.trim().isEmpty ? 'You' : _playerName.trim();
    if (_mode == '2p') {
      return GameConfig(
        mode: '2p',
        handicap: _handicap,
        senteName: _handicap == 'even' ? human : 'Black',
        goteName: _handicap == 'even' ? 'Friend' : human,
        playerName: human,
      );
    }
    // Bot mode: human is sente on even, gote (first mover) on handicap.
    final humanSente = _handicap == 'even';
    return GameConfig(
      mode: 'bot',
      difficulty: _difficulty,
      handicap: _handicap,
      senteName: humanSente ? human : 'Bot',
      goteName: humanSente ? 'Bot' : human,
      playerName: human,
    );
  }

  Future<void> _refreshSave() async {
    _hasSave = await GameSave.has();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wood = pieceWoods[SettingsService.I.pieceStyle] ?? pieceWoods['kaya']!;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TatamiPainter())),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  // Hero pieces.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(
                          angle: -0.12,
                          child: ShogiPiece(
                              piece: sente * ptSilver, size: 54, wood: wood)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: ShogiPiece(
                            piece: sente * ptKing, size: 72, wood: wood),
                      ),
                      Transform.rotate(
                          angle: 0.12,
                          child: ShogiPiece(
                              piece: gote * ptRook, size: 54, wood: wood)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('将棋',
                      style: ShogiType.kanji(72, ShogiPalette.ink,
                          spacing: 18)),
                  Text('SHOGI — Japanese Chess',
                      style: ShogiType.title(16, ShogiPalette.ink)),
                  const SizedBox(height: 4),
                  const Text(
                    'Capture, drop, checkmate — the game of generals.',
                    style: TextStyle(
                        color: ShogiPalette.warmGray, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  if (_hasSave)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PlaqueButton(
                        kanji: '続',
                        label: 'Continue game',
                        primary: true,
                        width: 240,
                        onTap: () => _start(cont: true),
                      ),
                    ),
                  // Mode plaques.
                  _modeCard(
                    selected: _mode == 'bot',
                    kanji: '対',
                    title: 'Play vs Bot',
                    subtitle: 'Hone your strategy against the machine',
                    onTap: () {
                      setState(() => _mode = 'bot');
                      AudioService.I.click();
                    },
                    child: _mode == 'bot'
                        ? _difficultyRow()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _modeCard(
                    selected: _mode == '2p',
                    kanji: '二',
                    title: 'Two Players',
                    subtitle: 'Face a friend on this device',
                    onTap: () {
                      setState(() => _mode = '2p');
                      AudioService.I.click();
                    },
                  ),
                  const SizedBox(height: 16),
                  // Handicap washi panel.
                  _washiPanel(
                    title: 'ハンデ Handicap',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final h in handicapLabel.keys)
                          _chip(
                            selected: _handicap == h,
                            kanji: handicapKanji[h]!,
                            label: handicapLabel[h]!,
                            onTap: () {
                              setState(() => _handicap = h);
                              AudioService.I.click();
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name field.
                  _washiPanel(
                    title: '名前 Your name',
                    child: TextField(
                      controller: _nameCtrl,
                      maxLength: 14,
                      textAlign: TextAlign.center,
                      style: ShogiType.title(16, ShogiPalette.ink),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'You',
                        border: InputBorder.none,
                        hintStyle:
                            TextStyle(color: ShogiPalette.warmGray),
                      ),
                      onChanged: (v) => _playerName = v,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PlaqueButton(
                    kanji: '始',
                    label: 'Start game',
                    primary: true,
                    width: 240,
                    onTap: () => _start(cont: false),
                  ),
                  const SizedBox(height: 20),
                  // Bottom: settings disc + how-to tanzaku.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DiscButton(
                        icon: Icons.settings,
                        onTap: () {
                          AudioService.I.click();
                          Navigator.of(context).pushNamed('/settings');
                        },
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: () {
                          AudioService.I.click();
                          _howTo();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: ShogiPalette.washi,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: ShogiPalette.washiShade),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('遊',
                                  style: ShogiType.kanji(
                                      18, ShogiPalette.vermilion,
                                      spacing: 1)),
                              const SizedBox(width: 6),
                              const Text('How to play',
                                  style: TextStyle(
                                      color: ShogiPalette.ink,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('v1.0.0',
                      style: TextStyle(
                          color: ShogiPalette.warmGray, fontSize: 11)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required bool selected,
    required String kanji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? ShogiPalette.washi
              : ShogiPalette.washi.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? ShogiPalette.vermilion
                : ShogiPalette.washiShade,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? ShogiPalette.vermilion
                        : ShogiPalette.kayaDeep,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(kanji,
                      style: ShogiType.kanji(
                          22, ShogiPalette.washi, spacing: 0)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              ShogiType.title(17, ShogiPalette.ink)),
                      Text(subtitle,
                          style: const TextStyle(
                              color: ShogiPalette.warmGray,
                              fontSize: 12)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: ShogiPalette.vermilion),
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _difficultyRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final d in [0, 1, 2])
          _chip(
            selected: _difficulty == d,
            kanji: difficultyKanji[d]!,
            label: difficultyLabel[d]!,
            onTap: () {
              setState(() => _difficulty = d);
              AudioService.I.click();
            },
          ),
      ],
    );
  }

  Widget _chip({
    required bool selected,
    required String kanji,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? ShogiPalette.lacquer
              : ShogiPalette.kayaAmber.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? ShogiPalette.vermilion
                : ShogiPalette.kayaDeep,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(kanji,
                style: ShogiType.kanji(
                    14,
                    selected
                        ? ShogiPalette.washi
                        : ShogiPalette.ink,
                    spacing: 1)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? ShogiPalette.washi
                        : ShogiPalette.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _washiPanel({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: ShogiMaterials.washiCard(radius: 10),
      child: Column(
        children: [
          Text(title,
              style: ShogiType.title(14, ShogiPalette.ink)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  void _howTo() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ShogiMaterials.washiCard(),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Text('遊び方',
                        style: ShogiType.kanji(28, ShogiPalette.ink,
                            spacing: 6))),
                const SizedBox(height: 4),
                const Center(
                    child: Text('How to play',
                        style: TextStyle(
                            color: ShogiPalette.warmGray))),
                const SizedBox(height: 12),
                ...const [
                  '• Tap one of your pieces, then tap a highlighted square to move it.',
                  '• Captured pieces join YOUR stand — tap one, then tap an empty square to drop it back into battle.',
                  '• Pieces promote in the far three ranks: choose 成 (promote) or 不成 (keep).',
                  '• No pawn drops on the last rank, on a file with your unpromoted pawn, or to deliver checkmate.',
                  '• Checkmate (詰み) the enemy king to win!',
                ].map((t) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(t,
                          style: TextStyle(
                              color: ShogiPalette.ink,
                              fontSize: 14,
                              height: 1.5)),
                    )),
                const SizedBox(height: 8),
                Center(
                  child: PlaqueButton(
                    kanji: '閉',
                    label: 'Close',
                    width: 160,
                    onTap: () {
                      AudioService.I.click();
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
