/// Settings: sound, pieces, board, theme, names, game options.
library;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../engine.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _s = SettingsService.I;

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
  }

  @override
  void dispose() {
    _humanCtrl.dispose();
    _botCtrl.dispose();
    _senteCtrl.dispose();
    _goteCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyAudio() async {
    await AudioService.I.refresh(
      musicOn: _s.musicOn,
      sfxOn: _s.sfxOn,
      volume: _s.volume,
      musicVolume: _s.musicVolume,
    );
  }

  Future<void> _set(Future<void> Function() fn) async {
    await _s.update(fn);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TatamiPainter())),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DiscButton(
                        icon: Icons.arrow_back,
                        size: 42,
                        onTap: () {
                          AudioService.I.click();
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 12),
                      Text('設定',
                          style: ShogiType.kanji(32, ShogiPalette.ink,
                              spacing: 8)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _group('音 Sound', [
                    _toggleRow('Music', _s.musicOn,
                        (v) => _set(() async => _s.musicOn = v).then((_) => _applyAudio())),
                    _toggleRow('Sound effects', _s.sfxOn,
                        (v) => _set(() async => _s.sfxOn = v).then((_) => _applyAudio())),
                    _sliderRow('Master volume', _s.volume,
                        (v) => _set(() async => _s.volume = v).then((_) => _applyAudio())),
                    _sliderRow('Music volume', _s.musicVolume,
                        (v) => _set(() async => _s.musicVolume = v).then((_) => _applyAudio())),
                  ]),
                  _group('意匠 Theme', [
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: ShogiThemes.all.length + 1,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          if (i == ShogiThemes.all.length) {
                            return _themeSwatch('custom', '自', 'Custom',
                                Color(_s.customBg), Color(_s.customAccent));
                          }
                          final t = ShogiThemes.all[i];
                          return _themeSwatch(t.id, t.kanji, t.label,
                              t.tatami, t.vermilion);
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
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
                    ),
                  ]),
                  _group('駒 Pieces', [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final id in pieceStyles)
                          _pieceSwatch(id),
                      ],
                    ),
                  ]),
                  _group('盤 Board', [
                    Text('Wood',
                        style: ShogiType.title(14, ShogiPalette.ink)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in boardWoodIds)
                          _optionChip(
                            selected: _s.boardWood == id,
                            label: boardWoodLabel[id]!,
                            onTap: () =>
                                _set(() async => _s.boardWood = id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Grid accent',
                        style: ShogiType.title(14, ShogiPalette.ink)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in boardAccentIds)
                          _optionChip(
                            selected: _s.boardAccent == id,
                            label: boardAccentLabel[id]!,
                            onTap: () =>
                                _set(() async => _s.boardAccent = id),
                          ),
                      ],
                    ),
                  ]),
                  _group('名前 Player names', [
                    _nameRow('Your name (vs Bot)', _humanCtrl,
                        (v) => _s.humanName = v.isEmpty ? 'You' : v),
                    _nameRow('Bot name', _botCtrl,
                        (v) => _s.botName = v.isEmpty ? 'Bot' : v),
                    _nameRow('先手 Sente (2 players)', _senteCtrl,
                        (v) => _s.senteName = v.isEmpty ? 'Black' : v),
                    _nameRow('後手 Gote (2 players)', _goteCtrl,
                        (v) => _s.goteName = v.isEmpty ? 'White' : v),
                  ]),
                  _group('対局 Game', [
                    _toggleRow('Show legal-move dots', _s.showLegalDots,
                        (v) => _set(() async => _s.showLegalDots = v)),
                    _toggleRow('Show coordinates', _s.showCoordinates,
                        (v) => _set(() async => _s.showCoordinates = v)),
                    _toggleRow('Confirm before resign', _s.confirmResign,
                        (v) => _set(() async => _s.confirmResign = v)),
                    _toggleRow('Allow undo', _s.allowUndo,
                        (v) => _set(() async => _s.allowUndo = v)),
                  ]),
                  Center(
                    child: PlaqueButton(
                      kanji: '戻',
                      label: 'Reset to defaults',
                      width: 240,
                      onTap: () async {
                        AudioService.I.click();
                        await _s.resetDefaults();
                        await _applyAudio();
                        _humanCtrl.text = _s.humanName;
                        _botCtrl.text = _s.botName;
                        _senteCtrl.text = _s.senteName;
                        _goteCtrl.text = _s.goteName;
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: ShogiMaterials.washiCard(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ShogiType.title(16, ShogiPalette.ink)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _toggleRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: ShogiType.body(15, ShogiPalette.ink))),
          WoodToggle(
              value: value,
              onChanged: (v) {
                AudioService.I.click();
                onChanged(v);
              }),
        ],
      ),
    );
  }

  Widget _sliderRow(
      String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child:
                  Text(label, style: ShogiType.body(15, ShogiPalette.ink))),
          Expanded(
            child: BambooSlider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _themeSwatch(String id, String kanji, String label, Color bg,
      Color accent) {
    final selected = _s.themeId == id;
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        _set(() async => _s.themeId = id);
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

  Widget _pieceSwatch(String id) {
    final selected = _s.pieceStyle == id;
    final w = pieceWoods[id]!;
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        _set(() async => _s.pieceStyle = id);
      },
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ShogiPalette.washiShade.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? ShogiPalette.vermilion
                  : ShogiPalette.washiShade,
              width: selected ? 2.5 : 1),
        ),
        child: Column(
          children: [
            ShogiPiece(piece: sente * ptSilver, size: 44, wood: w),
            const SizedBox(height: 4),
            Text(pieceStyleLabel[id]!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ShogiPalette.ink)),
          ],
        ),
      ),
    );
  }

  Widget _optionChip(
      {required bool selected,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        onTap();
      },
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
              width: selected ? 2 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? ShogiPalette.washi : ShogiPalette.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }

  Widget _nameRow(String label, TextEditingController ctrl,
      ValueChanged<String> onSaved) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 150,
              child:
                  Text(label, style: ShogiType.body(14, ShogiPalette.ink))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ShogiPalette.washiShade.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ShogiPalette.kayaDeep),
              ),
              child: TextField(
                controller: ctrl,
                maxLength: 14,
                style: ShogiType.title(14, ShogiPalette.ink),
                decoration: const InputDecoration(
                    counterText: '', border: InputBorder.none),
                onChanged: (v) =>
                    _s.update(() async => onSaved(v.trim())),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
