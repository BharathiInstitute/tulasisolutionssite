@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:tulasisolutionssite/core/tasks/pending_save_warning_web.dart';

void main() {
  test(
    'browser unload is prevented only while the unsaved warning is registered',
    () {
      web.Event unload() =>
          web.Event('beforeunload', web.EventInit(cancelable: true));
      final before = unload();
      web.window.dispatchEvent(before);
      expect(before.defaultPrevented, isFalse);
      final remove = registerPendingSaveWarning();
      try {
        final pending = unload();
        web.window.dispatchEvent(pending);
        expect(pending.defaultPrevented, isTrue);
      } finally {
        remove();
      }
      final confirmed = unload();
      web.window.dispatchEvent(confirmed);
      expect(confirmed.defaultPrevented, isFalse);
    },
  );
}
