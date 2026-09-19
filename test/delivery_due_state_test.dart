import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delivery task due states use calendar days', () {
    final today = DateTime(2026, 9, 9, 16);
    final tomorrow = DateTime(2026, 9, 10);
    final overdue = DateTime(2026, 9, 7);

    expect(
      tomorrow.difference(DateTime(today.year, today.month, today.day)).inDays,
      1,
    );
    expect(
      overdue.difference(DateTime(today.year, today.month, today.day)).inDays,
      -2,
    );
  });
}
