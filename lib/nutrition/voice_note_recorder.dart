import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceClip {
  final Uint8List bytes;
  final String mimeType;

  const VoiceClip({required this.bytes, required this.mimeType});
}

class VoiceNoteRecorder {
  AudioRecorder? _recorder;
  AudioEncoder _encoder = AudioEncoder.wav;

  bool get isReady => _recorder != null;

  Future<bool> start() async {
    final recorder = _recorder ?? AudioRecorder();
    _recorder = recorder;
    if (!await recorder.hasPermission()) return false;

    _encoder = await recorder.isEncoderSupported(AudioEncoder.wav)
        ? AudioEncoder.wav
        : AudioEncoder.opus;
    await recorder.start(
      RecordConfig(encoder: _encoder, numChannels: 1, sampleRate: 16000),
      path: await _pathFor(_encoder),
    );
    return true;
  }

  Future<VoiceClip?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final path = await recorder.stop();
    if (path == null || path.isEmpty) return null;
    final bytes = await XFile(path).readAsBytes();
    if (bytes.isEmpty) return null;
    return VoiceClip(bytes: bytes, mimeType: _mimeType(_encoder));
  }

  Future<void> cancel() async {
    await _recorder?.cancel();
  }

  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }

  String _mimeType(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.wav:
        return 'audio/wav';
      case AudioEncoder.opus:
        return kIsWeb ? 'audio/webm' : 'audio/ogg';
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return 'audio/mp4';
      case AudioEncoder.flac:
        return 'audio/flac';
      default:
        return 'audio/wav';
    }
  }

  Future<String> _pathFor(AudioEncoder encoder) async {
    final ext = switch (encoder) {
      AudioEncoder.wav => 'wav',
      AudioEncoder.opus => 'opus',
      AudioEncoder.flac => 'flac',
      _ => 'm4a',
    };
    if (kIsWeb) return 'meal_voice.$ext';
    final dir = await getTemporaryDirectory();
    return '${dir.path}/meal_voice.$ext';
  }
}
