import '../lyric_line.dart';
import '../lyric_parser_support.dart';

class LrcLyricParser {
  const LrcLyricParser._();

  static final RegExp formatPattern = RegExp(r'\[\d{2}:\d{2}\.\d{2}\]');
  static final RegExp metadataPattern = RegExp(r'^\[[a-z]{2}:');
  static final RegExp timestampPattern =
      RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\]');

  static bool matches(String content) {
    return content.contains(formatPattern);
  }

  static List<LyricLine> parse(String content) {
    final lines = content.split('\n');
    final List<LyricLine> lyrics = [];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      if (metadataPattern.hasMatch(trimmedLine)) {
        continue;
      }

      final timeMatches = timestampPattern.allMatches(trimmedLine);

      if (timeMatches.isEmpty) continue;

      final timestamps = <Duration>[];
      for (final match in timeMatches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        timestamps.add(Duration(
          milliseconds:
              minutes * 60 * 1000 + seconds * 1000 + centiseconds * 10,
        ));
      }

      final text = trimmedLine.replaceAll(timestampPattern, '').trim();

      for (final timestamp in timestamps) {
        lyrics.add(LyricLine(
          startTime: timestamp,
          endTime: timestamp,
          text: text,
        ));
      }
    }

    return LyricParserSupport.finalizeLyrics(lyrics);
  }
}
