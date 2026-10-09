/// Game configuration + save/restore via shared_preferences.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';

/// Match configuration chosen on the menu.
class GameConfig {
  final String mode; // 'bot' or '2p'
  final int difficulty; // 0 beginner, 1 skilled, 2 master
  final String handicap; // 'even', 'lance', '2piece', '4piece', '6piece'
  final String senteName;
  final String goteName;
  final String playerName;

  const GameConfig({
    required this.mode,
    this.difficulty = 1,
    this.handicap = 'even',
    this.senteName = 'You',
    this.goteName = 'Bot',
    this.playerName = 'You',
  });

  /// Which color the human plays in bot mode (0 = both, for 2p).
  int get humanColor =>
      mode == '2p' ? 0 : (handicap == 'even' ? sente : gote);

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'difficulty': difficulty,
        'handicap': handicap,
        'senteName': senteName,
        'goteName': goteName,
        'playerName': playerName,
      };

  factory GameConfig.fromJson(Map<String, dynamic> j) => GameConfig(
        mode: j['mode'] as String? ?? 'bot',
        difficulty: j['difficulty'] as int? ?? 1,
        handicap: j['handicap'] as String? ?? 'even',
        senteName: j['senteName'] as String? ?? 'You',
        goteName: j['goteName'] as String? ?? 'Bot',
        playerName: j['playerName'] as String? ?? 'You',
      );
}

const Map<String, String> handicapLabel = {
  'even': 'Even',
  'lance': 'Lance drop',
  '2piece': '2-piece',
  '4piece': '4-piece',
  '6piece': '6-piece',
};

const Map<String, String> handicapKanji = {
  'even': '互角',
  'lance': '香',
  '2piece': '二枚',
  '4piece': '四枚',
  '6piece': '六枚',
};

const Map<int, String> difficultyLabel = {
  0: 'Beginner',
  1: 'Skilled',
  2: 'Master',
};

const Map<int, String> difficultyKanji = {
  0: '初級',
  1: '上級',
  2: '達人',
};

/// Saved in-progress game.
class GameSave {
  static const _key = 'shogi_save_v1';

  static Future<bool> has() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_key);
  }

  static Future<Map<String, dynamic>?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> store(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(data));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
