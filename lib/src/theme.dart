/// Japanese craft design tokens — Stitch visual source of truth.
/// See stitch-batch3/shogi/DESIGN.md
///
/// 12 selectable themes + a custom theme. [ShogiPalette] keeps its name and
/// API but now resolves to the active theme at runtime, so every screen
/// follows the chosen theme.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'settings.dart';

// ---------------------------------------------------------------------------
// Theme data + catalog
// ---------------------------------------------------------------------------

/// Full color-token set for one theme.
class ShogiThemeData {
  final String id;
  final String label;
  final String kanji;
  final Color tatami;
  final Color tatamiDark;
  final Color kayaAmber;
  final Color kayaDeep;
  final Color kayaLight;
  final Color lacquer;
  final Color lacquerSoft;
  final Color washi;
  final Color washiShade;
  final Color ink;
  final Color vermilion;
  final Color vermilionDeep;
  final Color warmGray;
  final Color emberGold;
  final Color gridInk;

  const ShogiThemeData({
    required this.id,
    required this.label,
    required this.kanji,
    required this.tatami,
    required this.tatamiDark,
    required this.kayaAmber,
    required this.kayaDeep,
    required this.kayaLight,
    required this.lacquer,
    required this.lacquerSoft,
    required this.washi,
    required this.washiShade,
    required this.ink,
    required this.vermilion,
    required this.vermilionDeep,
    required this.warmGray,
    required this.emberGold,
    required this.gridInk,
  });
}

const _lacquer = Color(0xFF1A1817);
const _lacquerSoft = Color(0xFF2B2622);
const _ink = Color(0xFF24211D);
const _washi = Color(0xFFF5EEDC);
const _washiShade = Color(0xFFE9DFC6);
const _warmGray = Color(0xFF8A7F6E);

