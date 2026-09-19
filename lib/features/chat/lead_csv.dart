import 'package:csv/csv.dart';

class LeadCsvRow {
  final String name;
  final String number;

  const LeadCsvRow({required this.name, required this.number});
}

class LeadCsvImportResult {
  final List<LeadCsvRow> leads;
  final int invalidRows;
  final int duplicateRows;

  const LeadCsvImportResult({
    required this.leads,
    required this.invalidRows,
    required this.duplicateRows,
  });
}

LeadCsvImportResult parseLeadCsv(String source) {
  final rows = csv.decode(source);
  if (rows.isEmpty) {
    return const LeadCsvImportResult(
      leads: [],
      invalidRows: 0,
      duplicateRows: 0,
    );
  }

  final headers = rows.first
      .map((value) => value.toString().trim().toLowerCase())
      .toList();
  final nameIndex = headers.indexOf('name');
  final numberIndex = headers.indexOf('number');
  if (nameIndex == -1 || numberIndex == -1) {
    throw const FormatException('CSV headers must be: name,number');
  }

  final leads = <LeadCsvRow>[];
  final seenNumbers = <String>{};
  var invalidRows = 0;
  var duplicateRows = 0;
  for (final row in rows.skip(1)) {
    if (row.length <= nameIndex || row.length <= numberIndex) {
      invalidRows++;
      continue;
    }
    final name = row[nameIndex].toString().trim();
    final number = row[numberIndex].toString().trim();
    final normalized = normalizeLeadNumber(number);
    if (name.isEmpty || normalized.isEmpty) {
      invalidRows++;
      continue;
    }
    if (!seenNumbers.add(normalized)) {
      duplicateRows++;
      continue;
    }
    leads.add(LeadCsvRow(name: name, number: number));
  }
  return LeadCsvImportResult(
    leads: leads,
    invalidRows: invalidRows,
    duplicateRows: duplicateRows,
  );
}

String encodeLeadCsv(Iterable<LeadCsvRow> leads) {
  final rows = <List<dynamic>>[
    ['name', 'number'],
    ...leads.map((lead) => [lead.name, lead.number]),
  ];
  return csv.encode(rows);
}

String normalizeLeadNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length < 10 ? '' : digits.substring(digits.length - 10);
}
