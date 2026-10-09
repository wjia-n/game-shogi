/// Persistent settings (shared_preferences): sound, visuals, names, themes.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Piece finishes (settings-selectable). 9 styles.
const List<String> pieceStyles = [
  'kaya',
  'katsura',
  'kurogaki',
  'tsuge',
  'walnut',
  'sakura',
  'kuro',
  'shu',
  'bamboo',
];
const Map<String, String> pieceStyleLabel = {
  'kaya': 'Kaya',
  'katsura': 'Katsura',
  'kurogaki': 'Kurogaki',
  'tsuge': 'Boxwood',
  'walnut': 'Walnut',
  'sakura': 'Cherry',
  'kuro': 'Black lacquer',
  'shu': 'Vermilion lacquer',
  'bamboo': 'Bamboo',
};

/// Board wood choices (settings-selectable). 6 woods.
const List<String> boardWoodIds = [
  'kaya',
  'katsura',
  'walnut',
  'sakura',
  'ebony',
  'bamboo',
];
const Map<String, String> boardWoodLabel = {
  'kaya': 'Kaya',
  'katsura': 'Katsura',
  'walnut': 'Walnut',
  'sakura': 'Cherry',
  'ebony': 'Ebony',
  'bamboo': 'Pale bamboo',
};

/// Board accent (grid ink + star-point) choices.
const List<String> boardAccentIds = ['ink', 'vermilion', 'gold', 'pale'];
const Map<String, String> boardAccentLabel = {
  'ink': 'Sumi ink',
  'vermilion': 'Vermilion',
  'gold': 'Ember gold',
  'pale': 'Pale ash',
};

class SettingsService {
  static final SettingsService I = SettingsService._();
  SettingsService._();

  // Audio.
  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8; // master
  double musicVolume = 0.6; // relative multiplier

  // Visuals.
  String themeId = 'kaya-classic';
  String pieceStyle = 'kaya';
  String boardWood = 'kaya';
  String boardAccent = 'ink';
  bool showLegalDots = true;
  bool showCoordinates = true;

  // Game.
  bool confirmResign = true;
  bool allowUndo = true;
  int difficulty = 1;

  // Names (every slot renameable, persisted).
  String humanName = 'You';
  String botName = 'Bot';
  String senteName = 'Black';
  String goteName = 'White';

  // Custom theme colors (ARGB ints).
  int customBg = 0xFFD9C9A8;
  int customBoard = 0xFFD9AE62;
  int customBoardEdge = 0xFFA87B3F;
  int customAccent = 0xFFC93A2B;
  int customPaper = 0xFFF5EEDC;

  bool _ready = false;
  bool get ready => _ready;

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    musicOn = p.getBool('shogi_musicOn') ?? true;
    sfxOn = p.getBool('shogi_sfxOn') ?? true;
    volume = p.getDouble('shogi_volume') ?? 0.8;
    musicVolume = p.getDouble('shogi_musicVolume') ?? 0.6;
    themeId = p.getString('shogi_themeId') ?? 'kaya-classic';
    pieceStyle = p.getString('shogi_pieceStyle') ?? 'kaya';
    if (!pieceStyles.contains(pieceStyle)) pieceStyle = 'kaya';
    boardWood = p.getString('shogi_boardWood') ?? 'kaya';
    if (!boardWoodIds.contains(boardWood)) boardWood = 'kaya';
    boardAccent = p.getString('shogi_boardAccent') ?? 'ink';
    if (!boardAccentIds.contains(boardAccent)) boardAccent = 'ink';
    showLegalDots = p.getBool('shogi_showLegalDots') ?? true;
    showCoordinates = p.getBool('shogi_showCoordinates') ?? true;
    confirmResign = p.getBool('shogi_confirmResign') ?? true;
    allowUndo = p.getBool('shogi_allowUndo') ?? true;
    difficulty = p.getInt('shogi_difficulty') ?? 1;
    humanName = p.getString('shogi_humanName') ?? 'You';
    botName = p.getString('shogi_botName') ?? 'Bot';
    senteName = p.getString('shogi_senteName') ?? 'Black';
    goteName = p.getString('shogi_goteName') ?? 'White';
    customBg = p.getInt('shogi_customBg') ?? 0xFFD9C9A8;
    customBoard = p.getInt('shogi_customBoard') ?? 0xFFD9AE62;
    customBoardEdge = p.getInt('shogi_customBoardEdge') ?? 0xFFA87B3F;
    customAccent = p.getInt('shogi_customAccent') ?? 0xFFC93A2B;
    customPaper = p.getInt('shogi_customPaper') ?? 0xFFF5EEDC;
    _ready = true;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('shogi_musicOn', musicOn);
    await p.setBool('shogi_sfxOn', sfxOn);
    await p.setDouble('shogi_volume', volume);
    await p.setDouble('shogi_musicVolume', musicVolume);
    await p.setString('shogi_themeId', themeId);
    await p.setString('shogi_pieceStyle', pieceStyle);
    await p.setString('shogi_boardWood', boardWood);
    await p.setString('shogi_boardAccent', boardAccent);
    await p.setBool('shogi_showLegalDots', showLegalDots);
    await p.setBool('shogi_showCoordinates', showCoordinates);
    await p.setBool('shogi_confirmResign', confirmResign);
    await p.setBool('shogi_allowUndo', allowUndo);
    await p.setInt('shogi_difficulty', difficulty);
    await p.setString('shogi_humanName', humanName);
    await p.setString('shogi_botName', botName);
    await p.setString('shogi_senteName', senteName);
    await p.setString('shogi_goteName', goteName);
    await p.setInt('shogi_customBg', customBg);
    await p.setInt('shogi_customBoard', customBoard);
    await p.setInt('shogi_customBoardEdge', customBoardEdge);
    await p.setInt('shogi_customAccent', customAccent);
    await p.setInt('shogi_customPaper', customPaper);
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
    themeId = 'kaya-classic';
    pieceStyle = 'kaya';
    boardWood = 'kaya';
    boardAccent = 'ink';
    showLegalDots = true;
    showCoordinates = true;
    confirmResign = true;
    allowUndo = true;
    difficulty = 1;
    humanName = 'You';
    botName = 'Bot';
    senteName = 'Black';
    goteName = 'White';
    await _persist();
  }
}
