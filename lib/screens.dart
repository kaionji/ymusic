import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'models.dart';
import 'player.dart';
import 'theme.dart';

const _tokenUrl =
    'https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d';

// ---------------------------------------------------------------- вход

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function(String) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogin(_ctrl.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Моя Музыка',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 8),
              const Text('Неофициальный клиент Яндекс Музыки',
                  style: TextStyle(color: Pal.muted)),
              const SizedBox(height: 28),
              TextField(
                controller: _ctrl,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: 'Токен или ссылка с access_token'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Войти', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 28),
              const Text('Где взять токен', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                '1. Войдите в Яндекс в браузере.\n'
                '2. Откройте эту ссылку и разрешите доступ:',
                style: TextStyle(color: Pal.muted, height: 1.4),
              ),
              const SizedBox(height: 6),
              const SelectableText(_tokenUrl,
                  style: TextStyle(color: Pal.accent, fontSize: 12)),
              const SizedBox(height: 6),
              const Text(
                '3. В адресной строке появится #access_token=... - вставьте сюда весь адрес '
                'или только значение токена.',
                style: TextStyle(color: Pal.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- каркас

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api, required this.player, required this.onLogout});
  final YaApi api;
  final PlayerController player;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  static const _titles = ['Моя волна', 'Любимое', 'Плейлисты', 'Поиск'];

  @override
  void initState() {
    super.initState();
    widget.player.loadLikes();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final player = widget.player;
    final pages = IndexedStack(index: _tab, children: [
      WaveTab(player: player),
      LikesTab(api: widget.api, player: player),
      PlaylistsTab(api: widget.api, player: player),
      SearchTab(api: widget.api, player: player),
    ]);
    const dests = [
      (Icons.waves_rounded, 'Волна'),
      (Icons.favorite_rounded, 'Любимое'),
      (Icons.library_music_rounded, 'Плейлисты'),
      (Icons.search_rounded, 'Поиск'),
    ];

    return PlayerShortcuts(player: player, child: _scaffold(wide, pages, dests));
  }

  Widget _scaffold(bool wide, Widget pages, List<(IconData, String)> dests) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _tab,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                Expanded(child: pages),
                MiniPlayer(player: widget.player),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in dests) NavigationDestination(icon: Icon(d.$1), label: d.$2),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- вкладки

class WaveTab extends StatelessWidget {
  const WaveTab({super.key, required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF4F4F4), Color(0xFF8E8E8E)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.waves_rounded, size: 44, color: Colors.black),
                        const SizedBox(height: 48),
                        const Text('Моя волна',
                            style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -1)),
                        const SizedBox(height: 6),
                        Text(
                          player.waveMode
                              ? 'Играет сейчас. Лайки и пропуски влияют на подборку.'
                              : 'Бесконечная подборка под ваш вкус.',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: player.loading ? null : player.startWave,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Pal.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                          ),
                          icon: player.loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.play_arrow_rounded),
                          label: Text(player.waveMode ? 'Начать заново' : 'Включить'),
                        ),
                      ],
                    ),
                  ),
                  if (player.error != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(player.error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Загрузка списка с индикатором, ошибкой и кнопкой "повторить".
class LoadList<T> extends StatefulWidget {
  const LoadList({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;

  @override
  State<LoadList<T>> createState() => _LoadListState<T>();
}

class _LoadListState<T> extends State<LoadList<T>> {
  late Future<T> _f = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _f = widget.load()),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

class LikesTab extends StatelessWidget {
  const LikesTab({super.key, required this.api, required this.player});
  final YaApi api;
  final PlayerController player;

  @override
  Widget build(BuildContext context) => LoadList<List<Track>>(
        load: () => api.likedTracks(),
        builder: (_, tracks) => TrackListView(tracks: tracks, player: player),
      );
}

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key, required this.api, required this.player});
  final YaApi api;
  final PlayerController player;

  @override
  Widget build(BuildContext context) => LoadList<List<Playlist>>(
        load: () => api.playlists(),
        builder: (_, lists) => ListView.builder(
          itemCount: lists.length,
          itemBuilder: (context, i) {
            final p = lists[i];
            return ListTile(
              leading: Cover(url: p.cover(), size: 52),
              title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p.trackCount} треков', style: const TextStyle(color: Pal.muted)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlaylistScreen(api: api, player: player, playlist: p),
              )),
            );
          },
        ),
      );
}

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.api, required this.player, required this.playlist});
  final YaApi api;
  final PlayerController player;
  final Playlist playlist;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(playlist.title, overflow: TextOverflow.ellipsis)),
        body: LoadList<List<Track>>(
          load: () => api.playlistTracks(playlist),
          builder: (_, tracks) => TrackListView(tracks: tracks, player: player),
        ),
        bottomNavigationBar: MiniPlayer(player: player),
      );
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.api, required this.player});
  final YaApi api;
  final PlayerController player;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  Future<List<Track>>? _f;

  void _go() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _f = widget.api.search(q));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              hintText: 'Треки, исполнители',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _go),
            ),
          ),
        ),
        Expanded(
          child: _f == null
              ? const Center(child: Text('Введите запрос', style: TextStyle(color: Pal.muted)))
              : FutureBuilder<List<Track>>(
                  future: _f,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) return Center(child: Text('${snap.error}'));
                    final tracks = snap.data ?? [];
                    if (tracks.isEmpty) return const Center(child: Text('Ничего не найдено'));
                    return TrackListView(tracks: tracks, player: widget.player);
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- общие виджеты

class Cover extends StatelessWidget {
  const Cover({super.key, required this.url, required this.size, this.radius = 10});
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Pal.surface2,
      child: Icon(Icons.music_note_rounded, color: Pal.muted, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
            ),
    );
  }
}

