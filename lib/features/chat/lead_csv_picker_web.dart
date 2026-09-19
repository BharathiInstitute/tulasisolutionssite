import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<Uint8List?> pickLeadCsvBytes() {
  final completer = Completer<Uint8List?>();
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,text/csv';

  void finish(Uint8List? bytes) {
    if (completer.isCompleted) return;
    input.remove();
    completer.complete(bytes);
  }

  void handleChange(Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    unawaited(
      file.arrayBuffer().toDart.then(
        (buffer) => finish(buffer.toDart.asUint8List()),
      ),
    );
  }

  input.addEventListener('change', handleChange.toJS);
  input.addEventListener('cancel', ((Event _) => finish(null)).toJS);
  document.body?.appendChild(input);
  input.click();
  return completer.future;
}
