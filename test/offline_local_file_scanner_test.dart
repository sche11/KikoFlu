import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/offline_local_file_scanner.dart';

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

class _ObjectFile {
  const _ObjectFile({
    required this.type,
    required this.title,
    this.hash,
    this.children,
    this.duration,
    this.size,
  });

  final String type;
  final String title;
  final String? hash;
  final List<dynamic>? children;
  final int? duration;
  final int? size;
}

void main() {
  group('OfflineLocalFileScanner', () {
    test('keeps only existing completed files and prunes empty folders',
        () async {
      final existingPaths = {
        '/downloads/123/Disc 1/track01.mp3',
        '/downloads/123/Disc 1/cover.jpg',
        '/downloads/123/Disc 1/cover.jpg.downloading',
      };
      final track = fileItem('track01.mp3', hash: 'track');
      final tree = [
        folderItem('Disc 1', [
          track,
          fileItem('cover.jpg', hash: 'cover'),
          fileItem('notes.txt', hash: 'notes'),
          fileItem('hashless.mp3'),
        ]),
        folderItem('Empty', [
          fileItem('missing.mp3', hash: 'missing'),
        ]),
      ];
      final scanner = OfflineLocalFileScanner(
        fileExists: (path) async => existingPaths.contains(path),
      );

      final result = await scanner.scan(
        fileTree: tree,
        workDirPath: '/downloads/123',
      );

      expect(result.fileExists, {'track': true});
      expect(result.files, hasLength(1));

      final folder = result.files.single as Map<String, dynamic>;
      expect(folder['title'], 'Disc 1');

      final children = folder['children'] as List<dynamic>;
      expect(children, hasLength(1));
      expect(children.single, {
        'type': 'audio',
        'title': 'track01.mp3',
        'hash': 'track',
      });
      expect(track['type'], 'file');
    });

    test('preserves specific metadata type when extension is generic',
        () async {
      final scanner = OfflineLocalFileScanner(
        fileExists: (path) async => path == '/downloads/123/video.bin',
      );

      final result = await scanner.scan(
        fileTree: [
          fileItem('video.bin', type: 'video', hash: 'video'),
        ],
        workDirPath: '/downloads/123',
      );

      expect(result.files.single, {
        'type': 'video',
        'title': 'video.bin',
        'hash': 'video',
      });
    });

    test('converts object-backed file tree items to maps', () async {
      final scanner = OfflineLocalFileScanner(
        fileExists: (path) async => path == '/downloads/123/Disc/script.pdf',
      );

      final result = await scanner.scan(
        fileTree: const [
          _ObjectFile(
            type: 'folder',
            title: 'Disc',
            children: [
              _ObjectFile(
                type: 'file',
                title: 'script.pdf',
                hash: 'pdf',
                duration: 12,
                size: 2048,
              ),
            ],
          ),
        ],
        workDirPath: '/downloads/123',
      );

      expect(result.files, [
        {
          'type': 'folder',
          'title': 'Disc',
          'children': [
            {
              'type': 'pdf',
              'title': 'script.pdf',
              'hash': 'pdf',
              'duration': 12,
              'size': 2048,
            },
          ],
        },
      ]);
    });
  });
}