/// 12 Japanese-craft themes. All avoid neon/cyberpunk per MASTER_RULES.md.
const Map<String, ShogiThemeData> shogiThemes = {
  'kaya-classic': ShogiThemeData(
    id: 'kaya-classic',
    label: 'Kaya Classic',
    kanji: '欅',
    tatami: Color(0xFFD9C9A8),
    tatamiDark: Color(0xFFC4B28E),
    kayaAmber: Color(0xFFC89B5A),
    kayaDeep: Color(0xFFA87B3F),
    kayaLight: Color(0xFFDDB271),
    lacquer: _lacquer,
    lacquerSoft: _lacquerSoft,
    washi: _washi,
    washiShade: _washiShade,
    ink: _ink,
    vermilion: Color(0xFFC93A2B),
    vermilionDeep: Color(0xFFA02A1F),
    warmGray: _warmGray,
    emberGold: Color(0xFFE0A93E),
    gridInk: Color(0xFF4A3826),
  ),
  'sakura-dawn': ShogiThemeData(
    id: 'sakura-dawn',
    label: 'Sakura Dawn',
    kanji: '桜',
    tatami: Color(0xFFE3CDBD),
    tatamiDark: Color(0xFFCFB3A1),
    kayaAmber: Color(0xFFD9A184),
    kayaDeep: Color(0xFFB57E5C),
    kayaLight: Color(0xFFEBC39F),
    lacquer: Color(0xFF221A18),
    lacquerSoft: Color(0xFF342825),
    washi: Color(0xFFFBF3EC),
    washiShade: Color(0xFFF0DFD2),
    ink: Color(0xFF2E2320),
    vermilion: Color(0xFFD14A6B),
    vermilionDeep: Color(0xFFA83654),
    warmGray: Color(0xFF9A8577),
    emberGold: Color(0xFFE8B25E),
    gridInk: Color(0xFF5A4034),
  ),
  'midnight-dojo': ShogiThemeData(
    id: 'midnight-dojo',
    label: 'Midnight Dojo',
    kanji: '夜',
    tatami: Color(0xFF3A3F4A),
    tatamiDark: Color(0xFF2C313A),
    kayaAmber: Color(0xFF9A7B4F),
    kayaDeep: Color(0xFF6E5732),
    kayaLight: Color(0xFFB89668),
    lacquer: Color(0xFF121316),
    lacquerSoft: Color(0xFF1E2126),
    washi: Color(0xFFE8E2D2),
    washiShade: Color(0xFFD2C9B2),
    ink: Color(0xFF1E2024),
    vermilion: Color(0xFFD64A35),
    vermilionDeep: Color(0xFFA83624),
    warmGray: Color(0xFF8E94A0),
    emberGold: Color(0xFFE8B84E),
    gridInk: Color(0xFFD8CFAE),
  ),
  'bamboo-grove': ShogiThemeData(
    id: 'bamboo-grove',
    label: 'Bamboo Grove',
    kanji: '竹',
    tatami: Color(0xFFCFC39A),
    tatamiDark: Color(0xFFB3A87E),
    kayaAmber: Color(0xFFC2A05C),
    kayaDeep: Color(0xFF97803F),
    kayaLight: Color(0xFFD9BC7E),
    lacquer: Color(0xFF1C1A14),
    lacquerSoft: Color(0xFF2E2A20),
    washi: Color(0xFFF4EEDB),
    washiShade: Color(0xFFE4D9BC),
    ink: Color(0xFF26241A),
    vermilion: Color(0xFFBE3A28),
    vermilionDeep: Color(0xFF962C1E),
    warmGray: Color(0xFF8A8468),
    emberGold: Color(0xFFDDB04A),
    gridInk: Color(0xFF4E4426),
  ),
  'momiji-autumn': ShogiThemeData(
    id: 'momiji-autumn',
    label: 'Momiji Autumn',
    kanji: '紅葉',
    tatami: Color(0xFFD9BE96),
    tatamiDark: Color(0xFFC2A37C),
    kayaAmber: Color(0xFFC98F4E),
    kayaDeep: Color(0xFFA06834),
    kayaLight: Color(0xFFDEAC72),
    lacquer: Color(0xFF1E1613),
    lacquerSoft: Color(0xFF322520),
    washi: Color(0xFFF7EDDA),
    washiShade: Color(0xFFE9D8BC),
    ink: Color(0xFF2A2018),
    vermilion: Color(0xFFC23E1E),
    vermilionDeep: Color(0xFF9A2F16),
    warmGray: Color(0xFF94805F),
    emberGold: Color(0xFFE89E3E),
    gridInk: Color(0xFF503722),
  ),
  'aizome-indigo': ShogiThemeData(
    id: 'aizome-indigo',
    label: 'Aizome Indigo',
    kanji: '藍',
    tatami: Color(0xFFB9B49A),
    tatamiDark: Color(0xFF9E9A82),
    kayaAmber: Color(0xFFB08D52),
    kayaDeep: Color(0xFF82683A),
    kayaLight: Color(0xFFCCAB72),
    lacquer: Color(0xFF16181D),
    lacquerSoft: Color(0xFF23262E),
    washi: Color(0xFFEDEBD8),
    washiShade: Color(0xFFDAD5BC),
    ink: Color(0xFF1F2230),
    vermilion: Color(0xFFC93A2B),
    vermilionDeep: Color(0xFFA02A1F),
    warmGray: Color(0xFF7E7F88),
    emberGold: Color(0xFFD8A848),
    gridInk: Color(0xFF2E3A5C),
  ),
  'matcha-garden': ShogiThemeData(
    id: 'matcha-garden',
    label: 'Matcha Garden',
    kanji: '抹茶',
    tatami: Color(0xFFC4C09A),
    tatamiDark: Color(0xFFAAA67E),
    kayaAmber: Color(0xFFB5985A),
    kayaDeep: Color(0xFF8A7440),
    kayaLight: Color(0xFFCFB678),
    lacquer: Color(0xFF181A14),
    lacquerSoft: Color(0xFF282B20),
    washi: Color(0xFFF2EDDA),
    washiShade: Color(0xFFE0D8BC),
    ink: Color(0xFF23241A),
    vermilion: Color(0xFFBE3A28),
    vermilionDeep: Color(0xFF962C1E),
    warmGray: Color(0xFF85836A),
    emberGold: Color(0xFFD9A848),
    gridInk: Color(0xFF44502E),
  ),
  'cedar-night': ShogiThemeData(
    id: 'cedar-night',
    label: 'Cedar Night',
    kanji: '杉',
    tatami: Color(0xFF4A3D30),
    tatamiDark: Color(0xFF3A2F24),
    kayaAmber: Color(0xFFA87B4A),
    kayaDeep: Color(0xFF7C5730),
    kayaLight: Color(0xFFC29468),
    lacquer: Color(0xFF14100D),
    lacquerSoft: Color(0xFF221B16),
    washi: Color(0xFFEFE4CC),
    washiShade: Color(0xFFD9C8A6),
    ink: Color(0xFF241C14),
    vermilion: Color(0xFFD0522E),
    vermilionDeep: Color(0xFFA03E22),
    warmGray: Color(0xFF9A8A76),
    emberGold: Color(0xFFE8A848),
    gridInk: Color(0xFFE2D2AC),
  ),
  'pearl-morning': ShogiThemeData(
    id: 'pearl-morning',
    label: 'Pearl Morning',
    kanji: '朝',
    tatami: Color(0xFFE6DCC4),
    tatamiDark: Color(0xFFD2C6A8),
    kayaAmber: Color(0xFFD9B878),
    kayaDeep: Color(0xFFB89458),
    kayaLight: Color(0xFFF0D49C),
    lacquer: Color(0xFF2A2622),
    lacquerSoft: Color(0xFF3E3830),
    washi: Color(0xFFFFFBF0),
    washiShade: Color(0xFFF2E8D4),
    ink: Color(0xFF2E2A22),
    vermilion: Color(0xFFC0392B),
    vermilionDeep: Color(0xFF9A2C20),
    warmGray: Color(0xFF9A8E78),
    emberGold: Color(0xFFE8BC5E),
    gridInk: Color(0xFF5A4A34),
  ),
  'sumi-night': ShogiThemeData(
    id: 'sumi-night',
    label: 'Sumi Night',
    kanji: '墨',
    tatami: Color(0xFF3C3A38),
    tatamiDark: Color(0xFF2E2C2A),
    kayaAmber: Color(0xFF9A8E7E),
    kayaDeep: Color(0xFF6E6558),
    kayaLight: Color(0xFFB8AC9C),
    lacquer: Color(0xFF0E0E0E),
    lacquerSoft: Color(0xFF1C1C1C),
    washi: Color(0xFFEDEAE2),
    washiShade: Color(0xFFD8D2C4),
    ink: Color(0xFF1A1A1A),
    vermilion: Color(0xFFB03324),
    vermilionDeep: Color(0xFF8A281C),
    warmGray: Color(0xFF8E8A84),
    emberGold: Color(0xFFC8A848),
    gridInk: Color(0xFFD8D2C4),
  ),
  'plum-blossom': ShogiThemeData(
    id: 'plum-blossom',
    label: 'Plum Blossom',
    kanji: '梅',
    tatami: Color(0xFFD8C4B8),
    tatamiDark: Color(0xFFC0A898),
    kayaAmber: Color(0xFFC99A7E),
    kayaDeep: Color(0xFFA07458),
    kayaLight: Color(0xFFDEB898),
    lacquer: Color(0xFF1E181C),
    lacquerSoft: Color(0xFF32262E),
    washi: Color(0xFFFAF1EA),
    washiShade: Color(0xFFEDD9CC),
    ink: Color(0xFF2C2228),
    vermilion: Color(0xFFB03A5E),
    vermilionDeep: Color(0xFF8A2C48),
    warmGray: Color(0xFF96827E),
    emberGold: Color(0xFFE0A86E),
    gridInk: Color(0xFF54383E),
  ),
  'golden-hour': ShogiThemeData(
    id: 'golden-hour',
    label: 'Golden Hour',
    kanji: '夕',
    tatami: Color(0xFFE0C491),
    tatamiDark: Color(0xFFCBAE78),
    kayaAmber: Color(0xFFD8A24E),
    kayaDeep: Color(0xFFB37C32),
    kayaLight: Color(0xFFF0C078),
    lacquer: Color(0xFF201812),
    lacquerSoft: Color(0xFF36281C),
    washi: Color(0xFFFBF2DC),
    washiShade: Color(0xFFF2E2C0),
    ink: Color(0xFF2E2416),
    vermilion: Color(0xFFC8481E),
    vermilionDeep: Color(0xFFA03816),
    warmGray: Color(0xFF9A8560),
    emberGold: Color(0xFFF0B83E),
    gridInk: Color(0xFF5A4426),
  ),
};

