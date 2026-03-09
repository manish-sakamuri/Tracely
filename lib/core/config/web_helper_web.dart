import 'dart:html' as html;

/// Web implementation — reads from the real browser window.

String getWindowLocationHash() => html.window.location.hash;

String getWindowLocationOrigin() => html.window.location.origin;

void setWindowLocationHash(String hash) {
  html.window.location.hash = hash;
}
