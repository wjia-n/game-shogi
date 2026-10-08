import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const ShogiApp());

class ShogiApp extends StatelessWidget {
  const ShogiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Shogi',
      tagline: 'Japanese chess with sneaky piece drops! Outsmart the bot! 👑',
      emoji: '👑',
      slug: 'shogi',
      howToPlay:
          '• Fast 5×5 mini-shogi! Tap your piece, then tap a glowing square to move.\n• Captured pieces join YOUR hand — tap one, then tap any empty square to drop it back in!\n• No pawn drops on the last rank or in a file that already has your pawn.\n• Checkmate the enemy king (王) to win! Solo vs the bot or duel a friend!',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => ShogiScreen(players: players, callbacks: cb),
    );
  }
}
