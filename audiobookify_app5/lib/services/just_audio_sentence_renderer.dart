import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:kokoro_flutter/kokoro_flutter.dart';
import 'package:path_provider/path_provider.dart';

class JustAudioSentenceRenderer implements OpenTtsAudioRenderer {
  JustAudioSentenceRenderer({AudioPlayer? player, Directory? tempDirectory})
    : _player = player ?? AudioPlayer(),
      _tempDirectory = tempDirectory;

  final AudioPlayer _player;
  final Directory? _tempDirectory;

  Completer<void>? _playCompleter;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Object>? _errorSubscription;
  File? _currentFile;

  @override
  Future<void> play(
    Float32List audio,
    int sampleRate, {
    required String requestId,
  }) async {
    await stop(requestId: requestId);

    final file = await _writeWavFile(audio, sampleRate, requestId);
    _currentFile = file;
    final completer = Completer<void>();
    _playCompleter = completer;

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          !completer.isCompleted) {
        completer.complete();
      }
    });
    _errorSubscription = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    try {
      await _player.setFilePath(file.path);
      await _player.play();
      await completer.future;
    } finally {
      await _clearCurrentPlayback();
    }
  }

  @override
  Future<void> stop({String? requestId}) async {
    if (_playCompleter != null && !_playCompleter!.isCompleted) {
      _playCompleter!.complete();
    }
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
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    await _errorSubscription?.cancel();
    _errorSubscription = null;
    _playCompleter = null;

    final file = _currentFile;
    _currentFile = null;
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }
}
