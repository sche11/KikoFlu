import 'dart:io';

import 'package:path/path.dart' as p;

import 'download_file_path_service.dart';
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
    final knownRelativePaths = <String>{};
    final files = await _filterItems(
      fileTree,
      workDirPath,
      '',
      existingFiles,
      knownRelativePaths,
    );
    await _mergeDiscoveredDirectory(
      targetItems: files,
      directoryPath: workDirPath,
      parentPath: '',
      knownRelativePaths: knownRelativePaths,
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
    Set<String> knownRelativePaths,
  ) async {
    final filteredItems = <dynamic>[];

    for (final item in items) {
      if (FileTreeUtils.isFolder(item)) {
        final folder = await _filterFolder(
          item,
          workDirPath,
          parentPath,
          existingFiles,
          knownRelativePaths,
        );
        if (folder != null) filteredItems.add(folder);
        continue;
      }

      final file = await _filterFile(
        item,
        workDirPath,
        parentPath,
        existingFiles,
        knownRelativePaths,
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
    Set<String> knownRelativePaths,
  ) async {
    final children = FileTreeUtils.childrenOf(item);
    if (children == null || children.isEmpty) return null;

    final title = FileTreeUtils.titleOf(item, defaultValue: 'unknown');
    final folderPath =
        DownloadFilePathService.localRelativePathForItem(item, parentPath);
    final filteredChildren = await _filterItems(
      children,
      workDirPath,
      folderPath,
      existingFiles,
      knownRelativePaths,
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
    Set<String> knownRelativePaths,
  ) async {
    final hash = FileTreeUtils.property(item, 'hash')?.toString();
    if (hash == null) return null;

    final title = FileTreeUtils.titleOf(item, defaultValue: 'unknown');
    final relativePath =
        DownloadFilePathService.localRelativePathForItem(item, parentPath);
    final filePath = p.join(workDirPath, relativePath);

    final exists = await fileExists(filePath);
    final isDownloading = await fileExists('$filePath.downloading');
    if (!exists || isDownloading) return null;

    knownRelativePaths.add(_normalizeRelativePath(relativePath));
    existingFiles[hash] = true;
    final fileType = _normalizedType(item, title);

    if (item is Map<String, dynamic>) {
      if (item['type'] == fileType && item['localPath'] == filePath) {
        return item;
      }

      return Map<String, dynamic>.from(item)
        ..['type'] = fileType
        ..['localPath'] = filePath
        ..['relativePath'] = _normalizeRelativePath(relativePath);
    }

    return <String, dynamic>{
      'type': fileType,
      'title': title,
      'hash': hash,
      'localPath': filePath,
      'relativePath': _normalizeRelativePath(relativePath),
      'duration': FileTreeUtils.property(item, 'duration'),
      'size': FileTreeUtils.property(item, 'size'),
    };
  }

  Future<void> _mergeDiscoveredDirectory({
    required List<dynamic> targetItems,
    required String directoryPath,
    required String parentPath,
    required Set<String> knownRelativePaths,
  }) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return;

    final entities = <FileSystemEntity>[];
    await for (final entity in directory.list(followLinks: false)) {
      entities.add(entity);
    }
    entities.sort(
      (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
    );

    for (final entity in entities) {
      final title = p.basename(entity.path);
      final relativePath = parentPath.isEmpty ? title : '$parentPath/$title';
      final normalizedRelativePath = _normalizeRelativePath(relativePath);

      if (_shouldSkipDiscoveredEntity(title, normalizedRelativePath)) {
        continue;
      }

      if (entity is Directory) {
        final existingFolder = _findFolder(targetItems, title);
        final children = existingFolder == null
            ? <dynamic>[]
            : List<dynamic>.from(
                FileTreeUtils.childrenOf(existingFolder) ?? const [],
              );

        await _mergeDiscoveredDirectory(
          targetItems: children,
          directoryPath: entity.path,
          parentPath: normalizedRelativePath,
          knownRelativePaths: knownRelativePaths,
        );

        if (children.isEmpty) continue;

        if (existingFolder is Map<String, dynamic>) {
          existingFolder['children'] = children;
        } else if (existingFolder == null) {
          targetItems.add({
            'type': 'folder',
            'title': title,
            'children': children,
          });
        }
        continue;
      }

      if (entity is! File) continue;
      if (await fileExists('${entity.path}.downloading')) continue;
      if (!knownRelativePaths.add(normalizedRelativePath)) continue;

      final size = await entity.length();
      targetItems.add({
        'type': FileIconUtils.inferFileType(title),
        'title': title,
        'hash': 'local:$normalizedRelativePath',
        'path': entity.path,
        'localPath': entity.path,
        'relativePath': normalizedRelativePath,
        'size': size,
      });
    }
  }

  dynamic _findFolder(List<dynamic> items, String title) {
    for (final item in items) {
      if (FileTreeUtils.isFolder(item) &&
          FileTreeUtils.titleOf(item) == title) {
        return item;
      }
    }
    return null;
  }

  bool _shouldSkipDiscoveredEntity(String title, String relativePath) {
    if (title.startsWith('.')) return true;
    if (title.endsWith('.downloading')) return true;
    if (relativePath == 'work_metadata.json') return true;
    if (relativePath == 'cover.jpg') return true;
    return false;
  }

  String _normalizeRelativePath(String relativePath) {
    return relativePath.replaceAll('\\', '/');
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
