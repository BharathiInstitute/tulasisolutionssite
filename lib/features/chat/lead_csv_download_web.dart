import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<void> saveLeadCsv(String fileName, Uint8List bytes) async {
  final blob = Blob(
    <JSAny>[bytes.toJS].toJS,
    BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}