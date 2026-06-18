import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../utils/file_icon_utils.dart';
import '../utils/string_utils.dart';
import '../utils/subtitle_library_display.dart';

typedef SubtitleLibrarySelectionToggle = void Function(
  String path,
  bool isFolder,
  Map<String, dynamic> item,
);

typedef SubtitleLibraryFileOptions = void Function(
  Map<String, dynamic> item,
  String path,
);

class SubtitleLibraryFileList extends StatelessWidget {
  const SubtitleLibraryFileList({
    super.key,
    required this.items,
    required this.selectedPaths,
    required this.selectionMode,
    required this.recursive,
    required this.onRefresh,
    required this.onSelectionToggle,
    required this.onFolderTap,
    required this.onPreviewFile,
    required this.onLoadSubtitle,
    required this.onShowOptions,
  });

  final List<Map<String, dynamic>> items;
  final Set<String> selectedPaths;
  final bool selectionMode;
  final bool recursive;
  final RefreshCallback onRefresh;
  final SubtitleLibrarySelectionToggle onSelectionToggle;
  final ValueChanged<String> onFolderTap;
  final ValueChanged<String> onPreviewFile;
  final ValueChanged<Map<String, dynamic>> onLoadSubtitle;
  final SubtitleLibraryFileOptions onShowOptions;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: _buildRows(context, items, level: 0),
      ),
    );
  }

  List<Widget> _buildRows(
    BuildContext context,
    List<Map<String, dynamic>> currentItems, {
    required int level,
  }) {
    final rows = <Widget>[];

    for (final item in currentItems) {
      final path = item['path'] as String;
      final isFolder = item['type'] == 'folder';

      rows.add(
        _SubtitleLibraryFileRow(
          item: item,
          path: path,
          level: level,
          isFolder: isFolder,
          isSelected: selectedPaths.contains(path),
          selectionMode: selectionMode,
          onTap: () {
            if (selectionMode) {
              onSelectionToggle(path, isFolder, item);
            } else if (isFolder) {
              onFolderTap(path);
            } else {
              onPreviewFile(path);
            }
          },
          onPreviewFile: () => onPreviewFile(path),
          onLoadSubtitle: () => onLoadSubtitle(item),
          onShowOptions: () => onShowOptions(item, path),
        ),
      );

      if (recursive && isFolder && item['children'] != null) {
        rows.addAll(_buildRows(
          context,
          (item['children'] as List).cast<Map<String, dynamic>>(),
          level: level + 1,
        ));
      }
    }

    return rows;
  }
}

class _SubtitleLibraryFileRow extends StatelessWidget {
  const _SubtitleLibraryFileRow({
    required this.item,
    required this.path,
    required this.level,
    required this.isFolder,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onPreviewFile,
    required this.onLoadSubtitle,
    required this.onShowOptions,
  });

  final Map<String, dynamic> item;
  final String path;
  final int level;
  final bool isFolder;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onPreviewFile;
  final VoidCallback onLoadSubtitle;
  final VoidCallback onShowOptions;

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? '').toString();
    final size = item['size'];
    final isLyricFile = !isFolder && FileIconUtils.isLyricFile(title);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0 + (level * 20.0),
          right: 16.0,
          top: 8.0,
          bottom: 8.0,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(
                isFolder ? Icons.folder : Icons.text_snippet,
                color: isFolder ? Colors.amber : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFolder
                        ? localizedSubtitleFolderTitle(context, title)
                        : title,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isFolder && size is int)
                    Text(
                      formatBytes(size),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isLyricFile)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onLoadSubtitle,
                    icon: const Icon(Icons.subtitles),
                    color: Colors.orange,
                    tooltip: S.of(context).loadAsSubtitle,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: onPreviewFile,
                    icon: const Icon(Icons.visibility),
                    color: Colors.blue,
                    tooltip: S.of(context).preview,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              )
            else if (isFolder)
              Text(
                S.of(context).nItems((item['children'] as List?)?.length ?? 0),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 18),
              onPressed: onShowOptions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