/// Builds the user-customized theme from [SettingsService] custom colors.
ShogiThemeData customThemeData(SettingsService s) {
  final bg = Color(s.customBg);
  final bgDark = Color.lerp(bg, const Color(0xFF000000), 0.12) ?? bg;
  final board = Color(s.customBoard);
  final edge = Color(s.customBoardEdge);
  final accent = Color(s.customAccent);
  final paper = Color(s.customPaper);
  final paperShade = Color.lerp(paper, const Color(0xFF000000), 0.07) ?? paper;
  return ShogiThemeData(
    id: 'custom',
    label: 'My Theme',
    kanji: '自',
    tatami: bg,
    tatamiDark: bgDark,
    kayaAmber: board,
    kayaDeep: edge,
    kayaLight: Color.lerp(board, const Color(0xFFFFFFFF), 0.18) ?? board,
    lacquer: _lacquer,
    lacquerSoft: _lacquerSoft,
    washi: paper,
    washiShade: paperShade,
    ink: _ink,
    vermilion: accent,
    vermilionDeep: Color.lerp(accent, const Color(0xFF000000), 0.2) ?? accent,
    warmGray: _warmGray,
    emberGold: Color.lerp(accent, const Color(0xFFFFD98A), 0.45) ?? accent,
    gridInk: const Color(0xFF4A3826),
  );
}

