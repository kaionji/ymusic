export 'platform_setup_stub.dart'
    if (dart.library.js_interop) 'platform_setup_web.dart'
    if (dart.library.io) 'platform_setup_io.dart';
