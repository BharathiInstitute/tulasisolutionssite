import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:tulasisolutionssite/core/models/models.dart';

class LeadCsvRow {
  final String code;
  final String name;
  final String number;

  const LeadCsvRow({this.code = '', required this.name, required this.number});
}

class LeadCsvImportResult {
  final List<LeadCsvRow> leads;
  final int invalidRows;
  final int duplicateRows;
  final List<LeadImportIssue> issues;

  const LeadCsvImportResult({
    required this.leads,
    required this.invalidRows,
    required this.duplicateRows,
    this.issues = const [],
  });
}

class LeadImportIssue {
  final int rowNumber;
  final String reason;
  final String name;
  final String number;

  const LeadImportIssue({
    required this.rowNumber,
    required this.reason,
    this.name = '',
    this.number = '',
  });
}

LeadCsvImportResult parseLeadCsv(String source) {
  return _parseLeadRows(csv.decode(source));
}

LeadCsvImportResult parseLeadFile(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04) {
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables.values.firstWhere(
      (table) => table.rows.any(
        (row) => row.any(
          (cell) => cell?.value?.toString().trim().isNotEmpty == true,
        ),
      ),
      orElse: () => throw const FormatException('The spreadsheet is empty.'),
    );
    return _parseLeadRows(
      sheet.rows
          .map(
            (row) => row.map((cell) => cell?.value?.toString() ?? '').toList(),
          )
          .toList(),
    );
  }

  return parseLeadCsv(utf8.decode(bytes));
}

LeadCsvImportResult _parseLeadRows(List<List<dynamic>> rows) {
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
  final nameIndex = headers.indexWhere(
    (header) =>
        const ['name', 'restaurant name', 'business name'].contains(header),
  );
  final numberIndex = headers.indexWhere(
    (header) => const [
      'number',
      'phone',
      'phone number',
      'mobile',
      'mobile number',
    ].contains(header),
  );
  final codeIndex = headers.indexWhere(
    (header) => const ['code', 'client code', 'lead code'].contains(header),
  );
  if (nameIndex == -1 || numberIndex == -1) {
    throw const FormatException(
      'A name column and a phone or mobile number column are required.',
    );
  }

  final leads = <LeadCsvRow>[];
  final issues = <LeadImportIssue>[];
  final seenNumbers = <String>{};
  final seenCodes = <String>{};
  var invalidRows = 0;
  var duplicateRows = 0;
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.length <= nameIndex || row.length <= numberIndex) {
      invalidRows++;
      issues.add(
        LeadImportIssue(
          rowNumber: rowIndex + 1,
          reason: 'Missing name or phone column value',
        ),
      );
      continue;
    }
    final name = row[nameIndex].toString().trim();
    final number = row[numberIndex].toString().trim();
    final code = codeIndex >= 0 && row.length > codeIndex
      ? row[codeIndex].toString().trim().toUpperCase()
      : '';
    final normalized = normalizeLeadNumber(number);
    if (name.isEmpty || normalized.isEmpty) {
      invalidRows++;
      issues.add(
        LeadImportIssue(
          rowNumber: rowIndex + 1,
          reason: name.isEmpty
              ? 'Restaurant name is empty'
              : 'Invalid phone number',
          name: name,
          number: number,
        ),
      );
      continue;
    }
    if (!seenNumbers.add(normalized)) {
      duplicateRows++;
      issues.add(
        LeadImportIssue(
          rowNumber: rowIndex + 1,
          reason: 'Duplicate phone number in file',
          name: name,
          number: number,
        ),
      );
      continue;
    }
    if (code.isNotEmpty && !seenCodes.add(code)) {
      duplicateRows++;
      issues.add(
        LeadImportIssue(
          rowNumber: rowIndex + 1,
          reason: 'Duplicate code in file',
          name: name,
          number: number,
        ),
      );
      continue;
    }
    leads.add(LeadCsvRow(code: code, name: name, number: number));
  }
  return LeadCsvImportResult(
    leads: leads,
    invalidRows: invalidRows,
    duplicateRows: duplicateRows,
    issues: issues,
  );
}

String encodeLeadCsv(Iterable<LeadCsvRow> leads) {
  final rows = <List<dynamic>>[
    ['code', 'name', 'number'],
    ...leads.map((lead) => [lead.code, lead.name, lead.number]),
  ];
  return csv.encode(rows);
}

String encodeClientExportCsv(Iterable<Client> clients) {
  String date(DateTime? value) => value?.toIso8601String() ?? '';
  final rows = <List<dynamic>>[
    [
      'code',
      'business name',
      'phone',
      'record id',
      'owner name',
      'category',
      'email',
      'alternate phone',
      'assigned manager',
      'stage',
      'created date',
      'updated date',
      'notes',
      'follow up at',
      'follow up notes',
      'intent confirmed',
      'role confirmed',
      'decision maker role',
      'package tier',
      'closed reason',
      'closed sub reason',
      'closed note',
      'stage changed at',
      'archived',
      'last send status',
      'last send error',
      'last attempt at',
      'send attempt count',
      'last campaign id',
      'do not contact',
    ],
    ...clients.map(
      (client) => [
        client.clientCode,
        client.name,
        client.contactPhone,
        client.id,
        client.ownerName ?? '',
        client.category,
        client.contactEmail,
        client.alternatePhone ?? '',
        client.assignedManager ?? '',
        client.stage.name,
        date(client.createdDate),
        date(client.updatedDate),
        client.notes ?? '',
        date(client.followUpAt),
        client.followUpNotes ?? '',
        client.intentConfirmed,
        client.roleConfirmed,
        client.decisionMakerRole ?? '',
        client.packageTier ?? '',
        client.closedReason ?? '',
        client.closedSubReason ?? '',
        client.closedNote ?? '',
        date(client.stageChangedAt),
        client.isArchived,
        client.lastSendStatus ?? '',
        client.lastSendError ?? '',
        date(client.lastAttemptAt),
        client.sendAttemptCount,
        client.lastCampaignId ?? '',
        client.doNotContact,
      ],
    ),
  ];
  return csv.encode(rows);
}

String normalizeLeadNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length < 10 ? '' : digits.substring(digits.length - 10);
}
