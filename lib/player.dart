import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Track, Playlist;

import 'api.dart';
import 'models.dart';

enum RepeatKind { off, all, one }

/// Очередь, «Моя волна» и воспроизведение. Один экземпляр на все приложение.
class PlayerController extends ChangeNotifier {
  PlayerController(this.api) {
    _subs.addAll([
      _player.stream.playing.listen((v) {
        playing = v;
        notifyListeners();
      }),
      _player.stream.position.listen((v) => position.value = v),
      _player.stream.duration.listen((v) {
        if (v > Duration.zero) duration.value = v;
      }),
      _player.stream.completed.listen((done) {
        if (done) _onCompleted();
      }),
      _player.stream.error.listen((e) {
        error = e;
        loading = false;
        notifyListeners();
      }),
    ]);
  }

  final YaApi api;
  final Player _player = Player();
  final List<StreamSubscription> _subs = [];
  final Random _rand = Random();

  // очередь
  List<Track> queue = [];
  int index = -1;
  final List<int> _history = []; // для "назад" при перемешивании

  // состояние
  bool playing = false;
  bool loading = false;
  String? error;
  bool shuffle = false;
  RepeatKind repeat = RepeatKind.off;
  Set<String> likedIds = {};

  // волна
  bool waveMode = false;
  String? _waveSession;
  String? _waveBatch;
  bool _extending = false;

  // часто меняются - отдельно, чтобы не перерисовывать весь интерфейс
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<double> volume = ValueNotifier(100);

  int _gen = 0;

  Track? get current => (index >= 0 && index < queue.length) ? queue[index] : null;
  bool get isLiked => current != null && likedIds.contains(current!.id);

  // ---------------------------------------------------------------- запуск

  Future<void> playQueue(List<Track> tracks, int startIndex) async {
    waveMode = false;
    _waveSession = null;
    _waveBatch = null;
    _history.clear();
    queue = List.of(tracks);
    await _playIndex(startIndex);
  }

  Future<void> startWave() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final b = await api.waveStart();
      if (b.tracks.isEmpty) throw ApiException('Волна не вернула ни одного трека');
      waveMode = true;
      _waveSession = b.sessionId;
      _waveBatch = b.batchId;
      _history.clear();
      queue = List.of(b.tracks);
      unawaited(api.waveFeedback(_waveSession, _waveBatch, 'radioStarted'));
      await _playIndex(0);
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _playIndex(int i) async {
    if (i < 0 || i >= queue.length) return;
    final gen = ++_gen;
    index = i;
    loading = true;
    error = null;
    position.value = Duration.zero;
    duration.value = Duration(milliseconds: queue[i].durationMs);
    notifyListeners();
    try {
      final url = await api.streamUrl(queue[i].id);
      if (gen != _gen) return; // пока грузили ссылку, выбрали другой трек
      await _player.open(Media(url));
      if (waveMode) {
        unawaited(api.waveFeedback(_waveSession, _waveBatch, 'trackStarted',
            trackId: queue[i].id));
      }
    } catch (e) {
      if (gen == _gen) error = e.toString();
    }
    if (gen == _gen) {
      loading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- управление

  Future<void> togglePlay() => _player.playOrPause();
  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> setVolume(double v) async {
    volume.value = v;
    await _player.setVolume(v);
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = RepeatKind.values[(repeat.index + 1) % RepeatKind.values.length];
    notifyListeners();
  }

  Future<void> next() => _advance(auto: false);

  Future<void> previous() async {
    if (waveMode || position.value > const Duration(seconds: 3) || index <= 0) {
      await _player.seek(Duration.zero);
      return;
    }
    if (shuffle && _history.isNotEmpty) {
      await _playIndex(_history.removeLast());
    } else {
      await _playIndex(index - 1);
    }
  }

  Future<void> _onCompleted() async {
    if (repeat == RepeatKind.one && !waveMode) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    await _advance(auto: true);
  }

  Future<void> _advance({required bool auto}) async {
    if (current == null) return;

    if (waveMode) {
      final secs = (position.value.inMilliseconds / 100).round() / 10;
      unawaited(api.waveFeedback(_waveSession, _waveBatch, auto ? 'trackFinished' : 'skip',
          trackId: current!.id, seconds: secs));
      if (index + 1 >= queue.length - 1) await _extendWave();
      if (index + 1 < queue.length) await _playIndex(index + 1);
      return;
    }

    if (shuffle && queue.length > 1) {
      _history.add(index);
      var n = _rand.nextInt(queue.length);
      while (n == index) {
        n = _rand.nextInt(queue.length);
      }
      await _playIndex(n);
    } else if (index + 1 < queue.length) {
      _history.add(index);
      await _playIndex(index + 1);
    } else if (repeat == RepeatKind.all) {
      _history.add(index);
      await _playIndex(0);
    }
  }

  Future<void> _extendWave() async {
    if (_extending) return;
    _extending = true;
    try {
      final from = queue.length > 10 ? queue.length - 10 : 0;
      final played = queue.sublist(from, index + 1).map((t) => t.id).toList();
      final b = await api.waveNext(_waveSession, played);
      final known = queue.map((t) => t.id).toSet();
      queue.addAll(b.tracks.where((t) => !known.contains(t.id)));
      _waveSession = b.sessionId ?? _waveSession;
      _waveBatch = b.batchId ?? _waveBatch;
    } catch (e) {
      error = 'Не удалось подгрузить волну: $e';
      notifyListeners();
    } finally {
      _extending = false;
    }
  }

  // ---------------------------------------------------------------- лайки

  Future<void> loadLikes() async {
    try {
      likedIds = await api.likedIds();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleLike([Track? track]) async {
    final t = track ?? current;
    if (t == null) return;
    final was = likedIds.contains(t.id);
    if (was) {
      likedIds.remove(t.id);
    } else {
      likedIds.add(t.id);
    }
    notifyListeners();
    try {
      await api.setLike(t, !was);
    } catch (e) {
      if (was) {
        likedIds.add(t.id);
      } else {
        likedIds.remove(t.id);
      }
      error = 'Не удалось изменить лайк: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    position.dispose();
    duration.dispose();
    volume.dispose();
    super.dispose();
  }
}
