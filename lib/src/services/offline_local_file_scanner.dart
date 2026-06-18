import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/file_icon_utils.dart';
import '../utils/file_tree_utils.dart';

typedef OfflineFileExists = Future<bool> Function(String path);

class OfflineLocalFileScanResult {
  const OfflineLocalFileScanResult({
    required this.files,
    required this.fileExists,
  });

  final List<dynamic> files;
  final Map<String, bool> fileExists;
}

class OfflineLocalFileScanner {
  const OfflineLocalFileScanner({
    this.fileExists = _defaultFileExists,
  });

  final OfflineFileExists fileExists;

  Future<OfflineLocalFileScanResult> scan({
    required List<dynamic> fileTree,
    required String workDirPath,
  }) async {
    final existingFiles = <String, bool>{};
    final files = await _filterItems(
      fileTree,
      workDirPath,
      '',
      existingFiles,
    );

    return OfflineLocalFileScanResult(
      files: files,
      fileExists: existingFiles,
    );
  }

  Future<List<dynamic>> _filterItems(
    List<dynamic> items,
    String workDirPath,
    String parentPath,
    Map<String, bool> existingFiles,
  ) async {
    final filteredItems = <dynamic>[];

    for (final item in items) {
      if (FileTreeUtils.isFolder(item)) {
        final folder = await _filterFolder(
          item,
          workDirPath,
          parentPath,
          existingFiles,
        );
        if (folder != null) filteredItems.add(folder);
        continue;
      }

      final file = await _filterFile(
        item,
        workDirPath,
        parentPath,
        existingFiles,
      );
      if (file != null) filteredItems.add(file);
    }

    return filteredItems;
  }

  Future<dynamic> _filterFolder(
    dynamic item,
    String workDirPath,
    String parentPath,
    Map<String, bool> existingFiles,
  ) async {
    final children = FileTreeUtils.childrenOf(item);
    if (children == null || children.isEmpty) return null;

    final title = FileTreeUtils.titleOf(item, defaultValue: 'unknown');
    final folderPath = parentPath.isEmpty ? title : '$parentPath/$title';
    final filteredChildren = await _filterItems(
      children,
      workDirPath,
      folderPath,
      existingFiles,
    );

    if (filteredChildren.isEmpty) return null;

    if (item is Map<String, dynamic>) {
      return Map<String, dynamic>.from(item)..['children'] = filteredChildren;
    }

    return <String, dynamic>{
      'type': 'folder',
      'title': title,
      'children': filteredChildren,
    };
  }

  Future<dynamic> _filterFile(
    dynamic item,
    String workDirPath,
    String parentPath,
    Map<String, bool> existingFiles,
  ) async {
    final hash = FileTreeUtils.property(item, 'hash')?.toString();
    if (hash == null) return null;

    final title = FileTreeUtils.titleOf(item, defaultValue: 'unknown');
    final relativePath = parentPath.isEmpty ? title : '$parentPath/$title';
    final filePath = p.join(workDirPath, relativePath);

    final exists = await fileExists(filePath);
    final isDownloading = await fileExists('$filePath.downloading');
    if (!exists || isDownloading) return null;

    existingFiles[hash] = true;
    final fileType = _normalizedType(item, title);

    if (item is Map<String, dynamic>) {
      if (item['type'] == fileType) return item;

      return Map<String, dynamic>.from(item)..['type'] = fileType;
    }

    return <String, dynamic>{
      'type': fileType,
      'title': title,
      'hash': hash,
      'duration': FileTreeUtils.property(item, 'duration'),
      'size': FileTreeUtils.property(item, 'size'),
    };
  }

  static String _normalizedType(dynamic item, String title) {
    final type = FileTreeUtils.typeOf(item);
    if (type != 'file' && type.isNotEmpty) return type;

    return FileIconUtils.inferFileType(title);
  }

  static Future<bool> _defaultFileExists(String path) {
    return File(path).exists();
  }
}
