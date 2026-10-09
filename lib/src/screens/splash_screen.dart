/// Splash flow: WAJIHA company splash -> game splash (logo + name +
/// animated loading line + "Credits: WAJIHA") -> main menu.
///
/// Heavy startup work (settings, audio prewarm, store init) happens here
/// while the loading line animates.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../iap.dart';
import '../settings.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _companyDone = false;
  late final AnimationController _lineCtrl;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addListener(() => setState(() {}));
    _boot();
  }

  Future<void> _boot() async {
    // Company splash moment (official WAJIHA logo, untouched).
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => _companyDone = true);
    _lineCtrl.forward();
    // Startup work while the loading line animates.
    await SettingsService.I.init();
    await AudioService.I.init();
    AudioService.I.configure(
      musicOn: SettingsService.I.musicOn,
      sfxOn: SettingsService.I.sfxOn,
      volume: SettingsService.I.volume,
      musicVolume: SettingsService.I.musicVolume,
    );
    unawaited(AudioService.I.prewarm());
    unawaited(StoreService.I.init());
    unawaited(AudioService.I.menuMusic());
    await Future.delayed(const Duration(milliseconds: 2300));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_companyDone) return _companySplash();
    return _gameSplash();
  }

  Widget _companySplash() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          builder: (ctx, v, child) => Opacity(opacity: v, child: child),
          child: Padding(
            padding: const EdgeInsets.all(64),
            child: Image.asset(
              'assets/images/wajiha_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameSplash() {
    final t = _lineCtrl.value.clamp(0.0, 1.0);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TatamiPainter())),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1),
                    duration: const Duration(milliseconds: 1200),
                    builder: (ctx, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black45,
                              blurRadius: 24,
                              offset: Offset(0, 10)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/images/shogi_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('将棋',
                      style: ShogiType.kanji(64, ShogiPalette.ink,
                          spacing: 20)),
                  Text('SHOGI — Japanese Chess',
                      style: ShogiType.title(16, ShogiPalette.ink)),
                  const SizedBox(height: 28),
                  // Animated loading line.
                  Container(
                    width: 220,
                    height: 6,
                    decoration: BoxDecoration(
                      color: ShogiPalette.kayaDeep.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 220 * t,
                        height: 6,
                        decoration: BoxDecoration(
                          color: ShogiPalette.vermilion,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/wajiha_logo.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: ShogiType.title(14, ShogiPalette.ink)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
