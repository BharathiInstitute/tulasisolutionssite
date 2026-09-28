import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/features/chat/lead_csv.dart';

void main() {
  test('imports only valid unique name and number rows', () {
    final result = parseLeadCsv(
      'name,number\r\nTulasi Cafe,+91 98765 43210\r\n'
      'Duplicate,9876543210\r\nMissing,123\r\n,9000000000',
    );

    expect(result.leads, hasLength(1));
    expect(result.leads.single.name, 'Tulasi Cafe');
    expect(result.leads.single.number, '+91 98765 43210');
    expect(result.duplicateRows, 1);
    expect(result.invalidRows, 2);
    expect(result.issues, hasLength(3));
    expect(result.issues.first.reason, 'Duplicate phone number in file');
  });

  test('requires name and number headers', () {
    expect(
      () => parseLeadCsv('business,phone\r\nTulasi,9876543210'),
      throwsFormatException,
    );
  });

  test('exports exactly name and number columns with CSV escaping', () {
    final output = encodeLeadCsv(const [
      LeadCsvRow(code: 'A0101', name: 'Cafe, One', number: '9876543210'),
    ]);

    expect(output, 'code,name,number\r\nA0101,"Cafe, One",9876543210');
  });

  test('imports and normalizes unique lead codes', () {
    final result = parseLeadCsv(
      'code,Business Name,Phone\r\na0101,Tulasi Cafe,9876543210',
    );

    expect(result.leads.single.code, 'A0101');
  });

  test('rejects duplicate lead codes', () {
    final result = parseLeadCsv(
      'code,name,phone\r\nA0101,One,9876543210\r\n'
      'a0101,Two,9876543211',
    );

    expect(result.leads, hasLength(1));
    expect(result.duplicateRows, 1);
    expect(result.issues.single.reason, 'Duplicate code in file');
  });

  test('imports XLSX with common restaurant and mobile headers', () {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    sheet.appendRow([
      TextCellValue('Restaurant Name'),
      TextCellValue('Mobile Number'),
    ]);
    sheet.appendRow([
      TextCellValue('Tulasi Kitchen'),
      TextCellValue('+91 90000 00000'),
    ]);

    final encoded = workbook.save();
    final result = parseLeadFile(Uint8List.fromList(encoded!));

    expect(result.leads, hasLength(1));
    expect(result.leads.single.name, 'Tulasi Kitchen');
    expect(result.leads.single.number, '+91 90000 00000');
  });

  test('exports complete client details with import-compatible headers', () {
    final output = encodeClientExportCsv([
      Client(
        id: 'client-1',
        clientCode: 'A2185',
        name: 'Tulasi Cafe',
        ownerName: 'Owner',
        category: 'Restaurant',
        contactEmail: 'owner@example.com',
        contactPhone: '9876543210',
        alternatePhone: '9876543211',
        assignedManager: 'Manager',
        stage: ClientStage.followUp,
        createdDate: DateTime.utc(2026, 9, 27),
        notes: 'Call tomorrow',
        sendAttemptCount: 2,
        doNotContact: true,
      ),
    ]);

    expect(output, startsWith('code,business name,phone,record id,'));
    expect(output, contains('A2185,Tulasi Cafe,9876543210,client-1'));
    expect(output, contains('Owner,Restaurant,owner@example.com'));
    expect(output, contains('followUp'));
    expect(output, contains('Call tomorrow'));
  });
}