/// Active theme: the selected catalog theme, or the user's custom theme.
abstract class ShogiThemes {
  static ShogiThemeData get active {
    final s = SettingsService.I;
    if (s.themeId == 'custom') return customThemeData(s);
    return shogiThemes[s.themeId] ?? shogiThemes['kaya-classic']!;
  }

  static List<ShogiThemeData> get all => shogiThemes.values.toList();
}

// ---------------------------------------------------------------------------
// Palette facade — same API as before, now theme-aware.
// ---------------------------------------------------------------------------

/// Palette from the Stitch "Japanese craft" design system, resolved against
/// the active theme.
abstract class ShogiPalette {
  static ShogiThemeData get _t => ShogiThemes.active;
  static Color get tatami => _t.tatami;
  static Color get tatamiDark => _t.tatamiDark;
  static Color get kayaAmber => _t.kayaAmber;
  static Color get kayaDeep => _t.kayaDeep;
  static Color get kayaLight => _t.kayaLight;
  static Color get lacquer => _t.lacquer;
  static Color get lacquerSoft => _t.lacquerSoft;
  static Color get washi => _t.washi;
  static Color get washiShade => _t.washiShade;
  static Color get ink => _t.ink;
  static Color get vermilion => _t.vermilion;
  static Color get vermilionDeep => _t.vermilionDeep;
  static Color get warmGray => _t.warmGray;
  static Color get emberGold => _t.emberGold;
  static Color get gridInk => _t.gridInk;
}

// ---------------------------------------------------------------------------
// Piece + board materials
// ---------------------------------------------------------------------------

