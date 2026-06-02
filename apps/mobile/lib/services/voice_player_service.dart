import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/media_url_resolver.dart';

enum VoicePlayPhase { idle, loading, playing }

/// Voice playback via media_kit (mpv on Windows desktop).
class VoicePlayerService extends ChangeNotifier {
  VoicePlayerService() {
    _player = Player(
      configuration: PlayerConfiguration(
        title: 'chat_mobile_voice',
        logLevel: MPVLogLevel.error,
        bufferSize: 2 * 1024 * 1024,
        vo: 'null',
        pitch: false,
        ready: _onPlayerReady,
      ),
    );
    _completedSub = _player.stream.completed.listen((done) {
      if (done) _safe(() => _setIdle());
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (playing &&
          _phase == VoicePlayPhase.loading &&
          _activeUrl != null) {
        _safe(() => _setPhase(VoicePlayPhase.playing));
      }
    });
    _errorSub = _player.stream.error.listen((error) {
      if (_phase == VoicePlayPhase.idle) return;
      _safe(() {
        _lastError = error;
        _setIdle();
      });
    });
  }

  late final Player _player;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;

  String? _activeUrl;
  VoicePlayPhase _phase = VoicePlayPhase.idle;
  String? _tempPath;
  String? _lastError;

  String? get activeUrl => _activeUrl;
  VoicePlayPhase get phase => _phase;
  String? get lastError => _lastError;

  bool isLoading(String url) =>
      _activeUrl == url && _phase == VoicePlayPhase.loading;

  bool isPlaying(String url) =>
      _activeUrl == url && _phase == VoicePlayPhase.playing;

  void _onPlayerReady() {
    final native = _player.platform;
    if (native is NativePlayer) {
      unawaited(_tuneMpv(native));
    }
  }

  /// Audio-only libmpv: no OSC; disable disk cache to avoid lavf cache errors.
  Future<void> _tuneMpv(NativePlayer native) async {
    const props = <String, String>{
      'cache-on-disk': 'no',
      'cache': 'no',
    };
    for (final entry in props.entries) {
      try {
        await native.setProperty(
          entry.key,
          entry.value,
          waitForInitialization: false,
        );
      } catch (_) {}
    }
  }

  void _safe(VoidCallback fn) {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle ||
        binding.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      fn();
      if (hasListeners) notifyListeners();
      return;
    }
    binding.addPostFrameCallback((_) {
      fn();
      if (hasListeners) notifyListeners();
    });
  }

  void _setPhase(VoicePlayPhase next, {String? url}) {
    _phase = next;
    _activeUrl = url ?? _activeUrl;
    _notifyUi();
  }

  void _setIdle() {
    _phase = VoicePlayPhase.idle;
    _activeUrl = null;
    _notifyUi();
  }

  void _notifyUi() {
    if (hasListeners) notifyListeners();
  }

  Future<void> play({
    required String url,
    required Map<String, String> headers,
    String? mimeType,
  }) async {
    final resolved = MediaUrlResolver.resolve(url);
    if (resolved.isEmpty) {
      throw Exception('无效的语音地址');
    }

    if (_activeUrl == url &&
        (_phase == VoicePlayPhase.playing ||
            _phase == VoicePlayPhase.loading)) {
      await stop();
      return;
    }

    await stop();
    _lastError = null;
    _setPhase(VoicePlayPhase.loading, url: url);

    try {
      final downloaded = await _download(resolved, headers);
      final ext = _extensionFor(
        bytes: downloaded.bytes,
        mimeType: mimeType,
        contentType: downloaded.contentType,
      );
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_play_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(path).writeAsBytes(downloaded.bytes, flush: true);
      _deleteTemp();
      _tempPath = path;

      await _player.open(Media(path), play: true);
      await _player.setVolume(100);

      if (_lastError != null) {
        throw Exception(_lastError!);
      }
      if (!_player.state.playing) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (_lastError != null) {
        throw Exception(_lastError!);
      }
      _setPhase(VoicePlayPhase.playing, url: url);
    } catch (e) {
      _setIdle();
      rethrow;
    }
  }

  static String _extensionFor({
    required List<int> bytes,
    String? mimeType,
    String? contentType,
  }) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        return 'wav';
      }
      if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        return 'mp3';
      }
      if (bytes.length >= 8 &&
          bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70) {
        return 'm4a';
      }
      if (bytes[0] == 0x4F &&
          bytes[1] == 0x67 &&
          bytes[2] == 0x67 &&
          bytes[3] == 0x53) {
        return 'ogg';
      }
    }
    final hint = '${contentType ?? ''} ${mimeType ?? ''}'.toLowerCase();
    if (hint.contains('wav')) return 'wav';
    if (hint.contains('mpeg') || hint.contains('mp3')) return 'mp3';
    if (hint.contains('ogg')) return 'ogg';
    if (hint.contains('mp4') || hint.contains('m4a') || hint.contains('aac')) {
      return 'm4a';
    }
    return Platform.isWindows ? 'wav' : 'm4a';
  }

  Future<({List<int> bytes, String? contentType})> _download(
    String resolved,
    Map<String, String> headers,
  ) async {
    try {
      final response = await Dio().get<List<int>>(
        resolved,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
      );
      final data = response.data;
      if (data == null || data.length < 16) {
        throw Exception('语音文件为空 (${response.statusCode})');
      }
      final contentType = response.headers.value('content-type');
      if ((contentType ?? '').contains('application/json')) {
        throw Exception('语音不存在或无权访问');
      }
      return (bytes: data, contentType: contentType);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      throw Exception('下载语音失败${code != null ? ' (HTTP $code)' : ''}');
    }
  }

  Future<void> stop() async {
    _setIdle();
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    _deleteTemp();
    super.dispose();
  }

  void _deleteTemp() {
    final path = _tempPath;
    _tempPath = null;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }
}
