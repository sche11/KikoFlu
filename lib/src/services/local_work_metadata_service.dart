import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/file_icon_utils.dart';
import '../utils/string_utils.dart';
import 'download_file_path_service.dart';

class LocalWorkFolder {
  const LocalWorkFolder({
    required this.id,
    required this.directory,
    required this.directoryName,
  });

  final int id;
  final Directory directory;
  final String directoryName;
}

class LocalWorkMetadataService {
  const LocalWorkMetadataService({
    this.fileLength = _defaultFileLength,
  });

  static const String metadataFileName = 'work_metadata.json';
  static const String localWorkDirNameKey = 'localWorkDirName';

  static const Set<String> reservedFileNames = {
    metadataFileName,
    'cover.jpg',
  };

  static final RegExp _rjPattern = RegExp(r'RJ(\d{5,8})', caseSensitive: false);
  static final RegExp _numericFolderPattern = RegExp(r'^\d+$');

  static const List<String> _coverBaseNames = [
    'cover',
    'folder',
    'front',
    'main',
    'poster',
    'thumbnail',
  ];

  static const Set<String> _coverExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  final Future<int?> Function(File file) fileLength;

  LocalWorkFolder? parseWorkFolder(Directory directory) {
    final directoryName = p.basename(directory.path);
    final workId = parseWorkIdFromName(directoryName);
    if (workId == null) return null;

    return LocalWorkFolder(
      id: workId,
      directory: directory,
      directoryName: directoryName,
    );
  }

  static int? parseWorkIdFromName(String name) {
    final rjMatch = _rjPattern.firstMatch(name);
    if (rjMatch != null) {
      return int.tryParse(rjMatch.group(1)!);
    }

    final trimmed = name.trim();
    if (_numericFolderPattern.hasMatch(trimmed)) {
      final parsed = int.tryParse(trimmed);
      return parsed != null && parsed > 0 ? parsed : null;
    }

    return null;
  }

  Future<Map<String, dynamic>> buildFallbackMetadata({
    required int workId,
    required Directory workDir,
    required String directoryName,
    Map<String, dynamic>? existingMetadata,
  }) async {
    final metadata = existingMetadata == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existingMetadata);

    metadata['id'] = _asPositiveInt(metadata['id']) ?? workId;
    metadata['title'] = _cleanString(metadata['title']) ??
        _titleFromDirectoryName(directoryName, workId);
    metadata['source_id'] =
        _cleanString(metadata['source_id']) ?? formatRJCode(workId);
    metadata['source_url'] = _cleanString(metadata['source_url']) ??
        'https://www.dlsite.com/maniax/work/=/product_id/${formatRJCode(workId)}.html';
    metadata[localWorkDirNameKey] = directoryName;

    metadata['children'] = await buildFileTree(workDir);

    final localCoverPath = await detectCoverRelativePath(
      workDir,
      metadata['localCoverPath'],
    );
    if (localCoverPath != null) {
      metadata['localCoverPath'] = localCoverPath;
    }

