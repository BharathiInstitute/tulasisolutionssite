import 'dart:js_interop';
import 'package:web/web.dart' as web;

void Function() registerPendingSaveWarning() {
  final listener = ((web.BeforeUnloadEvent event) {
    event.preventDefault();
    event.returnValue = 'true';
  }).toJS;
  web.window.addEventListener('beforeunload', listener);
  return () => web.window.removeEventListener('beforeunload', listener);
}
