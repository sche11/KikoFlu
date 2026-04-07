class LyricLine {
  final Duration startTime;
  final Duration endTime;
  final String text;

  LyricLine({
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  LyricLine copyWith({
    Duration? startTime,
    Duration? endTime,
    String? text,
  }) {
    return LyricLine(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      text: text ?? this.text,
    );
  }

  /// 应用时间轴偏移
  LyricLine applyOffset(Duration offset) {
    return LyricLine(
      startTime: startTime + offset,
      endTime: endTime + offset,
      text: text,
    );
  }
}

class LyricParser {
  static List<LyricLine> parse(String content) {
    List<LyricLine> result = [];

    // 检测是否是 LRC 格式（包含 [mm:ss.xx] 格式的时间戳）
    if (content.contains(RegExp(r'\[\d{2}:\d{2}\.\d{2}\]'))) {
      result = parseLRC(content);
    }
    // 检测 ASS/SSA 格式（包含 [Events] 区段和 Dialogue: 行）
    else if (content.contains('[Events]') &&
        content.contains(RegExp(r'^Dialogue:', multiLine: true))) {
      result = parseASS(content);
    }
    // 检测 TTML/DFXP 格式（XML 中含 <p begin= 标签）
    else if (content.contains(RegExp(r'<p\s+begin='))) {
      result = parseTTML(content);
    }
    // 检测 SBV 格式（YouTube，H:MM:SS.mmm,H:MM:SS.mmm 逗号分隔的时间对）
    else if (content
        .contains(RegExp(r'^\d+:\d{2}:\d{2}\.\d{3},\d+:\d{2}:\d{2}\.\d{3}', multiLine: true))) {
      result = parseSBV(content);
    }
    // 尝试 WebVTT / SRT 格式
    else {
      result = parseWebVTT(content);
    }

    if (result.isEmpty) {
      throw const FormatException("解析失败，格式不支持");
    }

    return result;
  }

  static List<LyricLine> parseLRC(String content) {
    final lines = content.split('\n');
    final List<LyricLine> lyrics = [];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      if (RegExp(r'^\[[a-z]{2}:').hasMatch(trimmedLine)) {
        continue;
      }

      final timeMatches =
          RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\]').allMatches(trimmedLine);

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

      String text =
          trimmedLine.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2}\]'), '').trim();

      for (final timestamp in timestamps) {
        lyrics.add(LyricLine(
          startTime: timestamp,
          endTime: timestamp,
          text: text,
        ));
      }
    }

    return _finalizeLyrics(lyrics);
  }

  static List<LyricLine> parseWebVTT(String content) {
    final lines = content.split('\n');
    final List<LyricLine> lyrics = [];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty || line.startsWith('WEBVTT') || line == 'NOTE') {
        i++;
        continue;
      }

      final timeMatch = RegExp(
              r'(?:(\d{2}):)?(\d{2}):(\d{2}[.,]\d{3})\s*-->\s*(?:(\d{2}):)?(\d{2}):(\d{2}[.,]\d{3})')
          .firstMatch(line);

      if (timeMatch != null) {
        final startTime = _parseTime(
          int.parse(timeMatch.group(1) ?? '0'),
          int.parse(timeMatch.group(2)!),
          double.parse(timeMatch.group(3)!.replaceAll(',', '.')),
        );

        final endTime = _parseTime(
          int.parse(timeMatch.group(4) ?? '0'),
          int.parse(timeMatch.group(5)!),
          double.parse(timeMatch.group(6)!.replaceAll(',', '.')),
        );

        i++;

        final textLines = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }

        if (textLines.isNotEmpty) {
          lyrics.add(LyricLine(
            startTime: startTime,
            endTime: endTime,
            text: textLines.join('\n'),
          ));
        }
      } else {
        i++;
      }
    }

    return _finalizeLyrics(lyrics);
  }

  /// 解析 ASS/SSA 格式
  /// 格式: Dialogue: Layer,H:MM:SS.cc,H:MM:SS.cc,Style,Name,MarginL,MarginR,MarginV,Effect,Text
  static List<LyricLine> parseASS(String content) {
    final lines = content.split('\n');
    final List<LyricLine> lyrics = [];

    // ASS 时间格式: H:MM:SS.cc (centiseconds)
    final timeRegex = RegExp(r'(\d+):(\d{2}):(\d{2})\.(\d{2})');

    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('Dialogue:')) continue;

      // 找到 Dialogue: 后面的内容，按逗号分割（前9个逗号是字段分隔，第10个字段是文本）
      final afterDialogue = trimmed.substring(trimmed.indexOf(':') + 1).trim();
      final parts = afterDialogue.split(',');
      if (parts.length < 10) continue;

      final startMatch = timeRegex.firstMatch(parts[1].trim());
      final endMatch = timeRegex.firstMatch(parts[2].trim());
      if (startMatch == null || endMatch == null) continue;

      final startTime = _parseASSTime(startMatch);
      final endTime = _parseASSTime(endMatch);

      // 文本是第10个字段之后的所有内容（文本中可能含逗号）
      var text = parts.sublist(9).join(',');

      // 处理 ASS 特殊标记
      text = text
          .replaceAll(RegExp(r'\{[^}]*\}'), '') // 移除 {\\b1} 等内联样式
          .replaceAll('\\N', '\n')               // 换行符
          .replaceAll('\\n', '\n')               // 软换行
          .replaceAll('\\h', ' ')                // 硬空格
          .trim();

      if (text.isEmpty) continue;

      lyrics.add(LyricLine(
        startTime: startTime,
        endTime: endTime,
        text: text,
      ));
    }

    return _finalizeLyrics(lyrics);
  }

  /// 解析 ASS 时间: H:MM:SS.cc → Duration
  static Duration _parseASSTime(RegExpMatch match) {
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final centiseconds = int.parse(match.group(4)!);
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: centiseconds * 10,
    );
  }

  /// 解析 SBV 格式 (YouTube)
  /// 格式:
  /// H:MM:SS.mmm,H:MM:SS.mmm
  /// Text content
  static List<LyricLine> parseSBV(String content) {
    final lines = content.split('\n');
    final List<LyricLine> lyrics = [];

    final timeRegex =
        RegExp(r'(\d+):(\d{2}):(\d{2})\.(\d{3}),(\d+):(\d{2}):(\d{2})\.(\d{3})');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();

      final timeMatch = timeRegex.firstMatch(line);
      if (timeMatch != null) {
        final startTime = Duration(
          hours: int.parse(timeMatch.group(1)!),
          minutes: int.parse(timeMatch.group(2)!),
          seconds: int.parse(timeMatch.group(3)!),
          milliseconds: int.parse(timeMatch.group(4)!),
        );
        final endTime = Duration(
          hours: int.parse(timeMatch.group(5)!),
          minutes: int.parse(timeMatch.group(6)!),
          seconds: int.parse(timeMatch.group(7)!),
          milliseconds: int.parse(timeMatch.group(8)!),
        );

        i++;
        final textLines = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }

        if (textLines.isNotEmpty) {
          lyrics.add(LyricLine(
            startTime: startTime,
            endTime: endTime,
            text: textLines.join('\n'),
          ));
        }
      } else {
        i++;
      }
    }

    return _finalizeLyrics(lyrics);
  }

  /// 解析 TTML/DFXP 格式 (XML)
  /// 格式: <p begin="HH:MM:SS.mmm" end="HH:MM:SS.mmm">Text</p>
  static List<LyricLine> parseTTML(String content) {
    final List<LyricLine> lyrics = [];

    // 匹配 <p begin="..." end="...">...</p>（支持跨行）
    final pRegex = RegExp(
      r'<p\s+begin="([^"]+)"\s+end="([^"]+)"[^>]*>(.*?)</p>',
      dotAll: true,
    );

    // TTML 时间格式: HH:MM:SS.mmm 或 HH:MM:SS:ff
    final timeRegex = RegExp(r'(\d{2}):(\d{2}):(\d{2})[.:](\d{3})');

    for (final match in pRegex.allMatches(content)) {
      final beginStr = match.group(1)!;
      final endStr = match.group(2)!;
      var text = match.group(3)!;

      final startMatch = timeRegex.firstMatch(beginStr);
      final endMatch = timeRegex.firstMatch(endStr);
      if (startMatch == null || endMatch == null) continue;

      final startTime = Duration(
        hours: int.parse(startMatch.group(1)!),
        minutes: int.parse(startMatch.group(2)!),
        seconds: int.parse(startMatch.group(3)!),
        milliseconds: int.parse(startMatch.group(4)!),
      );
      final endTime = Duration(
        hours: int.parse(endMatch.group(1)!),
        minutes: int.parse(endMatch.group(2)!),
        seconds: int.parse(endMatch.group(3)!),
        milliseconds: int.parse(endMatch.group(4)!),
      );

      // 移除 XML/HTML 标签，保留文本
      text = text
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .trim();

      if (text.isEmpty) continue;

      lyrics.add(LyricLine(
        startTime: startTime,
        endTime: endTime,
        text: text,
      ));
    }

    return _finalizeLyrics(lyrics);
  }

  static List<LyricLine> _finalizeLyrics(List<LyricLine> lyrics) {
    if (lyrics.isEmpty) return [];

    lyrics.sort((a, b) => a.startTime.compareTo(b.startTime));

    final List<LyricLine> finalLyrics = [];

    for (int i = 0; i < lyrics.length - 1; i++) {
      // 当前字幕的结束时间直接设置为下一行的开始时间
      finalLyrics.add(LyricLine(
        startTime: lyrics[i].startTime,
        endTime: lyrics[i + 1].startTime,
        text: lyrics[i].text,
      ));
    }

    // 最后一行
    final lastIndex = lyrics.length - 1;
    finalLyrics.add(LyricLine(
      startTime: lyrics[lastIndex].startTime,
      endTime: lyrics[lastIndex].endTime == lyrics[lastIndex].startTime
          ? lyrics[lastIndex].startTime + const Duration(seconds: 5)
          : lyrics[lastIndex].endTime,
      text: lyrics[lastIndex].text,
    ));

    return _mergeEmptyLines(finalLyrics);
  }

  static List<LyricLine> _mergeEmptyLines(List<LyricLine> lyrics) {
    if (lyrics.isEmpty) return [];

    final List<LyricLine> mergedLyrics = [];

    for (final line in lyrics) {
      final isEmpty = line.text.trim().isEmpty;

      if (mergedLyrics.isEmpty) {
        // 第一行特殊处理：如果是长空行（>=3秒）也替换为音符
        if (isEmpty) {
          mergedLyrics.add(line.copyWith(text: '♪ - ♪'));
        } else {
          mergedLyrics.add(line);
        }
        continue;
      }

      final lastLine = mergedLyrics.last;
      final duration = line.endTime - line.startTime;
      final isShort = duration < const Duration(seconds: 3);

      if (isEmpty && isShort) {
        // 合并到上一行：更新上一行的结束时间
        mergedLyrics.removeLast();
        mergedLyrics.add(lastLine.copyWith(endTime: line.endTime));
      } else {
        // 保留的行：如果是空行（说明是长空行），替换为音符
        if (isEmpty) {
          mergedLyrics.add(line.copyWith(text: '♪ - ♪'));
        } else {
          mergedLyrics.add(line);
        }
      }
    }

    return mergedLyrics;
  }

  static Duration _parseTime(int hours, int minutes, double seconds) {
    final totalSeconds = hours * 3600 + minutes * 60 + seconds;
    return Duration(milliseconds: (totalSeconds * 1000).round());
  }

  static String? getCurrentLyric(List<LyricLine> lyrics, Duration position) {
    for (int i = 0; i < lyrics.length; i++) {
      final lyric = lyrics[i];
      if (position >= lyric.startTime && position < lyric.endTime) {
        return lyric.text;
      }
      if (i < lyrics.length - 1) {
        final nextLyric = lyrics[i + 1];
        if (position >= lyric.endTime && position < nextLyric.startTime) {
          final gap = nextLyric.startTime - lyric.endTime;
          return gap < const Duration(seconds: 1) ? lyric.text : null;
        }
      }
    }
    return null;
  }
}
