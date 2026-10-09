/// Shogi audio — Japanese craft soundscape.
///
/// Reliability design (copied from the proven Ludo exemplar):
/// - All synthesized WAV clips are loaded ONCE from assets into a memory
///   cache; playing never touches disk after the first load.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu
///   in/out, pause/resume, toggles) can never swallow a start or leave the
///   player half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, background)
///   resumes exactly where it left off instead of restarting or dying.
/// - A small pool of SFX players means overlapping sounds (move + check,
///   rapid taps) never cut each other off.
/// - Every public method catches player errors; audio can never crash the app.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService I = AudioService._();
  AudioService._();

  // SFX pool: round-robin so overlapping sounds never cut each other.
  final List<AudioPlayer> _sfxPool =
      List.generate(4, (_) => AudioPlayer());
  int _sfxIdx = 0;
  final AudioPlayer _music = AudioPlayer();

  bool _musicOn = true;
  bool _sfxOn = true;
  double _volume = 0.8;
  double _musicVolume = 0.6;

  /// Memory cache of clip bytes (loaded once from assets).
  final Map<String, Uint8List> _cache = {};
  bool _prewarmed = false;

  // Music state machine.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  static const _sfxFiles = [
    'button_click.wav',
    'piece_select.wav',
    'piece_move.wav',
    'piece_drop.wav',
    'capture.wav',
    'check_alert.wav',
    'promotion.wav',
    'game_start.wav',
    'win.wav',
    'lose.wav',
    'draw.wav',
    'invalid.wav',
  ];

  Future<void> init() async {
    await _music.setReleaseMode(ReleaseMode.loop);
    await _applyVolumes();
  }

  void configure({
    required bool musicOn,
    required bool sfxOn,
    required double volume,
    required double musicVolume,
  }) {
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    _volume = volume.clamp(0.0, 1.0);
    _musicVolume = musicVolume.clamp(0.0, 1.0);
    _applyVolumes();
    if (!musicOn) {
      stopMusic();
    }
  }

  Future<void> _applyVolumes() async {
    try {
      await _music.setVolume(_musicOn ? _volume * _musicVolume : 0.0);
      for (final p in _sfxPool) {
        await p.setVolume(_sfxOn ? _volume : 0.0);
      }
    } catch (_) {}
  }

  /// Call after settings change.
  Future<void> refresh({
    required bool musicOn,
    required bool sfxOn,
    required double volume,
    required double musicVolume,
  }) async {
    configure(
        musicOn: musicOn,
        sfxOn: sfxOn,
        volume: volume,
        musicVolume: musicVolume);
  }

  /// Pre-load every clip into the memory cache off the critical path.
  /// Safe to call any time; call once from the splash screen.
  Future<void> prewarm() async {
    if (_prewarmed || _disposed) return;
    _prewarmed = true;
    for (final f in _sfxFiles) {
      await _bytes('sounds/$f');
    }
    await _bytes('music/menu_music.wav');
    await _bytes('music/game_music.wav');
  }

  Future<Uint8List?> _bytes(String asset) async {
    final hit = _cache[asset];
    if (hit != null) return hit;
    try {
      final data = await rootBundle.load('assets/$asset');
      final bytes = data.buffer.asUint8List();
      _cache[asset] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _playSfx(String file) async {
    if (!_sfxOn || _disposed) return;
    final bytes = await _bytes('sounds/$file');
    if (bytes == null) return;
    final player = _sfxPool[_sfxIdx];
    _sfxIdx = (_sfxIdx + 1) % _sfxPool.length;
    try {
      await player.stop();
      await player.play(BytesSource(bytes));
    } catch (_) {}
  }

  // ---- SFX (wooden piece taps, paper, temple blocks, drums) ----
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
  Future<void> _startTrack(String track, String asset) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !_musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !_musicOn) return;
      final bytes = await _bytes(asset);
      if (bytes == null) {
        _currentTrack = null;
        return;
      }
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.setVolume(_volume * _musicVolume);
      await _music.play(BytesSource(bytes));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> menuMusic() => _startTrack('menu', 'music/menu_music.wav');
  Future<void> gameMusic() => _startTrack('game', 'music/game_music.wav');

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !_musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await menuMusic();
      } else if (track == 'game') {
        await gameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      for (final p in _sfxPool) {
        await p.dispose();
      }
      await _music.dispose();
    } catch (_) {}
  }
}
