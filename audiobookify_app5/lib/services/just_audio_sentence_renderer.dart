import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'open_tts_renderer_support.dart';
import 'tts_debug_logging.dart';

class JustAudioSentenceRenderer implements ManagedOpenTtsAudioRenderer {
  JustAudioSentenceRenderer({AudioPlayer? player, Directory? tempDirectory})
    : _player = player ?? AudioPlayer(),
      _tempDirectory = tempDirectory;

  final AudioPlayer _player;
  final Directory? _tempDirectory;
  @override
  void Function(String requestId)? onPlaybackStart;
  @override
  void Function(String requestId)? onPlaybackComplete;

  File? _currentFile;

  @override
  Future<void> play(
    Float32List audio,
    int sampleRate, {
    required String requestId,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    await stop(requestId: requestId);

    final writeStopwatch = Stopwatch()..start();
    final file = await _writeWavFile(audio, sampleRate, requestId);
    writeStopwatch.stop();
    _currentFile = file;
    final double audioDurationMs = (audio.length / sampleRate) * 1000.0;
    logTtsDebug(
      'JustAudio renderer prepared requestId=$requestId '
      'samples=${audio.length} sampleRate=$sampleRate '
      'audioDurationMs=${audioDurationMs.toStringAsFixed(1)} '
      'wavWriteMs=${writeStopwatch.elapsedMilliseconds}',
      category: 'tts.renderer',
    );

    try {
      final setFilePathStopwatch = Stopwatch()..start();
      await _player.setFilePath(file.path);
      setFilePathStopwatch.stop();
      logTtsDebug(
        'JustAudio renderer player ready requestId=$requestId setFilePathMs=${setFilePathStopwatch.elapsedMilliseconds}',
        category: 'tts.renderer',
      );

      final playbackStopwatch = Stopwatch()..start();
      logTtsDebug(
        'JustAudio renderer starting playback requestId=$requestId',
        category: 'tts.renderer',
      );
      onPlaybackStart?.call(requestId);
      await _player.play();
      playbackStopwatch.stop();
      totalStopwatch.stop();
      onPlaybackComplete?.call(requestId);
      logTtsDebug(
        'JustAudio renderer completed playback requestId=$requestId '
        'playbackMs=${playbackStopwatch.elapsedMilliseconds} '
        'totalRendererMs=${totalStopwatch.elapsedMilliseconds}',
        category: 'tts.renderer',
      );
    } on Object catch (error, stackTrace) {
      totalStopwatch.stop();
      logTtsDebug(
        'JustAudio renderer playback failed requestId=$requestId totalRendererMs=${totalStopwatch.elapsedMilliseconds}',
        category: 'tts.renderer',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      await _clearCurrentPlayback();
    }
  }

  @override
  Future<void> stop({String? requestId}) async {
    logTtsDebug(
      'JustAudio renderer stop requestId=${requestId ?? "current"}',
      category: 'tts.renderer',
    );
    await _player.stop();
    await _clearCurrentPlayback();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    await _player.play();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  Future<File> _writeWavFile(
    Float32List audio,
    int sampleRate,
    String requestId,
  ) async {
    final directory = _tempDirectory ?? await getTemporaryDirectory();
    final file = File(
      '${directory.path}/audiobookify_tts_${requestId}_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(_encodeWav(audio, sampleRate), flush: true);
    return file;
  }

  Uint8List _encodeWav(Float32List samples, int sampleRate) {
    const bytesPerSample = 2;
    const headerSize = 44;
    final dataSize = samples.length * bytesPerSample;
    final fileSize = 36 + dataSize;
    final buffer = ByteData(headerSize + dataSize);

    _writeAscii(buffer, 0, 'RIFF');
    buffer.setUint32(4, fileSize, Endian.little);
    _writeAscii(buffer, 8, 'WAVE');
    _writeAscii(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * bytesPerSample, Endian.little);
    buffer.setUint16(32, bytesPerSample, Endian.little);
    buffer.setUint16(34, bytesPerSample * 8, Endian.little);
    _writeAscii(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    var offset = headerSize;
    for (final sample in samples) {
      final value = (math.max(-1.0, math.min(1.0, sample)) * 32767).round();
      buffer.setInt16(offset, value, Endian.little);
      offset += bytesPerSample;
    }

    return buffer.buffer.asUint8List(0, headerSize + dataSize);
  }

  void _writeAscii(ByteData buffer, int offset, String value) {
    for (var i = 0; i < value.length; i += 1) {
      buffer.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  Future<void> _clearCurrentPlayback() async {
    final file = _currentFile;
    _currentFile = null;
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }
}
