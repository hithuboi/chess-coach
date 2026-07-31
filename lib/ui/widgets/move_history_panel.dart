import 'package:flutter/material.dart';
import 'package:chess_app/engine/move_classifier.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/utils/extensions.dart';

/// Displays the game's move history in standard "1. e4 e5" row format,
/// with an optional quality tag (Excellent / Good / Mistake / Blunder)
/// shown next to any move that's been classified.
class MoveHistoryPanel extends StatefulWidget {
  final List<Move> moves;

  /// Quality classification for individual moves, keyed by that move's
  /// index in [moves]. Only moves that have been classified appear
  /// here -- v0.1 only classifies the human player's moves, so this
  /// map typically covers roughly every other entry.
  final Map<int, MoveQuality> moveQualities;

  const MoveHistoryPanel({
    super.key,
    required this.moves,
    this.moveQualities = const {},
  });

  @override
  State<MoveHistoryPanel> createState() => _MoveHistoryPanelState();
}

class _MoveHistoryPanelState extends State<MoveHistoryPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moves.length != oldWidget.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.moves.paired;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Moves', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'No moves yet',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rows.length,
                    itemBuilder: (context, index) =>
                        _buildRow(context, rows[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, MoveHistoryRow row) {
    final theme = Theme.of(context);
    final whiteIndex = (row.moveNumber - 1) * 2;
    final blackIndex = whiteIndex + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.moveNumber}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _buildMoveCell(
              context,
              row.whiteMove.toSan(),
              widget.moveQualities[whiteIndex],
            ),
          ),
          Expanded(
            child: row.blackMove != null
                ? _buildMoveCell(
                    context,
                    row.blackMove!.toSan(),
                    widget.moveQualities[blackIndex],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveCell(
    BuildContext context,
    String san,
    MoveQuality? quality,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(san, style: theme.textTheme.labelLarge),
        if (quality != null) ...[
          const SizedBox(width: 6),
          _buildQualityTag(quality),
        ],
      ],
    );
  }

  Widget _buildQualityTag(MoveQuality quality) {
    final (label, color) = switch (quality) {
      MoveQuality.excellent => ('Excellent', const Color(0xFF2E7D32)),
      MoveQuality.good => ('Good', const Color(0xFF1976D2)),
      MoveQuality.mistake => ('Mistake', const Color(0xFFE65100)),
      MoveQuality.blunder => ('Blunder', const Color(0xFFC62828)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
