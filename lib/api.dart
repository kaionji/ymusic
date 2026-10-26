import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Пачка треков «Моей волны».
class WaveBatch {
  WaveBatch({required this.sessionId, required this.batchId, required this.tracks});
  final String? sessionId; // null - работаем через старую схему станций
  final String? batchId;
  final List<Track> tracks;
}

/// Клиент к неофициальному API Яндекс Музыки.
/// Яндекс может изменить его в любой момент - все, что может сломаться,
/// собрано в этом файле.
class YaApi {
  YaApi(this.token);

  final String token;
  int? _uid;
  String? login;

  // В веб-версии сюда подставляется адрес посредника (--dart-define=API_BASE=...).
  static const _base =
      String.fromEnvironment('API_BASE', defaultValue: 'https://api.music.yandex.net');
  // Константа из мобильного приложения (описана в issue #566 библиотеки yandex-music-api).
  static const _signSecret = 'p93jhgh689SBReK6ghtw62';

  Map<String, String> get _headers => {
        'Authorization': 'OAuth $token',
        'X-Yandex-Music-Client': 'YandexMusicAndroid/24022571',
        'Accept-Language': 'ru',
      };

  dynamic _decode(http.Response r) {
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiException('Неожиданный ответ сервера (HTTP ${r.statusCode})');
    }
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw ApiException('Токен не подошел или устарел. Войдите заново.');
    }
    if (r.statusCode != 200) {
      final msg = (j is Map && j['error'] is Map) ? (j['error']['message'] ?? '') : '';
      throw ApiException('Ошибка API (HTTP ${r.statusCode}) $msg');
    }
    return (j as Map)['result'];
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    return _decode(await http.get(uri, headers: _headers));
  }

  /// Проверяет токен и запоминает uid пользователя.
  Future<int> ensureUid() async {
    if (_uid != null) return _uid!;
    final res = await _get('/account/status');
    final acc = (res as Map)['account'] as Map;
    _uid = (acc['uid'] as num).toInt();
    login = acc['login'] as String?;
    return _uid!;
  }

  /// Полные данные треков по списку id (пачками по 100).
  Future<List<Track>> tracksByIds(List<String> ids) async {
    final out = <Track>[];
    for (var i = 0; i < ids.length; i += 100) {
      final chunk = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
      final r = await http.post(
        Uri.parse('$_base/tracks'),
        headers: _headers,
        body: {'track-ids': chunk.join(',')},
      );
      final list = _decode(r) as List;
      out.addAll(list.map((e) => Track.fromJson(e as Map<String, dynamic>)));
    }
    return out;
  }

  /// "Мне нравится" (до [limit] треков).
  Future<List<Track>> likedTracks({int limit = 500}) async {
    final uid = await ensureUid();
    final res = await _get('/users/$uid/likes/tracks');
    final items = ((res as Map)['library'] as Map)['tracks'] as List? ?? [];
    final ids = items
        .map((e) => (e as Map)['id'].toString())
        .toList()
        .reversed // свежие лайки сверху
        .take(limit)
        .toList();
    return tracksByIds(ids);
  }

  Future<List<Playlist>> playlists() async {
    final uid = await ensureUid();
    final res = await _get('/users/$uid/playlists/list');
    return (res as List)
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Track>> playlistTracks(Playlist p) async {
    final res = await _get('/users/${p.uid}/playlists/${p.kind}');
    final items = ((res as Map)['tracks'] as List? ?? []);
    final ready = <Track>[];
    final missing = <String>[];
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      if (m['track'] is Map<String, dynamic>) {
        ready.add(Track.fromJson(m['track'] as Map<String, dynamic>));
      } else {
        missing.add(m['id'].toString());
      }
    }
    if (missing.isNotEmpty) ready.addAll(await tracksByIds(missing));
    return ready;
  }

  Future<List<Track>> search(String text) async {
    final res = await _get('/search', {
      'text': text,
      'nocorrect': 'false',
      'type': 'track',
      'page': '0',
    });
    final tracks = (res as Map)['tracks'];
    if (tracks is! Map) return [];
    final results = tracks['results'] as List? ?? [];
    return results.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ------------------------------------------------------------ лайки

  Future<Set<String>> likedIds() async {
    final uid = await ensureUid();
    final res = await _get('/users/$uid/likes/tracks');
    final items = ((res as Map)['library'] as Map)['tracks'] as List? ?? [];
    return items.map((e) => (e as Map)['id'].toString()).toSet();
  }

  Future<void> setLike(Track t, bool like) async {
    final uid = await ensureUid();
    final id = t.albumId != null ? '${t.id}:${t.albumId}' : t.id;
    final r = await http.post(
      Uri.parse('$_base/users/$uid/likes/tracks/${like ? 'add-multiple' : 'remove'}'),
      headers: _headers,
      body: {'track-ids': id},
    );
    _decode(r);
  }

  // ------------------------------------------------------------ Моя волна
  // Яндекс перевел волну на "сессии" (/rotor/session/...). Формат запросов
  // описан в открытых источниках неполно, поэтому есть запасной вариант на
  // старые "станции". Если волна перестанет работать - чинить здесь.

  static const waveSeed = 'user:onyourwave';

  Future<dynamic> _postJson(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final r = await http.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(r);
  }

  Future<WaveBatch> _parseWave(dynamic res, String? sessionId) async {
    final m = res as Map<String, dynamic>;
    final seq = m['sequence'] as List? ?? [];
    final ready = <Track>[];
    final missing = <String>[];
    for (final it in seq) {
      if (it is! Map) continue;
      final t = it['track'];
      if (t is Map<String, dynamic>) {
        ready.add(Track.fromJson(t));
      } else if (t != null) {
        missing.add(t.toString());
      }
    }
    if (missing.isNotEmpty) ready.addAll(await tracksByIds(missing));
    return WaveBatch(
      sessionId: (m['radioSessionId'] ?? sessionId)?.toString(),
      batchId: m['batchId']?.toString(),
      tracks: ready,
    );
  }

  Future<WaveBatch> waveStart() async {
    try {
      final res = await _postJson('/rotor/session/new', {
        'seeds': [waveSeed],
        'includeTracksInResponse': true,
      });
      final b = await _parseWave(res, null);
      if (b.tracks.isEmpty) throw ApiException('Сессия волны вернула пустой список');
      return b;
    } catch (e) {
      try {
        final res = await _get('/rotor/station/$waveSeed/tracks', {'settings2': 'true'});
        return await _parseWave(res, null);
      } catch (_) {
        throw ApiException('Не удалось запустить волну: $e');
      }
    }
  }

  /// Подгрузка следующей пачки. [played] - id уже сыгранных треков.
  Future<WaveBatch> waveNext(String? sessionId, List<String> played) async {
    if (sessionId != null) {
      final res = await _postJson('/rotor/session/$sessionId/tracks', {'queue': played});
      return _parseWave(res, sessionId);
    }
    final res = await _get('/rotor/station/$waveSeed/tracks', {
      'settings2': 'true',
      if (played.isNotEmpty) 'queue': played.last,
    });
    return _parseWave(res, null);
  }

  /// Отзывы для рекомендаций (начал/доиграл/пропустил). Ошибки не критичны.
  Future<void> waveFeedback(String? sessionId, String? batchId, String type,
      {String? trackId, double? seconds}) async {
    final event = <String, dynamic>{
      'type': type,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    if (type == 'radioStarted') event['from'] = 'ya-music-wave';
    if (trackId != null) event['trackId'] = trackId;
    if (seconds != null) event['totalPlayedSeconds'] = seconds;
    try {
      if (sessionId != null) {
        await _postJson('/rotor/session/$sessionId/feedback', {
          'event': event,
          if (batchId != null) 'batchId': batchId,
        });
      } else {
        await _postJson('/rotor/station/$waveSeed/feedback', event,
            query: {if (batchId != null) 'batch-id': batchId});
      }
    } catch (_) {}
  }

  /// Ссылка, которую можно отдать плееру.
  Future<String> streamUrl(String trackId) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final mac = Hmac(sha256, utf8.encode(_signSecret));
    final sign = base64.encode(mac.convert(utf8.encode('$trackId$ts')).bytes);

    final res = await _get('/tracks/$trackId/download-info', {
      'can_use_streaming': 'true',
      'ts': '$ts',
      'sign': sign,
    });
    final list = (res as List)
        .cast<Map<String, dynamic>>()
        .where((e) => e['preview'] != true)
        .toList();
    if (list.isEmpty) {
      throw ApiException('Для этого трека нет доступных потоков (возможно, нужна подписка Плюс).');
    }
    // Сначала mp3, внутри кодека - самый высокий битрейт.
    list.sort((a, b) {
      final ca = a['codec'] == 'mp3' ? 0 : 1;
      final cb = b['codec'] == 'mp3' ? 0 : 1;
      if (ca != cb) return ca - cb;
      return ((b['bitrateInKbps'] as num?) ?? 0).compareTo((a['bitrateInKbps'] as num?) ?? 0);
    });
    final best = list.first;
    final url = best['downloadInfoUrl'] as String;
    if (best['container'] == 'hls' || url.contains('.m3u8') || best['direct'] == true) {
      return url;
    }
    return _legacyDirectLink(url);
  }

  /// Запасной вариант для старого формата ответа (XML/JSON + md5-подпись).
  /// Может быть неактуален, если Яндекс окончательно отключил старую схему.
  Future<String> _legacyDirectLink(String infoUrl) async {
    final u = Uri.parse(infoUrl);
    final r = await http.get(
      u.replace(queryParameters: {...u.queryParameters, 'format': 'json'}),
      headers: _headers,
    );
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final host = j['host'] as String;
    final path = j['path'] as String;
    final ts = j['ts'] as String;
    final s = j['s'] as String;
    final sign = md5.convert(utf8.encode('XGRlBW9FXlekgbPrRHuSiA${path.substring(1)}$s')).toString();
    return 'https://$host/get-mp3/$sign/$ts$path';
  }
}