/// Piece finishes (settings-selectable). 9 styles.
class PieceWood {
  final Color base;
  final Color hi;
  final Color deep;
  final Color grain;
  final Color kanji;
  const PieceWood(this.base, this.hi, this.deep, this.grain, this.kanji);
}

const Map<String, PieceWood> pieceWoods = {
  'kaya': PieceWood(
    Color(0xFFE3B96B), Color(0xFFF6DC9E), Color(0xFFB57E3A),
    Color(0xFFC99B52), Color(0xFF241C12),
  ),
  'katsura': PieceWood(
    Color(0xFFEFD3A0), Color(0xFFFFEBC4), Color(0xFFC79B58),
    Color(0xFFDDB87E), Color(0xFF2A2115),
  ),
  'kurogaki': PieceWood(
    Color(0xFF7A4E28), Color(0xFFA9763F), Color(0xFF4E2F16),
    Color(0xFF8F5F33), Color(0xFFF5EEDC),
  ),
  'tsuge': PieceWood(
    Color(0xFFF2DFB8), Color(0xFFFFF2D4), Color(0xFFC8A468),
    Color(0xFFE2C48E), Color(0xFF2A2115),
  ),
  'walnut': PieceWood(
    Color(0xFF9A6B3D), Color(0xFFC08D55), Color(0xFF5E3E20),
    Color(0xFF8A5E34), Color(0xFFF5EEDC),
  ),
  'sakura': PieceWood(
    Color(0xFFD9A184), Color(0xFFF2C4A4), Color(0xFFA06844),
    Color(0xFFC78F6E), Color(0xFF2E1F16),
  ),
  'kuro': PieceWood(
    Color(0xFF2E2724), Color(0xFF4E443E), Color(0xFF121010),
    Color(0xFF3E3632), Color(0xFFE8C86E),
  ),
  'shu': PieceWood(
    Color(0xFFB03324), Color(0xFFD4553E), Color(0xFF7C2115),
    Color(0xFFA02A1C), Color(0xFFF8ECD8),
  ),
  'bamboo': PieceWood(
    Color(0xFFE4D29A), Color(0xFFF8EAB8), Color(0xFFB89B5E),
    Color(0xFFD4BE7E), Color(0xFF2A2415),
  ),
};

/// Board woods (settings-selectable). 6 woods.
class BoardWood {
  final Color face;
  final Color edge;
  final Color grid;
  const BoardWood(this.face, this.edge, this.grid);

  BoardWood withGrid(Color grid) => BoardWood(face, edge, grid);
}

const Map<String, BoardWood> boardWoods = {
  'kaya': BoardWood(Color(0xFFD9AE62), Color(0xFFA87B3F), Color(0xFF4A3826)),
  'katsura':
      BoardWood(Color(0xFFE4C184), Color(0xFFB28C4E), Color(0xFF5A4630)),
  'walnut': BoardWood(Color(0xFF9A6B3D), Color(0xFF6E4525), Color(0xFF2E1F12)),
  'sakura': BoardWood(Color(0xFFC98F5F), Color(0xFF9A5F36), Color(0xFF3A2414)),
  'ebony': BoardWood(Color(0xFF4A3428), Color(0xFF2A1D14), Color(0xFFE9DFC6)),
  'bamboo': BoardWood(Color(0xFFE8D49A), Color(0xFFB89B5E), Color(0xFF5A4A2A)),
};

/// Board accent (grid ink) colors.
const Map<String, Color> boardAccents = {
  'ink': Color(0xFF4A3826),
  'vermilion': Color(0xFFC93A2B),
  'gold': Color(0xFFE0A93E),
  'pale': Color(0xFFE9DFC6),
};

/// Resolves the effective board wood: chosen wood + chosen accent grid.
BoardWood resolveBoardWood(SettingsService s) {
  final wood = boardWoods[s.boardWood] ?? boardWoods['kaya']!;
  return wood.withGrid(boardAccents[s.boardAccent] ?? wood.grid);
}

