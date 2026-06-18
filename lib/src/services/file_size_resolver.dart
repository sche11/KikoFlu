import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/file_tree_utils.dart';

typedef FileSizeDownloadRootProvider = Future<String> Function();
typedef FileSizeLengthReader = Future<int?> Function(String path);

class FileSizeResolver {
  const FileSizeResolver({
    required this.downloadRootPath,
    this.fileLength = _defaultFileLength,
  });

  final FileSizeDownloadRootProvider downloadRootPath;
  final FileSizeLengthReader fileLength;

  Future<int?> resolveOffline({
    required dynamic item,
    required int workId,
    required String parentPath,
  }) async {
    final metaSize = FileTreeUtils.property(item, 'size');
    if (metaSize is int && metaSize > 0) {
      return metaSize;
    }

    final title = FileTreeUtils.titleOf(item);
    if (title.isEmpty) return null;

    try {
      final rootPath = await downloadRootPath();
      final filePathParts = [
        rootPath,
        workId.toString(),
        if (parentPath.isNotEmpty) parentPath,
        title,
      ];
      final filePath = p.joinAll(filePathParts);

      return await fileLength(filePath);
    } catch (_) {
      return null;
    }
  }

  static String formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';

    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    if (unitIndex == 0) {
      return '$bytes B';
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  static Future<int?> _defaultFileLength(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    return file.length();
  }
}