class TrackListView extends StatelessWidget {
  const TrackListView({super.key, required this.tracks, required this.player});
  final List<Track> tracks;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const Center(child: Text('Здесь пока пусто'));
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final currentId = player.current?.id;
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, i) {
            final t = tracks[i];
            return ListTile(
              selected: t.id == currentId,
              leading: Cover(url: t.cover(100), size: 48),
              title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(t.artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.muted)),
              trailing: Text(fmtDuration(Duration(milliseconds: t.durationMs)),
                  style: const TextStyle(color: Pal.muted, fontSize: 12)),
              onTap: () => player.playQueue(tracks, i),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------- плеер

/// Горячие клавиши плеера (работают, пока окно приложения активно).
class PlayerShortcuts extends StatelessWidget {
  const PlayerShortcuts({super.key, required this.player, required this.child});
  final PlayerController player;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): player.togglePlay,
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): player.next,
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): player.previous,
        const SingleActivator(LogicalKeyboardKey.space, control: true): player.togglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): player.next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): player.previous,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

class LikeButton extends StatelessWidget {
  const LikeButton({super.key, required this.player, this.size = 24});
  final PlayerController player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final liked = player.isLiked;
    return IconButton(
      tooltip: liked ? 'Убрать из любимого' : 'В любимое',
      iconSize: size,
      icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? Pal.accent : Pal.muted),
      onPressed: () => player.toggleLike(),
    );
  }
}

class VolumeControl extends StatelessWidget {
  const VolumeControl({super.key, required this.player, this.width = 110});
  final PlayerController player;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: player.volume,
      builder: (_, v, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: v == 0 ? 'Включить звук' : 'Выключить звук',
            icon: Icon(
              v == 0
                  ? Icons.volume_off_rounded
                  : (v < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
              color: Pal.muted,
            ),
            onPressed: () => player.setVolume(v == 0 ? 100 : 0),
          ),
          SizedBox(
            width: width,
            child: _thinSlider(
              context,
              Slider(value: v.clamp(0.0, 100.0).toDouble(), max: 100, onChanged: player.setVolume),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _thinSlider(BuildContext context, Slider slider) {
  return SliderTheme(
    data: SliderTheme.of(context).copyWith(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    ),
    child: slider,
  );
}

/// Полоса перемотки со временем слева и справа.
class SeekBar extends StatefulWidget {
  const SeekBar({super.key, required this.player});
  final PlayerController player;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _drag; // положение ползунка, пока его тянут

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    const style = TextStyle(color: Pal.muted, fontSize: 12);
    return ValueListenableBuilder<Duration>(
      valueListenable: player.duration,
      builder: (_, dur, __) => ValueListenableBuilder<Duration>(
        valueListenable: player.position,
        builder: (_, pos, __) {
          final max = dur.inMilliseconds.toDouble();
          final value = (_drag ?? pos.inMilliseconds.toDouble())
              .clamp(0.0, max > 0 ? max : 1.0)
              .toDouble();
          return Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(fmtDuration(Duration(milliseconds: value.toInt())),
                    textAlign: TextAlign.right, style: style),
              ),
              Expanded(
                child: _thinSlider(
                  context,
                  Slider(
                    value: value,
                    max: max > 0 ? max : 1.0,
                    onChanged: max > 0 ? (v) => setState(() => _drag = v) : null,
                    onChangeEnd: (v) {
                      player.seek(Duration(milliseconds: v.toInt()));
                      setState(() => _drag = null);
                    },
                  ),
                ),
              ),
              SizedBox(width: 40, child: Text(fmtDuration(dur), style: style)),
            ],
          );
        },
      ),
    );
  }
}

