/// Общий интерфейс звука: на Windows работает media_kit, в браузере (iPhone) - HTML-аудио.
abstract class AudioBackend {
  Stream<bool> get playing;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get completed;
  Stream<String> get error;

  /// Вызывается сразу в момент нажатия пользователем (до любых ожиданий).
  /// В браузере iPhone это "разрешает" звук - иначе Safari блокирует автозапуск.
  void prepare();

  Future<void> open(String url);
  Future<void> play();
  Future<void> playOrPause();
  Future<void> seek(Duration d);
  Future<void> setVolume(double v); // 0..100
  Future<void> dispose();
}
