/// Shogi PRO screen: Free-vs-Pro comparison + tip jar.
///
/// Products (created by Wajiha in Play Console):
/// - shogipro: one-time Pro unlock (non-consumable)
/// - shogicoffee / shogichocolate: consumable tips
/// Until the products exist, the screen honestly says
/// "available after store setup" — never a fake buy button.
library;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../audio.dart';
import '../iap.dart';
import '../theme.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final _store = StoreService.I;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _store.init();
    _store.lastThanks.addListener(_thanks);
    _store.proPurchased.addListener(_repaint);
    if (mounted) setState(() => _loading = false);
  }

  void _thanks() {
    final msg = _store.lastThanks.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: ShogiPalette.vermilion,
      ));
      _store.lastThanks.value = null;
    }
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_thanks);
    _store.proPurchased.removeListener(_repaint);
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
              padding: const EdgeInsets.all(20),
              child: Column(
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
                      Text('将棋 PRO',
                          style: ShogiType.kanji(30, ShogiPalette.ink,
                              spacing: 6)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Support indie shogi — unlock the full dojo.',
                      style: TextStyle(color: ShogiPalette.warmGray)),
                  const SizedBox(height: 16),
                  _comparisonCard(),
                  const SizedBox(height: 16),
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: ShogiPalette.vermilion),
                    )
                  else
                    _storeSection(),
                  const SizedBox(height: 16),
                  _tipJar(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard() {
    const rows = [
      ('Full game — vs Bot & 2 players', true, true),
      ('3 bot difficulties + handicaps', true, true),
      ('12 themes + custom theme creator', true, true),
      ('9 piece finishes, 6 board woods', true, true),
      ('All game modes, undo, draw offers', true, true),
      ('Master-level deep analysis hints', false, true),
      ('Exclusive 金 gold piece finish', false, true),
      ('Priority new features', false, true),
      ('No "support" reminders', false, true),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ShogiMaterials.washiCard(),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(flex: 3),
              Expanded(
                  child: Center(
                      child: Text('FREE',
                          style: ShogiType.title(14, ShogiPalette.ink)))),
              Expanded(
                  child: Center(
                      child: Text('PRO',
                          style: ShogiType.title(
                              14, ShogiPalette.vermilion)))),
            ],
          ),
          const Divider(),
          for (final (label, free, pro) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(label,
                        style: ShogiType.body(13, ShogiPalette.ink)),
                  ),
                  Expanded(child: _check(free)),
                  Expanded(child: _check(pro)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _check(bool v) => Center(
        child: Icon(v ? Icons.check_circle : Icons.remove_circle_outline,
            color: v ? ShogiPalette.vermilion : ShogiPalette.warmGray,
            size: 20),
      );

  Widget _storeSection() {
    if (!_store.storeReady) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: ShogiMaterials.washiCard(),
        child: Column(
          children: [
            const SealStamp(kanji: '錠', size: 44),
            const SizedBox(height: 10),
            Text('準備中',
                style: ShogiType.kanji(22, ShogiPalette.ink, spacing: 4)),
            const SizedBox(height: 6),
            Text(
              _store.error ?? 'Available after store setup',
              textAlign: TextAlign.center,
              style: ShogiType.body(14, ShogiPalette.warmGray),
            ),
            const SizedBox(height: 6),
            Text(
              'The PRO upgrade and tip jar appear here once the products are created in Play Console.',
              textAlign: TextAlign.center,
              style: ShogiType.caption,
            ),
          ],
        ),
      );
    }
    final pro = _store.proProduct;
    return Column(
      children: [
        if (_store.proPurchased.value)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: ShogiMaterials.washiCard(),
            child: Row(
              children: [
                const SealStamp(kanji: '極', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRO active',
                          style: ShogiType.title(16, ShogiPalette.ink)),
                      Text('Thank you for supporting indie shogi!',
                          style: ShogiType.body(13, ShogiPalette.warmGray)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (pro != null)
          _buyCard(
            kanji: '極',
            title: 'Shogi PRO',
            subtitle: 'One-time unlock, yours forever.',
            price: pro.price,
            onBuy: () {
              AudioService.I.click();
              _store.buyPro();
            },
          ),
        const SizedBox(height: 10),
        ValueListenableBuilder<String?>(
          valueListenable: _store.purchaseError,
          builder: (ctx, err, _) => err == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(err,
                      style:
                          TextStyle(color: ShogiPalette.vermilion)),
                ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _store.purchaseInProgress,
          builder: (ctx, busy, _) => busy
              ? Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      color: ShogiPalette.vermilion),
                )
              : const SizedBox.shrink(),
        ),
        TextButton(
          onPressed: () {
            AudioService.I.click();
            _store.restore();
          },
          child: Text('Restore purchases',
              style: TextStyle(
                  color: ShogiPalette.vermilion,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buyCard({
    required String kanji,
    required String title,
    required String subtitle,
    required String price,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShogiMaterials.washiCard(),
      child: Row(
        children: [
          SealStamp(kanji: kanji, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ShogiType.title(17, ShogiPalette.ink)),
                Text(subtitle,
                    style: ShogiType.body(13, ShogiPalette.warmGray)),
                Text(price,
                    style: ShogiType.title(15, ShogiPalette.vermilion)),
              ],
            ),
          ),
          PlaqueButton(
              kanji: '買', label: 'Buy', primary: true, width: 110, onTap: onBuy),
        ],
      ),
    );
  }

  Widget _tipJar() {
    final coffee = _store.coffeeProduct;
    final choco = _store.chocolateProduct;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: ShogiMaterials.washiCard(),
      child: Column(
        children: [
          Text('茶 Tip jar',
              style: ShogiType.kanji(22, ShogiPalette.ink, spacing: 4)),
          const SizedBox(height: 4),
          Text(
            'Shogi is free forever. Tips keep the pieces polished.',
            textAlign: TextAlign.center,
            style: ShogiType.body(13, ShogiPalette.warmGray),
          ),
          const SizedBox(height: 12),
          if (!_store.storeReady)
            Text('Available after store setup',
                style: ShogiType.caption)
          else
            Row(
              children: [
                if (coffee != null)
                  Expanded(
                      child: _tipButton('☕', 'Coffee', coffee,
                          () => _store.buyTip(coffee))),
                if (coffee != null && choco != null)
                  const SizedBox(width: 10),
                if (choco != null)
                  Expanded(
                      child: _tipButton('🍫', 'Chocolate', choco,
                          () => _store.buyTip(choco))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tipButton(
      String emoji, String label, ProductDetails p, VoidCallback onBuy) {
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        onBuy();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: ShogiMaterials.plaqueButton(radius: 10),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(label, style: ShogiType.title(13, ShogiPalette.lacquer)),
            Text(p.price,
                style: ShogiType.title(13, ShogiPalette.vermilionDeep)),
          ],
        ),
      ),
    );
  }
}
