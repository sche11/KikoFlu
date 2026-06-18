import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/file_delete_request_builder.dart';

void main() {
  group('FileDeleteRequestBuilder', () {
    test('builds title and relative path for nested files', () {
      const builder = FileDeleteRequestBuilder();

      final request = builder.build(
        file: const {
          'type': 'audio',
          'title': 'track01.mp3',
          'hash': 'audio',
        },
        parentPath: 'Disc 1',
        unknownTitle: 'unknown',
      );

      expect(request.title, 'track01.mp3');
      expect(request.relativePath, 'Disc 1/track01.mp3');
    });

    test('uses unknown title fallback for hash-only files', () {
      const builder = FileDeleteRequestBuilder();

      final request = builder.build(
        file: const {
          'type': 'file',
          'hash': 'missing-title',
        },
        parentPath: '',
        unknownTitle: 'unknown file',
      );

      expect(request.title, 'unknown file');
      expect(request.relativePath, 'unknown file');
    });
  });
}
