import 'package:flutter/material.dart';
import 'package:chess_app/models/move.dart';
import 'package:chess_app/utils/extensions.dart';

/// Displays the game's move history in standard "1. e4 e5" row format.
class MoveHistoryPanel extends StatefulWidget {
  final List<Move> moves;

  const MoveHistoryPanel({super.key, required this.moves});

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
            child: Text(
              row.whiteMove.toSan(),
              style: theme.textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: Text(
              row.blackMove?.toSan() ?? '',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
