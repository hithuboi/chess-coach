import 'package:flutter/material.dart';

/// A row of primary game controls: Undo and Restart.
class GameControlsBar extends StatelessWidget {
  /// Called when the user taps "Undo".
  final VoidCallback onUndo;

  /// Called when the user taps "Restart".
  final VoidCallback onRestart;

  /// Whether an undo is currently possible.
  final bool canUndo;

  const GameControlsBar({
    super.key,
    required this.onUndo,
    required this.onRestart,
    required this.canUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: () => _confirmRestart(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Restart'),
        ),
      ],
    );
  }

  Future<void> _confirmRestart(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart game?'),
        content: const Text(
          'This will discard the current game and start a new one from '
          'the beginning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onRestart();
    }
  }
}
