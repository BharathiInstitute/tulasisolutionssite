import '../models/models.dart';

String normalizeClientPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length < 10 ? '' : digits.substring(digits.length - 10);
}

List<Client> deduplicateClientsByPhone(Iterable<Client> clients) {
  final clientsByPhone = <String, Client>{};

  for (final client in clients) {
    final phone = normalizeClientPhone(client.contactPhone);
    final key = phone.isEmpty ? 'id:${client.id}' : 'phone:$phone';
    final existing = clientsByPhone[key];
    if (existing == null || _preferClient(client, existing, phone)) {
      clientsByPhone[key] = client;
    }
  }

  return clientsByPhone.values.toList();
}

bool _preferClient(Client candidate, Client existing, String phone) {
  final candidateHasCanonicalId = phone.isNotEmpty && candidate.id == phone;
  final existingHasCanonicalId = phone.isNotEmpty && existing.id == phone;
  if (candidateHasCanonicalId != existingHasCanonicalId) {
    return candidateHasCanonicalId;
  }

  final candidateDate =
      candidate.updatedDate ?? candidate.stageChangedAt ?? candidate.createdDate;
  final existingDate =
      existing.updatedDate ?? existing.stageChangedAt ?? existing.createdDate;
  return candidateDate.isAfter(existingDate);
}