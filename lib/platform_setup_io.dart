import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

/// Запуск плеера и настройка окна (Windows/macOS/Linux; на iOS окна нет).
Future<void> setupPlatform() async {
  MediaKit.ensureInitialized();

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
}
