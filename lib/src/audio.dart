/// AudioService — Japanese craft soundscape for Shogi.
///
/// Dry, woody, percussive SFX (synthesized WAVs in assets/) + sparse
/// koto/shakuhachi loops. Music/SFX toggles and volume controls work.
library;

import 'package:audioplayers/audioplayers.dart';

import 'settings.dart';

class AudioService {
  static final AudioService I = AudioService._();
  AudioService._();

  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();

  bool _ready = false;
  String? _currentTrack;

  SettingsService get _s => SettingsService.I;

  Future<void> init() async {
    if (_ready) return;
    await SettingsService.I.init();
    await _music.setReleaseMode(ReleaseMode.loop);
    await _applyVolumes();
    _ready = true;
  }

  Future<void> _applyVolumes() async {
    try {
      await _music.setVolume(_s.volume * _s.musicVolume);
      await _sfx.setVolume(_s.volume);
    } catch (_) {}
  }

  /// Call after settings change.
  Future<void> refresh() async {
    await _applyVolumes();
    if (!_s.musicOn) {
      await stopMusic();
      _currentTrack = null;
    }
  }

  Future<void> _playSfx(String file) async {
    if (!_s.sfxOn) return;
    try {
      await _sfx.setVolume(_s.volume);
      await _sfx.play(AssetSource('sounds/$file'));
    } catch (_) {}
  }

  // ---- SFX ----
  Future<void> click() => _playSfx('button_click.wav');
  Future<void> select() => _playSfx('piece_select.wav');
  Future<void> move() => _playSfx('piece_move.wav');
  Future<void> drop() => _playSfx('piece_drop.wav');
  Future<void> capture() => _playSfx('capture.wav');
  Future<void> check() => _playSfx('check_alert.wav');
  Future<void> promote() => _playSfx('promotion.wav');
  Future<void> gameStart() => _playSfx('game_start.wav');
  Future<void> win() => _playSfx('win.wav');
  Future<void> lose() => _playSfx('lose.wav');
  Future<void> draw() => _playSfx('draw.wav');
  Future<void> invalid() => _playSfx('invalid.wav');

  // ---- Music ----
  Future<void> _playTrack(String file) async {
    if (!_s.musicOn) return;
    if (_currentTrack == file) return;
    _currentTrack = file;
    try {
      await _music.setVolume(_s.volume * _s.musicVolume);
      await _music.play(AssetSource('music/$file'));
    } catch (_) {}
  }

  Future<void> menuMusic() => _playTrack('menu_music.wav');
  Future<void> gameMusic() => _playTrack('game_music.wav');

  Future<void> stopMusic() async {
    _currentTrack = null;
    try {
      await _music.stop();
    } catch (_) {}
  }

  void dispose() {
    _sfx.dispose();
    _music.dispose();
  }
}
