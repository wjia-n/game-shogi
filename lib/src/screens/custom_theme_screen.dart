/// Custom theme creator: pick the five key colors, preview live,
/// save as the "My Theme" theme.
library;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../settings.dart';
import '../theme.dart';

class CustomThemeScreen extends StatefulWidget {
  const CustomThemeScreen({super.key});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  final _s = SettingsService.I;

  static const _swatches = [
    0xFFD9C9A8, 0xFFE3CDBD, 0xFFC4C09A, 0xFFB9B49A, // lights
    0xFFD9AE62, 0xFFC89B5A, 0xFF9A6B3D, 0xFFE8D49A, // woods
    0xFFC93A2B, 0xFFD14A6B, 0xFFB03A5E, 0xFFC8481E, // accents
    0xFF1A1817, 0xFF3A3F4A, 0xFF2E3A5C, 0xFF44502E, // darks
    0xFFF5EEDC, 0xFFFBF3EC, 0xFFEDEBD8, 0xFF1C1A14, // papers
  ];

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
                      Text('自作テーマ',
                          style: ShogiType.kanji(28, ShogiPalette.ink,
                              spacing: 4)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Custom theme — pick five colors, preview live.',
                      style: TextStyle(color: ShogiPalette.warmGray)),
                  const SizedBox(height: 16),
                  _preview(),
                  const SizedBox(height: 16),
                  _colorRow('Background', _s.customBg, (v) => _s.customBg = v),
                  _colorRow('Board face', _s.customBoard, (v) => _s.customBoard = v),
                  _colorRow('Board edge', _s.customBoardEdge,
                      (v) => _s.customBoardEdge = v),
                  _colorRow('Accent', _s.customAccent, (v) => _s.customAccent = v),
                  _colorRow('Paper', _s.customPaper, (v) => _s.customPaper = v),
                  const SizedBox(height: 20),
                  Center(
                    child: PlaqueButton(
                      kanji: '用',
                      label: 'Use this theme',
                      primary: true,
                      width: 240,
                      onTap: () async {
                        AudioService.I.click();
                        await _s.update(() async {
                          _s.themeId = 'custom';
                        });
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
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

  Widget _preview() {
    // Live preview rendered with the candidate custom colors.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(_s.customPaper),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShogiPalette.washiShade),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Color(_s.customBoard),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(_s.customBoardEdge), width: 6),
            ),
            child: Center(
              child: Text('将',
                  style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Color(_s.customAccent))),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Color(_s.customAccent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Preview plaque',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String label, int value, ValueChanged<int> onPick) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: ShogiMaterials.washiCard(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(value),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ShogiPalette.warmGray),
                ),
              ),
              const SizedBox(width: 10),
              Text(label, style: ShogiType.title(15, ShogiPalette.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _swatches)
                GestureDetector(
                  onTap: () {
                    AudioService.I.click();
                    setState(() => onPick(c));
                    _s.update(() async {});
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: value == c
                            ? ShogiPalette.vermilion
                            : ShogiPalette.washiShade,
                        width: value == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
