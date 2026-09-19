import 'package:flutter_test/flutter_test.dart';
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
  });

  test('requires name and number headers', () {
    expect(
      () => parseLeadCsv('business,phone\r\nTulasi,9876543210'),
      throwsFormatException,
    );
  });

  test('exports exactly name and number columns with CSV escaping', () {
    final output = encodeLeadCsv(const [
      LeadCsvRow(name: 'Cafe, One', number: '9876543210'),
    ]);

    expect(output, 'name,number\r\n"Cafe, One",9876543210');
  });
}
