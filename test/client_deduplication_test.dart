import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/client_deduplication.dart';
import 'package:tulasisolutionssite/core/models/models.dart';

void main() {
  Client client({
    required String id,
    required String phone,
    ClientStage stage = ClientStage.reach,
    DateTime? createdDate,
  }) {
    return Client(
      id: id,
      name: id,
      category: '',
      contactEmail: '',
      contactPhone: phone,
      stage: stage,
      createdDate: createdDate ?? DateTime(2026),
    );
  }

  test('keeps one client for equivalent phone formats', () {
    final clients = deduplicateClientsByPhone([
      client(id: 'legacy-id', phone: '9966881868'),
      client(
        id: '9966881868',
        phone: '+91 99668 81868',
        stage: ClientStage.click,
      ),
    ]);

    expect(clients, hasLength(1));
    expect(clients.single.id, '9966881868');
    expect(clients.single.stage, ClientStage.click);
  });

  test('retains clients without a valid phone', () {
    final clients = deduplicateClientsByPhone([
      client(id: 'missing-1', phone: ''),
      client(id: 'missing-2', phone: '123'),
    ]);

    expect(clients.map((client) => client.id), ['missing-1', 'missing-2']);
  });

  test('uses the freshest record when neither id is canonical', () {
    final clients = deduplicateClientsByPhone([
      client(id: 'older', phone: '9000000000', createdDate: DateTime(2025)),
      client(id: 'newer', phone: '9000000000', createdDate: DateTime(2026)),
    ]);

    expect(clients.single.id, 'newer');
  });
}