/// Перемешать, назад, пуск/пауза, вперед, повтор.
class TransportControls extends StatelessWidget {
  const TransportControls({super.key, required this.player, this.big = false});
  final PlayerController player;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final wave = player.waveMode;
        final skipSize = big ? 34.0 : 26.0;
        final playSize = big ? 64.0 : 44.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Перемешать',
              icon: Icon(Icons.shuffle_rounded,
                  color: wave ? Pal.line : (player.shuffle ? Pal.accent : Pal.muted)),
              onPressed: wave ? null : player.toggleShuffle,
            ),
            IconButton(
              tooltip: 'Предыдущий',
              iconSize: skipSize,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: player.previous,
            ),
            SizedBox(width: big ? 8 : 4),
            player.loading
                ? SizedBox(
                    width: playSize,
                    height: playSize,
                    child: Padding(
                      padding: EdgeInsets.all(playSize * 0.28),
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : IconButton.filled(
                    tooltip: player.playing ? 'Пауза' : 'Играть',
                    style: IconButton.styleFrom(fixedSize: Size(playSize, playSize)),
                    iconSize: playSize * 0.58,
                    padding: EdgeInsets.zero,
                    icon: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    onPressed: player.togglePlay,
                  ),
            SizedBox(width: big ? 8 : 4),
            IconButton(
              tooltip: 'Следующий',
              iconSize: skipSize,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: player.next,
            ),
            IconButton(
              tooltip: 'Повтор',
              icon: Icon(
                player.repeat == RepeatKind.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: wave
                    ? Pal.line
                    : (player.repeat == RepeatKind.off ? Pal.muted : Pal.accent),
              ),
              onPressed: wave ? null : player.cycleRepeat,
            ),
          ],
        );
      },
    );
  }
}

void openNowPlaying(BuildContext context, PlayerController player) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => NowPlayingPage(player: player),
  ));
}

/// Нижняя панель плеера. На широком окне - трехзонная, на узком - компактная.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final t = player.current;
        if (t == null) return const SizedBox.shrink();
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final open = () => openNowPlaying(context, player);

        final info = InkWell(
          onTap: open,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Cover(url: t.cover(100), size: wide ? 56 : 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      player.error ?? t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: player.error != null ? Colors.redAccent : Pal.muted,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (wide) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Pal.surface,
              border: Border(top: BorderSide(color: Pal.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(children: [Expanded(child: info), LikeButton(player: player)]),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TransportControls(player: player),
                      SeekBar(player: player),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      VolumeControl(player: player),
                      IconButton(
                        tooltip: 'Развернуть',
                        icon: const Icon(Icons.open_in_full_rounded, color: Pal.muted),
                        onPressed: open,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: Pal.surface,
            border: Border(top: BorderSide(color: Pal.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: player.position,
                builder: (_, pos, __) => ValueListenableBuilder<Duration>(
                  valueListenable: player.duration,
                  builder: (_, dur, __) => LinearProgressIndicator(
                    minHeight: 2,
                    value: dur.inMilliseconds == 0
                        ? 0
                        : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0).toDouble(),
                    backgroundColor: Pal.line,
                    color: Pal.accent,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(child: info),
                    LikeButton(player: player),
                    player.loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: Icon(player.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            onPressed: player.togglePlay,
                          ),
                    IconButton(
                        icon: const Icon(Icons.skip_next_rounded), onPressed: player.next),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Полноэкранный плеер: подстраивается под размер окна, ничего не обрезается.
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key, required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return PlayerShortcuts(
      player: player,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Сейчас играет',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        body: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final t = player.current;
            if (t == null) {
              return const Center(child: Text('Ничего не играет', style: TextStyle(color: Pal.muted)));
            }
            return LayoutBuilder(builder: (context, c) {
              final details = _NowPlayingDetails(player: player, track: t);
              final sideBySide = c.maxWidth >= 900 && c.maxHeight < c.maxWidth * 0.8;
              if (sideBySide) {
                final cover = (c.maxHeight - 48).clamp(120.0, c.maxWidth * 0.38).toDouble();
                return Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Cover(url: t.cover(800), size: cover, radius: 20),
                      const SizedBox(width: 48),
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: details),
                    ],
                  ),
                );
              }
              final cover = (c.maxWidth - 48)
                  .clamp(96.0, 480.0)
                  .toDouble()
                  .clamp(96.0, (c.maxHeight - 330).clamp(96.0, 480.0).toDouble())
                  .toDouble();
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Cover(url: t.cover(800), size: cover, radius: 20),
                        const SizedBox(height: 24),
                        details,
                      ],
                    ),
                  ),
                ),
              );
            });
          },
        ),
      ),
    );
  }
}

class _NowPlayingDetails extends StatelessWidget {
  const _NowPlayingDetails({required this.player, required this.track});
  final PlayerController player;
  final Track track;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(track.artist, style: const TextStyle(color: Pal.muted, fontSize: 16)),
        if (player.error != null) ...[
          const SizedBox(height: 8),
          SelectableText(player.error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 16),
        SeekBar(player: player),
        const SizedBox(height: 4),
        Center(child: TransportControls(player: player, big: true)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LikeButton(player: player, size: 28),
            const SizedBox(width: 12),
            VolumeControl(player: player, width: 160),
          ],
        ),
      ],
    );
  }
}
