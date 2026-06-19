import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/audio_track.dart';
import 'audio_haptic_pattern.dart';
import 'log_service.dart';

final _hapticsLog = LogService.instance;

typedef AudioHapticsPositionProvider = Duration Function();
typedef AudioHapticsPlayingProvider = bool Function();

class AudioHapticsService {
  AudioHapticsService({
    MethodChannel? channel,
    AudioHapticPatternGenerator patternGenerator =
        const AudioHapticPatternGenerator(),
    AudioHapticsPositionProvider? positionProvider,
    AudioHapticsPlayingProvider? playingProvider,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _patternGenerator = patternGenerator,
        _positionProvider = positionProvider,
        _playingProvider = playingProvider {
    _channel.setMethodCallHandler(_handlePlatformCall);
  }

  static final AudioHapticsService instance = AudioHapticsService();
  static const String _channelName = 'com.meteor.kikoeruflutter/audio_haptics';

  final MethodChannel _channel;
  final AudioHapticPatternGenerator _patternGenerator;
  AudioHapticsPositionProvider? _positionProvider;
  AudioHapticsPlayingProvider? _playingProvider;

  bool _enabled = false;
  double _intensity = 0.85;
  AudioTrack? _track;
  List<AudioHapticEvent> _events = const [];
  Timer? _timer;
  int _nextEventIndex = 0;
  int _analysisGeneration = 0;
  StreamingAudioHapticPatternGenerator? _streamingPatternGenerator;
  String? _activeStreamSource;
  String? _activeStreamFinalSource;
  bool _activeStreamSourceIsGrowing = false;
  bool _loggedFirstStreamingChunk = false;
  bool _loggedNoEventChunk = false;
  bool _loggedFirstStreamingEventBatch = false;
  bool _platformPulseFailureLogged = false;
  bool _timerStartLogged = false;

  bool get enabled => _enabled;
  bool get _supportsPlatform => Platform.isIOS || Platform.isAndroid;

  void attachPlaybackState({
    required AudioHapticsPositionProvider positionProvider,
    required AudioHapticsPlayingProvider playingProvider,
  }) {
    _positionProvider = positionProvider;
    _playingProvider = playingProvider;
  }

  Future<void> updateSettings({
    required bool enabled,
    required double intensity,
  }) async {
    final previousEnabled = _enabled;
    final previousIntensity = _intensity;
    _enabled = enabled && _supportsPlatform;
    _intensity = intensity.clamp(0.2, 1.0);

    if (previousEnabled != _enabled ||
        (previousIntensity - _intensity).abs() > 0.001 ||
        enabled != _enabled) {
      _hapticsLog.info(
        '设置更新: requested=$enabled, effective=$_enabled, '
        'supported=$_supportsPlatform, intensity=${_intensity.toStringAsFixed(2)}, '
        'platform=${Platform.operatingSystem}',
        tag: 'AudioHaptics',
      );
    }

    if (!_enabled) {
      await stop(clearSource: false);
      return;
    }

    final streamSource = _activeStreamSource;
    final currentTrack = _track;
    if (currentTrack != null && streamSource != null) {
      unawaited(startStreamingAnalysis(
        track: currentTrack,
        source: streamSource,
        finalSource: _activeStreamFinalSource,
        growingFile: _activeStreamSourceIsGrowing,
        startPosition: _positionProvider?.call() ?? Duration.zero,
      ));
    }
  }

  Future<void> prepareForTrack(AudioTrack track) async {
    _track = track;
    _events = const [];
    _nextEventIndex = 0;
    _analysisGeneration++;
    _activeStreamSource = null;
    _activeStreamFinalSource = null;
    _activeStreamSourceIsGrowing = false;
    _streamingPatternGenerator = null;
    _resetDiagnosticsForNewAnalysis();

    if (!_enabled) return;

    final path = _localPathFromTrack(track);
    if (path == null) {
      _hapticsLog.captureOutput(
        '[AudioHaptics] 跳过非本地音频，暂不做实时流分析: ${track.title}',
      );
      return;
    }

    final generation = _analysisGeneration;

    try {
      _hapticsLog.info(
        '开始完整文件分析: title="${track.title}", path=${_shortPath(path)}, '
        'file=${await _fileState(path)}',
        tag: 'AudioHaptics',
      );
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'analyze',
        {
          'path': path,
          'frameMs': AudioHapticPatternGenerator.defaultFrameMs,
          'maxDurationMs': 3 * 60 * 60 * 1000,
        },
      );
      if (generation != _analysisGeneration || raw == null) return;

      final analysis = AudioHapticAnalysis.fromPlatform(raw);
      _events = _patternGenerator.generate(
        analysis,
        userIntensity: _intensity,
      );
      _nextEventIndex = _indexForPosition(
        _positionProvider?.call() ?? Duration.zero,
      );
      _hapticsLog.info(
        '完整分析完成: title="${track.title}", frames=${analysis.energies.length}, '
        'events=${_events.length}, startIndex=$_nextEventIndex',
        tag: 'AudioHaptics',
      );
      if (_playingProvider?.call() ?? false) {
        start();
      }
    } catch (e) {
      if (generation != _analysisGeneration) return;
      _events = const [];
      _hapticsLog.captureOutput('[AudioHaptics] 音频分析失败: $e');
    }
  }

  Future<void> startStreamingAnalysis({
    required AudioTrack track,
    required String source,
    String? finalSource,
    bool growingFile = false,
    Duration startPosition = Duration.zero,
  }) async {
    _track = track;
    _events = const [];
    _nextEventIndex = 0;
    _analysisGeneration++;
    _activeStreamSource = source;
    _activeStreamFinalSource = finalSource;
    _activeStreamSourceIsGrowing = growingFile;
    _resetDiagnosticsForNewAnalysis();
    _streamingPatternGenerator = StreamingAudioHapticPatternGenerator(
      frameMs: AudioHapticPatternGenerator.defaultFrameMs,
      userIntensity: _intensity,
      initialFrameIndex: startPosition.inMilliseconds ~/
          AudioHapticPatternGenerator.defaultFrameMs,
    );

    if (!_enabled) return;

    final generation = _analysisGeneration;
    final method =
        growingFile ? 'startGrowingFileAnalysis' : 'startFileStreamAnalysis';
    try {
      _hapticsLog.info(
        '准备流式分析: title="${track.title}", method=$method, '
        'source=${_shortPath(source)}, sourceFile=${await _fileState(source)}, '
        'finalSource=${_shortPath(finalSource)}, '
        'finalFile=${finalSource == null ? 'none' : await _fileState(finalSource)}, '
        'start=${startPosition.inMilliseconds}ms',
        tag: 'AudioHaptics',
      );
      await _channel.invokeMethod<void>(method, {
        'path': source,
        if (finalSource != null) 'finalPath': finalSource,
        'frameMs': AudioHapticPatternGenerator.defaultFrameMs,
        'maxDurationMs': 3 * 60 * 60 * 1000,
        'startPositionMs': startPosition.inMilliseconds,
        'analysisToken': generation,
      });
      if (generation == _analysisGeneration) {
        _hapticsLog.info(
          '已启动流式分析: title="${track.title}", token=$generation',
          tag: 'AudioHaptics',
        );
      }
    } catch (e) {
      if (generation != _analysisGeneration) return;
      _events = const [];
      _streamingPatternGenerator = null;
      _hapticsLog.captureOutput('[AudioHaptics] 启动流式分析失败: $e');
    }
  }

  void start() {
    if (!_enabled || _events.isEmpty) return;
    if (_timer?.isActive ?? false) return;
    _timer?.cancel();
    if (!_timerStartLogged) {
      _hapticsLog.info(
        '触感定时器启动: events=${_events.length}, '
        'position=${(_positionProvider?.call() ?? Duration.zero).inMilliseconds}ms',
        tag: 'AudioHaptics',
      );
      _timerStartLogged = true;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 24), (_) {
      unawaited(_tick());
    });
  }

  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
    await _silencePlatformHaptics();
  }

  Future<void> stop({bool clearSource = true}) async {
    _timer?.cancel();
    _timer = null;
    _events = const [];
    _nextEventIndex = 0;
    _analysisGeneration++;
    _streamingPatternGenerator = null;
    _resetDiagnosticsForNewAnalysis();
    if (clearSource) {
      _activeStreamSource = null;
      _activeStreamFinalSource = null;
      _activeStreamSourceIsGrowing = false;
    }
    await _stopPlatformHaptics();
  }

  void seek(Duration position) {
    _nextEventIndex = _indexForPosition(position);
    final currentTrack = _track;
    final streamSource = _activeStreamSource;
    if (_enabled && currentTrack != null && streamSource != null) {
      unawaited(startStreamingAnalysis(
        track: currentTrack,
        source: streamSource,
        finalSource: _activeStreamFinalSource,
        growingFile: _activeStreamSourceIsGrowing,
        startPosition: position,
      ));
    }
  }

  Future<void> _tick() async {
    if (!_enabled || _events.isEmpty) return;
    final isPlaying = _playingProvider?.call() ?? false;
    if (!isPlaying) return;

    final position = _positionProvider?.call() ?? Duration.zero;
    final positionMs = position.inMilliseconds;
    _nextEventIndex = _nextEventIndex.clamp(0, _events.length);

    while (_nextEventIndex < _events.length &&
        _events[_nextEventIndex].timeMs < positionMs - 90) {
      _nextEventIndex++;
    }

    while (_nextEventIndex < _events.length) {
      final event = _events[_nextEventIndex];
      final delta = event.timeMs - positionMs;
      if (delta > 42) break;

      if (delta >= -80) {
        await _pulse(event);
      }
      _nextEventIndex++;
    }
  }

  Future<void> _pulse(AudioHapticEvent event) async {
    try {
      await _channel.invokeMethod<void>('pulse', {
        'intensity': event.intensity,
        'durationMs': event.durationMs,
      });
    } catch (e) {
      if (!_platformPulseFailureLogged) {
        _hapticsLog.warning(
          '平台触感脉冲调用失败，后续同一分析周期内不再重复记录: $e',
          tag: 'AudioHaptics',
        );
        _platformPulseFailureLogged = true;
      }
      // Platform haptics are best-effort; never interrupt audio playback.
    }
  }

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'analysisChunk':
        _handleAnalysisChunk(call.arguments);
        return null;
      case 'analysisFinished':
        if (!_isCurrentAnalysisMessage(call.arguments)) return null;
        _hapticsLog.captureOutput('[AudioHaptics] 流式分析完成');
        return null;
      case 'analysisFailed':
        if (!_isCurrentAnalysisMessage(call.arguments)) return null;
        _hapticsLog.captureOutput(
          '[AudioHaptics] 流式分析失败: ${_analysisMessage(call.arguments)}',
        );
        return null;
      case 'diagnostic':
        _hapticsLog.info(
          _analysisMessage(call.arguments),
          tag: 'AudioHaptics',
        );
        return null;
      default:
        throw MissingPluginException(
            'Unknown audio haptics method: ${call.method}');
    }
  }

  void _handleAnalysisChunk(dynamic arguments) {
    if (!_enabled || arguments is! Map) return;
    if (!_isCurrentAnalysisMessage(arguments)) return;

    final analysis = AudioHapticAnalysis.fromPlatform(arguments);
    final generator = _streamingPatternGenerator;
    if (generator == null) return;
    generator.userIntensity = _intensity;

    if (!_loggedFirstStreamingChunk) {
      _hapticsLog.info(
        '收到首个分析块: startFrame=${analysis.startFrame}, '
        'frameMs=${analysis.frameMs}, energies=${analysis.energies.length}, '
        'energyRange=${_energyRange(analysis.energies)}',
        tag: 'AudioHaptics',
      );
      _loggedFirstStreamingChunk = true;
    }

    final newEvents = generator.append(
      startFrame: analysis.startFrame,
      energies: analysis.energies,
    );
    if (newEvents.isEmpty) {
      if (!_loggedNoEventChunk) {
        _hapticsLog.info(
          '分析块暂未产生触感事件，可能是音量/动态不足: '
          'startFrame=${analysis.startFrame}, energies=${analysis.energies.length}',
          tag: 'AudioHaptics',
        );
        _loggedNoEventChunk = true;
      }
      return;
    }

    if (!_loggedFirstStreamingEventBatch) {
      _hapticsLog.info(
        '生成首批流式触感事件: count=${newEvents.length}, '
        'first=${newEvents.first.timeMs}ms, last=${newEvents.last.timeMs}ms',
        tag: 'AudioHaptics',
      );
      _loggedFirstStreamingEventBatch = true;
    }

    _events = [..._events, ...newEvents];
    if (_playingProvider?.call() ?? false) {
      start();
    }
  }

  bool _isCurrentAnalysisMessage(dynamic arguments) {
    if (arguments is! Map) return true;
    final token = (arguments['analysisToken'] as num?)?.toInt();
    return token == null || token == _analysisGeneration;
  }

  String _analysisMessage(dynamic arguments) {
    if (arguments is Map && arguments['message'] != null) {
      return arguments['message'].toString();
    }
    return arguments.toString();
  }

  int _indexForPosition(Duration position) {
    if (_events.isEmpty) return 0;
    final positionMs = position.inMilliseconds;
    var low = 0;
    var high = _events.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_events[mid].timeMs < positionMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  String? _localPathFromTrack(AudioTrack track) {
    if (track.url.startsWith('file://')) {
      return Uri.decodeFull(track.url.substring('file://'.length));
    }

    final sourcePath = track.sourcePath;
    if (sourcePath != null && sourcePath.isNotEmpty) return sourcePath;

    return null;
  }

  void _resetDiagnosticsForNewAnalysis() {
    _loggedFirstStreamingChunk = false;
    _loggedNoEventChunk = false;
    _loggedFirstStreamingEventBatch = false;
    _platformPulseFailureLogged = false;
    _timerStartLogged = false;
  }

  String _shortPath(String? path) {
    if (path == null || path.isEmpty) return 'none';
    if (path.length <= 96) return path;
    return '...${path.substring(path.length - 96)}';
  }

  Future<String> _fileState(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 'missing';
      final length = await file.length();
      return 'exists:${length}B';
    } catch (e) {
      return 'error:$e';
    }
  }

  String _energyRange(List<double> energies) {
    if (energies.isEmpty) return 'empty';
    var minValue = energies.first;
    var maxValue = energies.first;
    for (final energy in energies.skip(1)) {
      if (energy < minValue) minValue = energy;
      if (energy > maxValue) maxValue = energy;
    }
    return '${minValue.toStringAsFixed(3)}-${maxValue.toStringAsFixed(3)}';
  }

  Future<void> _stopPlatformHaptics() async {
    if (!_supportsPlatform) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Platform haptics are optional and should never affect playback.
    }
  }

  Future<void> _silencePlatformHaptics() async {
    if (!_supportsPlatform) return;
    try {
      await _channel.invokeMethod<void>('silence');
    } catch (_) {
      // Platform haptics are optional and should never affect playback.
    }
  }
}
