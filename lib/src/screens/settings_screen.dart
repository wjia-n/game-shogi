/// Settings: sound, piece wood, board wood, game options. All persisted.
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
  SettingsService get _s => SettingsService.I;

  Future<void> _update(Future<void> Function() apply) async {
    await _s.update(() async {
      await apply();
    });
    await AudioService.I.refresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TatamiPainter())),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Column(
                      children: [
                        _group('音 Sound', [
                          _toggleRow('音楽 Music', 'Background koto melodies',
                              _s.musicOn, (v) => _update(() async {
                                    _s.musicOn = v;
                                    if (v) {
                                      await AudioService.I.menuMusic();
                                    }
                                  })),
                          _toggleRow('効果音 SFX', 'Wooden clacks & drums',
                              _s.sfxOn, (v) => _update(() async {
                                    _s.sfxOn = v;
                                  })),
                          _sliderRow('音量 Master volume', _s.volume,
                              (v) => _update(() async {
                                    _s.volume = v;
                                  })),
                          _sliderRow('音楽音量 Music volume',
                              _s.musicVolume, (v) => _update(() async {
                                    _s.musicVolume = v;
                                  })),
                        ]),
                        _group('駒 Pieces', [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final style in pieceStyles)
                                  _woodSwatch(
                                    selected:
                                        _s.pieceStyle == style,
                                    label: pieceStyleLabel[style]!,
                                    onTap: () => _update(() async {
                                          _s.pieceStyle = style;
                                          await AudioService.I
                                              .click();
                                        }),
                                    piece: ShogiPiece(
                                      piece: sente * ptKing,
                                      size: 52,
                                      wood: pieceWoods[style]!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ]),
                        _group('盤 Board', [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final b in boardWoodIds)
                                  _boardSwatch(
                                    selected: _s.boardWood == b,
                                    label: boardWoodLabel[b]!,
                                    wood: boardWoods[b]!,
                                    onTap: () => _update(() async {
                                          _s.boardWood = b;
                                          await AudioService.I
                                              .click();
                                        }),
                                  ),
                              ],
                            ),
                          ),
                          _toggleRow('合法手 Legal-move dots',
                              'Show vermilion dots on legal squares',
                              _s.showLegalDots, (v) => _update(() async {
                                    _s.showLegalDots = v;
                                  })),
                          _toggleRow('座標 Coordinates',
                              'File numbers & rank kanji on the board',
                              _s.showCoordinates, (v) => _update(() async {
                                    _s.showCoordinates = v;
                                  })),
                        ]),
                        _group('対局 Game', [
                          _toggleRow('投了確認 Confirm resign',
                              'Ask before resigning a game',
                              _s.confirmResign, (v) => _update(() async {
                                    _s.confirmResign = v;
                                  })),
                          _toggleRow('待った Undo',
                              'Allow taking back moves',
                              _s.allowUndo, (v) => _update(() async {
                                    _s.allowUndo = v;
                                  })),
                        ]),
                        const SizedBox(height: 8),
                        PlaqueButton(
                          kanji: '戻',
                          label: 'Reset to defaults',
                          width: 230,
                          onTap: () async {
                            await _s.resetDefaults();
                            await AudioService.I.refresh();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: ShogiPalette.lacquer,
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          DiscButton(
              icon: Icons.arrow_back,
              size: 42,
              onTap: () {
                AudioService.I.click();
                Navigator.of(context).pop();
              }),
          const SizedBox(width: 12),
          Text('設定',
              style:
                  ShogiType.kanji(28, ShogiPalette.washi, spacing: 8)),
          const SizedBox(width: 8),
          const Text('Settings',
              style:
                  TextStyle(color: ShogiPalette.warmGray, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: ShogiMaterials.washiCard(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ShogiType.title(16, ShogiPalette.ink)),
          const Divider(color: ShogiPalette.washiShade),
          ...children,
        ],
      ),
    );
  }

  Widget _toggleRow(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: ShogiPalette.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text(subtitle,
                    style: const TextStyle(
                        color: ShogiPalette.warmGray, fontSize: 12)),
              ],
            ),
          ),
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
      String title, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: ShogiPalette.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text('${(value * 100).round()}%',
                  style: ShogiType.stat.copyWith(fontSize: 14)),
            ],
          ),
          BambooSlider(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _woodSwatch({
    required bool selected,
    required String label,
    required VoidCallback onTap,
    required Widget piece,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ShogiPalette.washiShade.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? ShogiPalette.vermilion
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: piece,
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: ShogiPalette.ink,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _boardSwatch({
    required bool selected,
    required String label,
    required BoardWood wood,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: wood.edge, width: 5),
              color: wood.face,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 3)),
              ],
            ),
            child: selected
                ? const Icon(Icons.check,
                    color: ShogiPalette.vermilion, size: 28)
                : null,
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: ShogiPalette.ink,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
