/// Persistent settings (shared_preferences): sound, visuals, game options.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Piece wood finishes.
const List<String> pieceStyles = ['kaya', 'katsura', 'kurogaki'];
const Map<String, String> pieceStyleLabel = {
  'kaya': 'Kaya',
  'katsura': 'Katsura',
  'kurogaki': 'Kurogaki',
};

/// Board wood choices.
const List<String> boardWoodIds = ['kaya', 'katsura', 'walnut'];
const Map<String, String> boardWoodLabel = {
  'kaya': 'Kaya',
  'katsura': 'Katsura',
  'walnut': 'Walnut',
};

class SettingsService {
  static final SettingsService I = SettingsService._();
  SettingsService._();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8; // master
  double musicVolume = 0.6; // relative multiplier

  String pieceStyle = 'kaya';
  String boardWood = 'kaya';
  bool showLegalDots = true;
  bool showCoordinates = true;
  bool confirmResign = true;
  bool allowUndo = true;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    musicOn = p.getBool('shogi_musicOn') ?? true;
    sfxOn = p.getBool('shogi_sfxOn') ?? true;
    volume = p.getDouble('shogi_volume') ?? 0.8;
    musicVolume = p.getDouble('shogi_musicVolume') ?? 0.6;
    pieceStyle = p.getString('shogi_pieceStyle') ?? 'kaya';
    boardWood = p.getString('shogi_boardWood') ?? 'kaya';
    showLegalDots = p.getBool('shogi_showLegalDots') ?? true;
    showCoordinates = p.getBool('shogi_showCoordinates') ?? true;
    confirmResign = p.getBool('shogi_confirmResign') ?? true;
    allowUndo = p.getBool('shogi_allowUndo') ?? true;
    _ready = true;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('shogi_musicOn', musicOn);
    await p.setBool('shogi_sfxOn', sfxOn);
    await p.setDouble('shogi_volume', volume);
    await p.setDouble('shogi_musicVolume', musicVolume);
    await p.setString('shogi_pieceStyle', pieceStyle);
    await p.setString('shogi_boardWood', boardWood);
    await p.setBool('shogi_showLegalDots', showLegalDots);
    await p.setBool('shogi_showCoordinates', showCoordinates);
    await p.setBool('shogi_confirmResign', confirmResign);
    await p.setBool('shogi_allowUndo', allowUndo);
  }

  Future<void> update(Future<void> Function() apply) async {
    await apply();
    await _persist();
  }

  Future<void> resetDefaults() async {
    musicOn = true;
    sfxOn = true;
    volume = 0.8;
    musicVolume = 0.6;
    pieceStyle = 'kaya';
    boardWood = 'kaya';
    showLegalDots = true;
    showCoordinates = true;
    confirmResign = true;
    allowUndo = true;
    await _persist();
  }
}
