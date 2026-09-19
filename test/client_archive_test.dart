
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';

void main() {
  Client buildClient() => Client(
    id: 'client-1',
    name: 'Example Business',
    category: 'Retail',
    contactEmail: 'example@test.com',
    contactPhone: '1234567890',
    stage: ClientStage.followUp,
    createdDate: DateTime(2026, 9, 15),
  );

  test('archiving preserves the lead funnel stage', () {
    final archived = buildClient().copyWith(isArchived: true);

    expect(archived.isArchived, isTrue);
    expect(archived.stage, ClientStage.followUp);
    expect(archived.toFirestore()['isArchived'], isTrue);
  });

  test('new leads are active by default', () {
    expect(buildClient().isArchived, isFalse);
  });
}
