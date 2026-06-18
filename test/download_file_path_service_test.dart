import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/download_file_path_service.dart';

Map<String, dynamic> fileItem(
  String title, {
  String? type,
  String? hash,
}) {
  return {
    'type': type ?? 'file',
    'title': title,
    if (hash != null) 'hash': hash,
  };
}

Map<String, dynamic> folderItem(
  String title,
  List<dynamic> children,
) {
  return {
    'type': 'folder',
    'title': title,
    'children': children,
  };
}

void main() {
  group('DownloadFilePathService', () {
    test('sanitizes path separators and platform-reserved characters', () {
      expect(
        DownloadFilePathService.safeRelativePath(
          r' Disc: 1 / CON / a<b>c?.mp3 ',
        ),
        'Disc_ 1/_CON/a_b_c_.mp3',
      );
      expect(DownloadFilePathService.safeRelativePath('../..'), 'download');
      expect(DownloadFilePathService.safeRelativePath('aux.txt'), '_aux.txt');
    });

    test('truncates long path segments while keeping extensions', () {
      final safe = DownloadFilePathService.safePathSegment(
        '${'很长' * 60}.flac',
      );

      expect(safe.length, lessThanOrEqualTo(80));
      expect(safe.endsWith('.flac'), isTrue);
    });

    test('annotates file tree with safe local paths and deduplicates clashes',
        () {
      final annotated = DownloadFilePathService.annotateFileTreeWithLocalPaths([
        folderItem('Disc:1', [
          fileItem('track?.mp3', hash: 'a'),
          fileItem('track*.mp3', hash: 'b'),
        ]),
      ]);

      final folder = annotated.single as Map<String, dynamic>;
      final children = folder['children'] as List<dynamic>;

      expect(folder['title'], 'Disc:1');
      expect(folder['localRelativePath'], 'Disc_1');
      expect(children.first['title'], 'track?.mp3');
      expect(children.first['localRelativePath'], 'Disc_1/track_.mp3');
      expect(children.last['localRelativePath'], 'Disc_1/track_ (2).mp3');
      expect(
        DownloadFilePathService.localRelativePathsByHash(annotated),
        {
          'a': 'Disc_1/track_.mp3',
          'b': 'Disc_1/track_ (2).mp3',
        },
      );
    });
  });
}