    return metadata;
  }

  Future<List<dynamic>> buildFileTree(Directory workDir) async {
    return _buildDirectoryChildren(
      directory: workDir,
      parentRelativePath: '',
    );
  }

  Future<String?> detectCoverRelativePath(
    Directory workDir, [
    dynamic existingCoverPath,
  ]) async {
    if (existingCoverPath is String && existingCoverPath.trim().isNotEmpty) {
      final normalized =
          DownloadFilePathService.normalizeRelativePath(existingCoverPath);
      if (normalized.isNotEmpty) {
        final coverPath = DownloadFilePathService.localPathForRelativePath(
          rootPath: workDir.path,
          relativePath: normalized,
        );
        if (await File(coverPath).exists()) return normalized;
      }
    }

    final candidates = <_CoverCandidate>[];
    await for (final entity in workDir.list(followLinks: false)) {
      if (entity is! File) continue;

      final fileName = p.basename(entity.path);
      final extension = p.extension(fileName).toLowerCase();
      if (!_coverExtensions.contains(extension)) continue;

      final baseName = p.basenameWithoutExtension(fileName).toLowerCase();
      final priority = _coverBaseNames.indexOf(baseName);
      if (priority == -1) continue;

      candidates.add(_CoverCandidate(
        relativePath: fileName,
        priority: priority,
      ));
    }

    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => a.priority != b.priority
          ? a.priority.compareTo(b.priority)
          : a.relativePath.compareTo(b.relativePath),
    );
    return candidates.first.relativePath;
  }

  Future<List<dynamic>> _buildDirectoryChildren({
    required Directory directory,
    required String parentRelativePath,
  }) async {
    final entities = <FileSystemEntity>[];
    await for (final entity in directory.list(followLinks: false)) {
      entities.add(entity);
    }
    entities.sort(
      (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
    );

    final children = <dynamic>[];
    for (final entity in entities) {
      final title = p.basename(entity.path);
      final relativePath =
          parentRelativePath.isEmpty ? title : '$parentRelativePath/$title';
      final normalizedRelativePath =
          DownloadFilePathService.normalizeRelativePath(relativePath);

      if (_shouldSkipEntity(title, normalizedRelativePath)) continue;

      if (entity is Directory) {
        final nested = await _buildDirectoryChildren(
          directory: entity,
          parentRelativePath: normalizedRelativePath,
        );
        if (nested.isEmpty) continue;
        children.add({
          'type': 'folder',
          'title': title,
          'localRelativePath': normalizedRelativePath,
          'children': nested,
        });
        continue;
      }

      if (entity is! File) continue;
      if (await File('${entity.path}.downloading').exists()) continue;

      final size = await fileLength(entity);
      children.add({
        'type': FileIconUtils.inferFileType(title),
        'title': title,
        'hash': 'local:$normalizedRelativePath',
        'localRelativePath': normalizedRelativePath,
        'relativePath': normalizedRelativePath,
        if (size != null && size > 0) 'size': size,
      });
    }

    return children;
  }

  static bool shouldSkipMetadataFile(String title, {bool isRoot = false}) {
    if (title.startsWith('.')) return true;
    if (title.endsWith('.downloading')) return true;
    if (title == metadataFileName) return true;
    if (isRoot && reservedFileNames.contains(title)) return true;
    if (isRoot && _isCoverFileName(title)) return true;
    return false;
  }

  bool _shouldSkipEntity(String title, String relativePath) {
    return shouldSkipMetadataFile(
      title,
      isRoot: !relativePath.contains('/'),
    );
  }

  static bool _isCoverFileName(String title) {
    final extension = p.extension(title).toLowerCase();
    if (!_coverExtensions.contains(extension)) return false;

    final baseName = p.basenameWithoutExtension(title).toLowerCase();
    return _coverBaseNames.contains(baseName);
  }

  static String _titleFromDirectoryName(String directoryName, int workId) {
    final normalizedId = formatRJCode(workId);
    var title = directoryName.trim();
    if (title.isEmpty ||
        title == workId.toString() ||
        title.toUpperCase() == normalizedId) {
      return normalizedId;
    }

    title = title.replaceFirst(
      RegExp(
        r'[\[【(（][^\]】)）]*RJ\d{5,8}[^\]】)）]*[\]】)）]',
        caseSensitive: false,
      ),
      ' ',
    );
    title = title.replaceFirst(_rjPattern, ' ');
    title = title.replaceFirst(
      RegExp(r'^[\s\-_~]*[\[【(（][^\]】)）]+[\]】)）]'),
      ' ',
    );
    title = title.replaceAll(RegExp(r'^[\s\-_~\[\]【】（）()]+'), '');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    return title.isEmpty ? normalizedId : title;
  }

  static String? _cleanString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _asPositiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static Future<int?> _defaultFileLength(File file) async {
    try {
      return file.length();
    } catch (_) {
      return null;
    }
  }
}

class _CoverCandidate {
  const _CoverCandidate({
    required this.relativePath,
    required this.priority,
  });

  final String relativePath;
  final int priority;
}
