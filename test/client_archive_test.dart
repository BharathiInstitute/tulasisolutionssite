import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';

void main() {
  test(
    'client edits retain contact history without overwriting its transaction-managed field',
    () {
      final client = Client(
        id: 'lead',
        name: 'Lead',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        createdDate: DateTime(2026, 10, 2),
        salesContacts: const [
          {
            'method': 'Call',
            'outcome': 'Interested',
            'at': '2026-10-02T10:00:00',
          },
        ],
      );
      final edited = client.copyWith(
        notes: 'Updated notes',
        stage: ClientStage.register,
      );
      expect(edited.salesContacts, client.salesContacts);
      expect(edited.toFirestore().containsKey('salesContacts'), isFalse);
    },
  );

  test('lead stages use canonical labels and merge legacy lead statuses', () {
    expect(chatFunnelStages.map((stage) => stage.displayName), [
      'Leads',
      'Pitch',
      'Follow Up',
      'Sale',
      'Retain',
      'Refer',
      'Closed',
    ]);
    expect(ClientStage.fromStoredName('reach'), ClientStage.click);
    expect(ClientStage.fromStoredName('click'), ClientStage.click);
    expect(ClientStage.fromStoredName('followUp'), ClientStage.consult);
    expect(ClientStage.fromStoredName('refer'), ClientStage.refer);
    expect(ClientStage.fromStoredName('retain'), ClientStage.retain);
    expect(ClientStage.storedNamesFor('retain'), ['retain']);
    expect(ClientStage.storedNamesFor('refer'), ['refer']);
    expect(ClientStage.fromStoredName('register'), ClientStage.register);
    expect(ClientStage.fromStoredName('consult'), ClientStage.consult);
    expect(ClientStage.fromStoredName('client'), ClientStage.client);
    expect(ClientStage.storedNamesFor('click'), ['click', 'reach']);
    expect(ClientStage.storedNamesFor('consult'), ['consult', 'followUp']);
    expect(ClientStage.storedNamesFor('register'), ['register']);
  });

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