// ---------------------------------------------------------------------------
// Typography + shared materials (unchanged API)
// ---------------------------------------------------------------------------

/// Typography: brush-stroke kanji display + warm serif for English.
abstract class ShogiType {
  /// Kanji display (brush-stroke feel via weight + spacing).
  static TextStyle kanji(double size, Color color, {double spacing = 6}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: spacing,
        height: 1.2,
        shadows: [
          Shadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      );

  /// Warm humanist serif for English labels.
  static const String serif = 'serif';

  static TextStyle title(double size, Color color) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 2.0,
      );

  static TextStyle body(double size, Color color) => TextStyle(
        fontSize: size,
        color: color,
        height: 1.5,
      );

  static TextStyle get stat => TextStyle(
        fontFamily: serif,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ShogiPalette.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get caption => TextStyle(
        fontSize: 12,
        color: ShogiPalette.warmGray,
        height: 1.4,
      );
}

/// Shared material decorations: lacquered plaques, washi panels, wood buttons.
abstract class ShogiMaterials {
  /// Thick lacquered-wood plaque button with carved label feel.
  static BoxDecoration plaqueButton(
      {double radius = 12, bool pressed = false, bool primary = false}) {
    final top = pressed ? ShogiPalette.kayaDeep : ShogiPalette.kayaAmber;
    final bottom = pressed ? ShogiPalette.kayaAmber : ShogiPalette.kayaDeep;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ),
      border: Border.all(
        color: primary ? ShogiPalette.vermilion : const Color(0xFF7A5A2E),
        width: primary ? 2.5 : 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: pressed ? 4 : 10,
          offset: Offset(0, pressed ? 2 : 5),
        ),
        const BoxShadow(
          color: Color(0x66FFE9B8),
          blurRadius: 1,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  /// Dark lacquer plaque (headers, trays).
  static BoxDecoration lacquerPanel({double radius = 12}) => BoxDecoration(
        color: ShogiPalette.lacquer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF3A332C), width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6)),
          BoxShadow(
              color: Color(0x22E0A93E), blurRadius: 1, offset: Offset(0, -1)),
        ],
      );

  /// Washi paper card.
  static BoxDecoration washiCard({double radius = 14}) => BoxDecoration(
        color: ShogiPalette.washi,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ShogiPalette.washiShade, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 22, offset: Offset(0, 10)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Texture painters (procedural, subtle — Stitch material language).
// ---------------------------------------------------------------------------

/// Woven tatami background with edge vignette.
class TatamiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = ShogiPalette.tatami;
    canvas.drawRect(Offset.zero & size, bg);
    // Weave: fine horizontal + vertical threads.
    final thread = Paint()..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 5) {
      thread.color = (y ~/ 5).isEven
          ? ShogiPalette.tatamiDark.withValues(alpha: 0.35)
          : const Color(0xFFE4D4B2).withValues(alpha: 0.5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thread);
    }
    for (double x = 0; x < size.width; x += 5) {
      thread.color = (x ~/ 5).isEven
          ? Colors.transparent
          : ShogiPalette.tatamiDark.withValues(alpha: 0.18);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), thread);
    }
    // Cloth binding strips (heri) every ~1/3 height.
    final heri = Paint()..color = const Color(0xFF6E5B3E).withValues(alpha: 0.55);
    for (double y = size.height / 3; y < size.height; y += size.height / 3) {
      canvas.drawRect(Rect.fromLTWH(0, y - 5, size.width, 10), heri);
      final stitch = Paint()
        ..color = ShogiPalette.emberGold.withValues(alpha: 0.5)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, y - 5), Offset(size.width, y - 5), stitch);
      canvas.drawLine(Offset(0, y + 5), Offset(size.width, y + 5), stitch);
    }
    // Vignette to focus the center.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.75,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Kaya-wood slab face with straight grain and beveled light-catching edge.
