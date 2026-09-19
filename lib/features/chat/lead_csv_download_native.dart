import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveLeadCsv(String fileName, Uint8List bytes) async {
  await FilePicker.saveFile(
    dialogTitle: 'Export chat leads',
    fileName: fileName,
    bytes: bytes,
  );
}