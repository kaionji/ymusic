import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'audio_backend_base.dart';

AudioBackend createAudioBackend() => WebAudioBackend();

// Крошечный беззвучный файл: им "разблокируем" аудио по первому нажатию (нужно для iPhone).
const _silentWav =
    'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

class WebAudioBackend implements AudioBackend {
  WebAudioBackend() {
    _a.preload = 'auto';
    _on('play', () => _playing.add(true));
    _on('playing', () => _playing.add(true));
    _on('pause', () => _playing.add(false));
    _on('ended', () {
      _playing.add(false);
      _completed.add(true);
    });
    _on('timeupdate', () {
      _position.add(Duration(milliseconds: (_a.currentTime * 1000).round()));
    });
    void dur() {
      final d = _a.duration;
      if (d.isFinite && d > 0) {
        _duration.add(Duration(milliseconds: (d * 1000).round()));
      }
    }

    _on('durationchange', dur);
    _on('loadedmetadata', dur);
    _on('error', () {
      final e = _a.error;
      _error.add('Браузер не смог воспроизвести трек'
          '${e == null ? '' : ' (код ${e.code})'}. '
          'Если это повторяется, возможно, поток Яндекса недоступен для браузера.');
    });
  }

  final web.HTMLAudioElement _a = web.HTMLAudioElement();
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  bool _unlocked = false;

  /// События беззвучного "разблокировочного" файла игнорируем.
  bool get _isSilent => _a.src.startsWith('data:');

  void _on(String type, void Function() cb) {
    _a.addEventListener(
      type,
      ((web.Event _) {
        if (!_isSilent) cb();
      }).toJS,
    );
  }

  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<String> get error => _error.stream;

  @override
  void prepare() {
    if (_unlocked) return;
    _unlocked = true;
    _a.src = _silentWav;
    _a.play().toDart.then((_) {}, onError: (_) {});
  }

  Future<void> _tryPlay() async {
    try {
      await _a.play().toDart;
    } catch (e) {
      final s = '$e';
      if (s.contains('AbortError')) return; // трек успели переключить
      _error.add('Браузер не дал начать воспроизведение: $s');
    }
  }

  @override
  Future<void> open(String url) async {
    _a.src = url;
    _a.load();
    await _tryPlay();
  }

  @override
  Future<void> play() => _tryPlay();

  @override
  Future<void> playOrPause() async {
    if (_a.paused) {
      await _tryPlay();
    } else {
      _a.pause();
    }
  }

  @override
  Future<void> seek(Duration d) async {
    _a.currentTime = d.inMilliseconds / 1000.0;
    _position.add(d);
  }

  @override
  Future<void> setVolume(double v) async {
    // На iPhone громкость задается кнопками телефона, это поле Safari игнорирует.
    _a.volume = (v / 100).clamp(0.0, 1.0).toDouble();
  }

  @override
  Future<void> dispose() async {
    _a.pause();
    _a.src = '';
    await _playing.close();
    await _position.close();
    await _duration.close();
    await _completed.close();
    await _error.close();
  }
}
