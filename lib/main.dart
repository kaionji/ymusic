import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'api.dart';
import 'player.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Заголовок и минимальный размер окна (только на компьютере).
  // Заголовок задается отсюда, чтобы русские буквы отображались правильно.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Моя Музыка', minimumSize: Size(420, 640)),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(App(prefs: prefs));
}

class App extends StatefulWidget {
  const App({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  YaApi? _api;
  PlayerController? _player;

  @override
  void initState() {
    super.initState();
    final saved = widget.prefs.getString('token');
    if (saved != null && saved.isNotEmpty) _start(YaApi(saved));
  }

  void _start(YaApi api) {
    _api = api;
    _player = PlayerController(api);
  }

  /// Принимает токен или всю ссылку с #access_token=... и проверяет его.
  Future<void> _login(String input) async {
    final m = RegExp(r'access_token=([^&\s]+)').firstMatch(input);
    final token = (m != null ? m.group(1)! : input).trim();
    if (token.isEmpty) throw ApiException('Вставьте токен');
    final api = YaApi(token);
    await api.ensureUid(); // бросит исключение, если токен неверный
    await widget.prefs.setString('token', token);
    setState(() => _start(api));
  }

  Future<void> _logout() async {
    _player?.dispose();
    await widget.prefs.remove('token');
    setState(() {
      _api = null;
      _player = null;
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Моя Музыка',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: (_api == null || _player == null)
          ? LoginScreen(onLogin: _login)
          : HomeShell(api: _api!, player: _player!, onLogout: _logout),
    );
  }
}
