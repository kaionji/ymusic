import 'package:media_kit/media_kit.dart' hide Track, Playlist;

import 'audio_backend_base.dart';

AudioBackend createAudioBackend() => MediaKitBackend();

class MediaKitBackend implements AudioBackend {
  final Player _p = Player();

  @override
  Stream<bool> get playing => _p.stream.playing;
  @override
  Stream<Duration> get position => _p.stream.position;
  @override
  Stream<Duration> get duration => _p.stream.duration;
  @override
  Stream<bool> get completed => _p.stream.completed;
  @override
  Stream<String> get error => _p.stream.error;

  @override
  void prepare() {}

  @override
  Future<void> open(String url) => _p.open(Media(url));
  @override
  Future<void> play() => _p.play();
  @override
  Future<void> playOrPause() => _p.playOrPause();
  @override
  Future<void> seek(Duration d) => _p.seek(d);
  @override
  Future<void> setVolume(double v) => _p.setVolume(v);
  @override
  Future<void> dispose() => _p.dispose();
}
