/// Main menu: 将棋 title, mode/difficulty/handicap, renameable player
/// names, theme picker, settings, PRO, how-to-play.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../save.dart';
import '../settings.dart';
import '../theme.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _s = SettingsService.I;
  String _mode = 'bot'; // 'bot' | '2p'
  String _handicap = 'even';
  bool _hasSave = false;

  late final TextEditingController _humanCtrl;
  late final TextEditingController _botCtrl;
  late final TextEditingController _senteCtrl;
  late final TextEditingController _goteCtrl;

  @override
  void initState() {
    super.initState();
    _humanCtrl = TextEditingController(text: _s.humanName);
    _botCtrl = TextEditingController(text: _s.botName);
    _senteCtrl = TextEditingController(text: _s.senteName);
    _goteCtrl = TextEditingController(text: _s.goteName);
    _load();
    unawaited(AudioService.I.menuMusic());
  }

  Future<void> _load() async {
    _hasSave = await GameSave.has();
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    await _s.update(() async {
      _s.humanName =
          _humanCtrl.text.trim().isEmpty ? 'You' : _humanCtrl.text.trim();
      _s.botName =
          _botCtrl.text.trim().isEmpty ? 'Bot' : _botCtrl.text.trim();
      _s.senteName =
          _senteCtrl.text.trim().isEmpty ? 'Black' : _senteCtrl.text.trim();
      _s.goteName =
          _goteCtrl.text.trim().isEmpty ? 'White' : _goteCtrl.text.trim();
    });
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
    if (_mode == '2p') {
      return GameConfig(
        mode: '2p',
        handicap: _handicap,
        senteName: _s.senteName,
        goteName: _s.goteName,
      );
    }
    // Bot mode: human is sente on even, gote (first mover) on handicap.
    final humanSente = _handicap == 'even';
    return GameConfig(
      mode: 'bot',
      difficulty: _s.difficulty,
      handicap: _handicap,
      senteName: humanSente ? _s.humanName : _s.botName,
      goteName: humanSente ? _s.botName : _s.humanName,
    );
  }

  Future<void> _refreshSave() async {
    _hasSave = await GameSave.has();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _humanCtrl.dispose();
    _botCtrl.dispose();
    _senteCtrl.dispose();
    _goteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TatamiPainter())),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Game logo.
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black45,
                            blurRadius: 18,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/images/shogi_logo.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('将棋',
                      style: ShogiType.kanji(56, ShogiPalette.ink,
                          spacing: 16)),
                  Text('SHOGI — Japanese Chess',
                      style: ShogiType.title(15, ShogiPalette.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'Capture, drop, checkmate — the game of generals.',
                    style: TextStyle(
                        color: ShogiPalette.warmGray, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
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
                        ? Column(
                            children: [
                              _difficultyRow(),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                      child: _nameField(
                                          'Your name', _humanCtrl)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child:
                                          _nameField('Bot name', _botCtrl)),
                                ],
                              ),
                            ],
                          )
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
                    child: _mode == '2p'
                        ? Row(
                            children: [
                              Expanded(
                                  child: _nameField(
                                      '先手 Sente', _senteCtrl)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child:
                                      _nameField('後手 Gote', _goteCtrl)),
                            ],
                          )
                        : null,
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
                  // Theme picker.
                  _washiPanel(
                    title: '意匠 Theme',
                    child: Column(
                      children: [
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: ShogiThemes.all.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (ctx, i) {
                              if (i == ShogiThemes.all.length) {
                                return _themeChip(
                                  id: 'custom',
                                  kanji: '自',
                                  label: 'Custom',
                                  bg: Color(_s.customBg),
                                  accent: Color(_s.customAccent),
                                );
                              }
                              final t = ShogiThemes.all[i];
                              return _themeChip(
                                id: t.id,
                                kanji: t.kanji,
                                label: t.label,
                                bg: t.tatami,
                                accent: t.vermilion,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            AudioService.I.click();
                            Navigator.of(context)
                                .pushNamed('/custom-theme')
                                .then((_) => setState(() {}));
                          },
                          child: Text('Create a custom theme…',
                              style: TextStyle(
                                  color: ShogiPalette.vermilion,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
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
                  // Bottom row: settings, PRO, how-to.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DiscButton(
                        icon: Icons.settings,
                        onTap: () {
                          AudioService.I.click();
                          Navigator.of(context)
                              .pushNamed('/settings')
                              .then((_) => setState(() {}));
                        },
                      ),
                      const SizedBox(width: 14),
                      _roundLabelButton('極', 'PRO', () {
                        AudioService.I.click();
                        Navigator.of(context).pushNamed('/pro');
                      }),
                      const SizedBox(width: 14),
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
                              Text('How to play',
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
                  Text('v1.1.0',
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

  Widget _roundLabelButton(
      String kanji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ShogiPalette.vermilion, ShogiPalette.vermilionDeep],
              ),
              border:
                  Border.all(color: ShogiPalette.emberGold, width: 1.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Text(kanji,
                style: ShogiType.kanji(20, ShogiPalette.washi, spacing: 0)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: ShogiPalette.warmGray,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _themeChip({
    required String id,
    required String kanji,
    required String label,
    required Color bg,
    required Color accent,
  }) {
    final selected = _s.themeId == id;
    return GestureDetector(
      onTap: () async {
        AudioService.I.click();
        await _s.update(() async => _s.themeId = id);
        setState(() {});
      },
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? accent : ShogiPalette.washiShade,
              width: selected ? 3 : 1),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(kanji,
                style: ShogiType.kanji(20, ShogiPalette.ink, spacing: 0)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ShogiPalette.ink)),
          ],
        ),
      ),
    );
  }

  Widget _nameField(String hint, TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ShogiPalette.washiShade.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShogiPalette.kayaDeep),
      ),
      child: TextField(
        controller: ctrl,
        maxLength: 14,
        textAlign: TextAlign.center,
        style: ShogiType.title(14, ShogiPalette.ink),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          border: InputBorder.none,
          hintStyle:
              TextStyle(color: ShogiPalette.warmGray, fontSize: 12),
        ),
        onChanged: (_) => _savePrefs(),
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
                          style: TextStyle(
                              color: ShogiPalette.warmGray,
                              fontSize: 12)),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle,
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
            selected: _s.difficulty == d,
            kanji: difficultyKanji[d]!,
            label: difficultyLabel[d]!,
            onTap: () async {
              await _s.update(() async => _s.difficulty = d);
              setState(() {});
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
                Center(
                    child: Text('How to play',
                        style: TextStyle(
                            color: ShogiPalette.warmGray))),
                const SizedBox(height: 12),
                ...const [
                  '• Tap one of your pieces, then tap a highlighted square to move it.',
                  '• Captured pieces join YOUR stand — tap one, then tap an empty square to drop it back into battle.',
                  '• Pieces promote in the far three ranks: choose 成 (promote) or 不成 (keep).',
                  '• No pawn drops on the last rank, on a file with your unpromoted pawn, or to deliver checkmate.',
                  '• If both kings invade deep, declare 持将棋 (impasse) — counted by pieces.',
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