class WoodSlabPainter extends CustomPainter {
  final Color face;
  final Color edge;
  final int seed;
  WoodSlabPainter({required this.face, required this.edge, this.seed = 7});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(10));
    // Edge bevel.
    canvas.drawRRect(rrect, Paint()..color = edge);
    final inner = RRect.fromRectAndRadius(
        Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
        const Radius.circular(6));
    canvas.drawRRect(inner, Paint()..color = face);
    // Straight grain lines.
    final rng = Random(seed);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = edge.withValues(alpha: 0.28);
    for (int i = 0; i < 16; i++) {
      final y = 10 + rng.nextDouble() * (size.height - 20);
      final wob = 2 + rng.nextDouble() * 5;
      final path = Path()
        ..moveTo(8, y)
        ..cubicTo(size.width * 0.3, y - wob, size.width * 0.6, y + wob,
            size.width - 8, y - wob / 2);
      canvas.drawPath(path, grain);
    }
    // Top-edge light catch.
    final light = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x55FFE9B8), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(inner, light);
  }

  @override
  bool shouldRepaint(covariant WoodSlabPainter oldDelegate) =>
      oldDelegate.face != face || oldDelegate.edge != edge;
}

/// Washi paper fibers.
class WashiPainter extends CustomPainter {
  final int seed;
  WashiPainter({this.seed = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final fiber = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * pi;
      final len = 3 + rng.nextDouble() * 7;
      fiber.color = const Color(0xFFB7A67F).withValues(alpha: 0.10);
      canvas.drawLine(Offset(x, y),
          Offset(x + cos(a) * len, y + sin(a) * len), fiber);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vermilion hanko seal stamp (square with kanji).
class SealStamp extends StatelessWidget {
  final String kanji;
  final double size;
  const SealStamp({super.key, required this.kanji, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ShogiPalette.vermilion,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ShogiPalette.vermilionDeep, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        kanji,
        style: ShogiType.kanji(size * 0.52, ShogiPalette.washi, spacing: 0),
      ),
    );
  }
}

/// Lacquered-wood plaque button with carved label.
class PlaqueButton extends StatefulWidget {
  final String kanji;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double width;
  const PlaqueButton({
    super.key,
    required this.kanji,
    required this.label,
    this.onTap,
    this.primary = false,
    this.width = 200,
  });

  @override
  State<PlaqueButton> createState() => _PlaqueButtonState();
}

class _PlaqueButtonState extends State<PlaqueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: ShogiMaterials.plaqueButton(
            pressed: _pressed, primary: widget.primary),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.kanji,
                style: ShogiType.kanji(20, ShogiPalette.lacquer, spacing: 2)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                style: ShogiType.title(15, ShogiPalette.lacquer),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round lacquer disc button (pause, settings).
class DiscButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const DiscButton({super.key, required this.icon, this.onTap, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ShogiPalette.lacquerSoft, ShogiPalette.lacquer],
          ),
          border: Border.all(color: ShogiPalette.emberGold, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: ShogiPalette.washi, size: size * 0.45),
      ),
    );
  }
}

/// Wooden toggle switch sliding in a carved groove (piece-shaped knob).
class WoodToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const WoodToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: ShogiPalette.kayaDeep,
          border: Border.all(color: const Color(0xFF6E4E26), width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 3, offset: Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: value
                        ? [ShogiPalette.emberGold, ShogiPalette.kayaDeep]
                        : [ShogiPalette.washiShade, ShogiPalette.warmGray],
                  ),
                  border: Border.all(
                      color: value
                          ? ShogiPalette.vermilion
                          : const Color(0xFF6E6252),
                      width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bamboo rod slider with wooden bead thumb.
class BambooSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const BambooSlider(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: ShogiPalette.kayaAmber,
        inactiveTrackColor: ShogiPalette.kayaDeep.withValues(alpha: 0.5),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
        thumbColor: ShogiPalette.emberGold,
        overlayColor: ShogiPalette.vermilion.withValues(alpha: 0.2),
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}
