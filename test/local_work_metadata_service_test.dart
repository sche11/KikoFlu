import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/local_work_metadata_service.dart';

void main() {
  group('LocalWorkMetadataService', () {
    test('parses numeric and RJ style work folders', () {
      expect(LocalWorkMetadataService.parseWorkIdFromName('123456'), 123456);
      expect(LocalWorkMetadataService.parseWorkIdFromName('RJ395908'), 395908);
      expect(
        LocalWorkMetadataService.parseWorkIdFromName(
          '[みやぢ屋][RJ334212]ガチ恋不可避',
        ),
        334212,
      );
      expect(LocalWorkMetadataService.parseWorkIdFromName('notes'), isNull);
    });

    test('builds fallback metadata from a local RJ work folder', () async {
      final tempDir = await Directory.systemTemp.createTemp('kikoflu_local_');
      addTearDown(() => tempDir.delete(recursive: true));

      final workDir = Directory(
        '${tempDir.path}/[みやぢ屋][RJ334212]ガチ恋不可避',
      );
      await Directory('${workDir.path}/Disc 1').create(recursive: true);
      await File('${workDir.path}/cover.png').writeAsBytes([1, 2, 3]);
      await File('${workDir.path}/Disc 1/track01.mp3').writeAsBytes([1, 2]);
      await File('${workDir.path}/Disc 1/track01.lrc').writeAsString('lyric');
      await File('${workDir.path}/work_metadata.json').writeAsString('{}');
      await File('${workDir.path}/.hidden.mp3').writeAsBytes([0]);

      final service = LocalWorkMetadataService(
        fileLength: (file) async => file.length(),
      );
      final folder = service.parseWorkFolder(workDir);
      final metadata = await service.buildFallbackMetadata(
        workId: folder!.id,
        workDir: workDir,
        directoryName: folder.directoryName,
      );

      expect(folder.id, 334212);
      expect(metadata['id'], 334212);
      expect(metadata['title'], 'ガチ恋不可避');
      expect(metadata['source_id'], 'RJ334212');
      expect(
        metadata['source_url'],
        'https://www.dlsite.com/maniax/work/=/product_id/RJ334212.html',
      );
      expect(metadata['localWorkDirName'], folder.directoryName);
      expect(metadata['localCoverPath'], 'cover.png');

      final children = metadata['children'] as List<dynamic>;
      expect(children, hasLength(1));
      expect(children.single, {
        'type': 'folder',
        'title': 'Disc 1',
        'localRelativePath': 'Disc 1',
        'children': [
          {
            'type': 'text',
            'title': 'track01.lrc',
            'hash': 'local:Disc 1/track01.lrc',
            'localRelativePath': 'Disc 1/track01.lrc',
            'relativePath': 'Disc 1/track01.lrc',
            'size': 5,
          },
          {
            'type': 'audio',
            'title': 'track01.mp3',
            'hash': 'local:Disc 1/track01.mp3',
            'localRelativePath': 'Disc 1/track01.mp3',
            'relativePath': 'Disc 1/track01.mp3',
            'size': 2,
          },
        ],
      });
    });

    test('preserves existing metadata while filling local fields', () async {
      final tempDir = await Directory.systemTemp.createTemp('kikoflu_local_');
      addTearDown(() => tempDir.delete(recursive: true));

      final workDir = Directory('${tempDir.path}/RJ395908');
      await workDir.create(recursive: true);
      await File('${workDir.path}/folder.webp').writeAsBytes([1]);
      await File('${workDir.path}/track.wav').writeAsBytes([1, 2, 3]);

      final metadata =
          await const LocalWorkMetadataService().buildFallbackMetadata(
        workId: 395908,
        workDir: workDir,
        directoryName: 'RJ395908',
        existingMetadata: const {
          'title': 'Existing title',
          'source_id': 'custom',
          'source_url': 'https://example.test/work',
        },
      );

      expect(metadata['title'], 'Existing title');
      expect(metadata['source_id'], 'custom');
      expect(metadata['source_url'], 'https://example.test/work');
      expect(metadata['localWorkDirName'], 'RJ395908');
      expect(metadata['localCoverPath'], 'folder.webp');
      expect(metadata['children'], [
        {
          'type': 'audio',
          'title': 'track.wav',
          'hash': 'local:track.wav',
          'localRelativePath': 'track.wav',
          'relativePath': 'track.wav',
          'size': 3,
        },
      ]);
    });
  });
}
