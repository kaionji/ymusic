class Track {
  Track({
    required this.id,
    required this.title,
    required this.artist,
    this.albumId,
    this.coverUri,
    this.durationMs = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String? albumId;
  final String? coverUri;
  final int durationMs;

  factory Track.fromJson(Map<String, dynamic> j) {
    final artists = (j['artists'] as List? ?? [])
        .map((a) => (a as Map)['name'])
        .whereType<String>()
        .join(', ');
    final albums = j['albums'] as List? ?? [];
    final version = j['version'] as String?;
    var title = (j['title'] as String?) ?? 'Без названия';
    if (version != null && version.isNotEmpty) title = '$title ($version)';
    return Track(
      id: j['id'].toString(),
      title: title,
      artist: artists.isEmpty ? 'Неизвестный исполнитель' : artists,
      albumId: albums.isNotEmpty ? (albums.first as Map)['id']?.toString() : null,
      coverUri: (j['coverUri'] as String?) ?? (j['ogImage'] as String?),
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ссылка на обложку нужного размера.
  String? cover([int size = 400]) {
    final u = coverUri;
    if (u == null) return null;
    return 'https://${u.replaceAll('%%', '${size}x$size')}';
  }
}

class Playlist {
  Playlist({
    required this.uid,
    required this.kind,
    required this.title,
    required this.trackCount,
    this.coverUri,
  });

  final int uid;
  final String kind;
  final String title;
  final int trackCount;
  final String? coverUri;

  factory Playlist.fromJson(Map<String, dynamic> j) {
    String? cover;
    final c = j['cover'];
    if (c is Map) {
      if (c['uri'] is String) {
        cover = c['uri'] as String;
      } else if (c['itemsUri'] is List && (c['itemsUri'] as List).isNotEmpty) {
        cover = (c['itemsUri'] as List).first.toString();
      }
    }
    return Playlist(
      uid: (j['uid'] as num?)?.toInt() ?? 0,
      kind: j['kind'].toString(),
      title: (j['title'] as String?) ?? 'Плейлист',
      trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
      coverUri: cover,
    );
  }

  String? cover([int size = 200]) =>
      coverUri == null ? null : 'https://${coverUri!.replaceAll('%%', '${size}x$size')}';
}

String fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
