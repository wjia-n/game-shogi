/// Japanese craft design tokens — Stitch visual source of truth.
/// See stitch-batch3/shogi/DESIGN.md
library;

import 'dart:math';

import 'package:flutter/material.dart';

/// Palette from the Stitch "Japanese craft" design system.
abstract class ShogiPalette {
  static const tatami = Color(0xFFD9C9A8); // app background (woven straw)
  static const tatamiDark = Color(0xFFC4B28E);
  static const kayaAmber = Color(0xFFC89B5A); // board slab, button plaques
  static const kayaDeep = Color(0xFFA87B3F); // board edge bevel, pressed state
  static const kayaLight = Color(0xFFDDB271);
  static const lacquer = Color(0xFF1A1817); // header strips, trays, primary plaques
  static const lacquerSoft = Color(0xFF2B2622);
  static const washi = Color(0xFFF5EEDC); // paper panels, cards, dialogs
  static const washiShade = Color(0xFFE9DFC6);
  static const ink = Color(0xFF24211D); // primary text on cream
  static const vermilion = Color(0xFFC93A2B); // accents, selection, check
  static const vermilionDeep = Color(0xFFA02A1F);
  static const warmGray = Color(0xFF8A7F6E); // secondary text
  static const emberGold = Color(0xFFE0A93E); // highlights, top-edge light
  static const gridInk = Color(0xFF4A3826); // board grid lines
}

/// Piece wood finishes (settings-selectable).
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
};

/// Board wood choices (settings-selectable).
class BoardWood {
  final Color face;
  final Color edge;
  final Color grid;
  const BoardWood(this.face, this.edge, this.grid);
}

const Map<String, BoardWood> boardWoods = {
  'kaya': BoardWood(Color(0xFFD9AE62), Color(0xFFA87B3F), Color(0xFF4A3826)),
  'katsura': BoardWood(Color(0xFFE4C184), Color(0xFFB28C4E), Color(0xFF5A4630)),
  'walnut': BoardWood(Color(0xFF9A6B3D), Color(0xFF6E4525), Color(0xFF2E1F12)),
};

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

  static const TextStyle stat = TextStyle(
    fontFamily: serif,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: ShogiPalette.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle caption = TextStyle(
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
    canvas.drawRRect(
        rrect, Paint()..color = edge);
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
        end: Alignment.center,
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
          gradient: const LinearGradient(
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
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
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
