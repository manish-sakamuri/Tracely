/// Platform-aware web helper.
/// On web, this exports the dart:html-based implementation.
/// On other platforms, it exports no-op stubs.
export 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart';
