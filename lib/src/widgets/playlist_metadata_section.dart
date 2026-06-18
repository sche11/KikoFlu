import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/playlist.dart';

class PlaylistMetadataSection extends StatelessWidget {
  const PlaylistMetadataSection({
    super.key,
    required this.metadata,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  final Playlist metadata;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final displayDate = _displayDate();
    final dateLabel = _usesUpdatedDate()
        ? S.of(context).lastUpdated
        : S.of(context).createdTime;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.displayName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metadata.userName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              _PlaylistMetadataActions(
                isOwner: isOwner,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
          ),
          if (metadata.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              metadata.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.music_note,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                S.of(context).nWorksCount(metadata.worksCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (metadata.playbackCount > 0) ...[
                const SizedBox(width: 16),
                Icon(
                  Icons.play_circle_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  S.of(context).nPlaysCount(metadata.playbackCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const Spacer(),
              if (displayDate.isNotEmpty)
                Text(
                  '$dateLabel: $displayDate',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  bool _usesUpdatedDate() {
    return metadata.updatedAt.isNotEmpty &&
        metadata.updatedAt != metadata.createdAt;
  }

  String _displayDate() {
    final dateText =
        _usesUpdatedDate() ? metadata.updatedAt : metadata.createdAt;
    if (dateText.isEmpty) return '';

    try {
      final date = DateTime.parse(dateText);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateText;
    }
  }
}

class _PlaylistMetadataActions extends StatelessWidget {
  const _PlaylistMetadataActions({
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return IconButton(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
        tooltip: S.of(context).unfavorite,
        visualDensity: VisualDensity.compact,
        color: Theme.of(context).colorScheme.error,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          tooltip: S.of(context).edit,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: S.of(context).delete,
          visualDensity: VisualDensity.compact,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}
