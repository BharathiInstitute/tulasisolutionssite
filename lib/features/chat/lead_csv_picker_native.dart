import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> pickLeadCsvBytes() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['csv'],
  );
  return file?.readAsBytes();
}
