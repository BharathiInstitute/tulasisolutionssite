import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tulasisolutionssite/features/chat/lead_csv.dart';

const _projectId = 'newproject1234561';
const _databaseId = '(default)';
const _batchSize = 400;

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/backfill_lead_codes.dart <file.xlsx|csv> [--apply]',
    );
    exitCode = 64;
    return;
  }

  final file = File(arguments.first);
  if (!await file.exists()) {
    stderr.writeln('File not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final parsed = parseLeadFile(Uint8List.fromList(await file.readAsBytes()));
  final csvCodesByPhone = <String, String>{
    for (final lead in parsed.leads)
      normalizeLeadNumber(lead.number): lead.code.trim().toUpperCase(),
  };
  final duplicateCodes = _duplicates(
    csvCodesByPhone.values.where((code) => code.isNotEmpty),
  );
  if (duplicateCodes.isNotEmpty) {
    throw StateError('Duplicate CSV codes: ${duplicateCodes.join(', ')}');
  }

  final accessToken = await _gcloudAccessToken();
  final clients = await _loadClients(accessToken);
  clients.sort((left, right) => left.id.compareTo(right.id));

  final clientsByPhone = <String, List<_FirestoreClient>>{};
  for (final client in clients) {
    final phone = normalizeLeadNumber(client.phone);
    final key = phone.isEmpty ? 'id:${client.id}' : phone;
    clientsByPhone.putIfAbsent(key, () => []).add(client);
  }
  final primaryClients = <_FirestoreClient>[];
  final duplicateClients = <_FirestoreClient>[];
  for (final entry in clientsByPhone.entries) {
    final phone = entry.key.startsWith('id:') ? '' : entry.key;
    final ordered = [...entry.value]
      ..sort((left, right) => _comparePreference(left, right, phone));
    primaryClients.add(ordered.first);
    duplicateClients.addAll(ordered.skip(1));
  }
  primaryClients.sort((left, right) => left.id.compareTo(right.id));
  duplicateClients.sort((left, right) => left.id.compareTo(right.id));

  final reservedCodes = csvCodesByPhone.values
      .where((code) => code.isNotEmpty)
      .toSet();
  final assignedCodes = <String>{...reservedCodes};
  final assignments = <_CodeAssignment>[];
  var matchedCsv = 0;
  var legacy = 0;
  var nextLegacyNumber = _nextSequentialNumber(reservedCodes);
  var nextDuplicateNumber = 1;

  String nextLegacyCode() {
    while (true) {
      final candidate = 'A${nextLegacyNumber.toString().padLeft(4, '0')}';
      nextLegacyNumber++;
      if (assignedCodes.add(candidate)) return candidate;
    }
  }

  String nextDuplicateCode() {
    while (true) {
      final candidate = 'D${nextDuplicateNumber.toString().padLeft(4, '0')}';
      nextDuplicateNumber++;
      if (assignedCodes.add(candidate)) return candidate;
    }
  }

  for (final client in primaryClients) {
    final phone = normalizeLeadNumber(client.phone);
    final csvCode = csvCodesByPhone[phone] ?? '';
    late final String desiredCode;
    if (csvCode.isNotEmpty) {
      desiredCode = csvCode;
      matchedCsv++;
    } else {
      desiredCode = nextLegacyCode();
      legacy++;
    }
    if (client.clientCode != desiredCode) {
      assignments.add(_CodeAssignment(client.id, desiredCode));
    }
  }
  for (final client in duplicateClients) {
    final desiredCode = nextDuplicateCode();
    if (client.clientCode != desiredCode) {
      assignments.add(_CodeAssignment(client.id, desiredCode));
    }
  }

  final firestorePhones = clients
      .map((client) => normalizeLeadNumber(client.phone))
      .where((phone) => phone.isNotEmpty)
      .toSet();
  final csvNotFound = csvCodesByPhone.keys
      .where((phone) => !firestorePhones.contains(phone))
      .length;

  stdout.writeln('Firestore contacts: ${clients.length}');
  stdout.writeln('Unique contacts shown in app: ${primaryClients.length}');
  stdout.writeln('Preserved duplicate documents: ${duplicateClients.length}');
  stdout.writeln('Matched to CSV codes: $matchedCsv');
  stdout.writeln('Legacy/unmatched contacts: $legacy');
  stdout.writeln('CSV contacts not in Firestore: $csvNotFound');
  stdout.writeln('Contacts already correctly coded: '
      '${clients.length - assignments.length}');
  stdout.writeln('Contacts to update: ${assignments.length}');
  for (final assignment in assignments.take(15)) {
    stdout.writeln('  ${assignment.clientId} -> ${assignment.code}');
  }

  if (!arguments.contains('--apply')) {
    stdout.writeln('Preview only. Add --apply to update clientCode fields.');
    return;
  }

  for (var offset = 0; offset < assignments.length; offset += _batchSize) {
    final end = (offset + _batchSize).clamp(0, assignments.length);
    await _commitAssignments(accessToken, assignments.sublist(offset, end));
    stdout.writeln('Updated $end/${assignments.length}');
  }
  await _setNextCodeNumber(accessToken, nextLegacyNumber);
  stdout.writeln('Next automatic client code: '
      'A${nextLegacyNumber.toString().padLeft(4, '0')}');
  stdout.writeln('Code backfill complete. No contacts were deleted.');
}

Set<String> _duplicates(Iterable<String> values) {
  final seen = <String>{};
  return values.where((value) => !seen.add(value)).toSet();
}

Future<String> _gcloudAccessToken() async {
  final executable = Platform.isWindows ? 'gcloud.cmd' : 'gcloud';
  final result = await Process.run(executable, ['auth', 'print-access-token']);
  if (result.exitCode != 0) {
    throw StateError('No active gcloud login is available.');
  }
  return result.stdout.toString().trim();
}

Future<List<_FirestoreClient>> _loadClients(String accessToken) async {
  final clients = <_FirestoreClient>[];
  String? pageToken;
  do {
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/$_databaseId/documents/clients',
      {
        'pageSize': '1000',
        if (pageToken != null) 'pageToken': pageToken,
      },
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw StateError('Could not load Firestore contacts: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    for (final raw in body['documents'] as List<dynamic>? ?? const []) {
      final document = raw as Map<String, dynamic>;
      final fields = document['fields'] as Map<String, dynamic>? ?? const {};
      clients.add(
        _FirestoreClient(
          document['name'].toString().split('/').last,
          _stringValue(fields, 'contactPhone'),
          _stringValue(fields, 'clientCode'),
          _timestampValue(fields, 'createdDate'),
          _timestampValue(fields, 'updatedDate'),
          _timestampValue(fields, 'stageChangedAt'),
        ),
      );
    }
    pageToken = body['nextPageToken']?.toString();
  } while (pageToken != null && pageToken.isNotEmpty);
  return clients;
}

String _stringValue(Map<String, dynamic> fields, String key) =>
    (fields[key] as Map<String, dynamic>?)?['stringValue']?.toString() ?? '';

DateTime? _timestampValue(Map<String, dynamic> fields, String key) {
  final value =
      (fields[key] as Map<String, dynamic>?)?['timestampValue']?.toString();
  return value == null ? null : DateTime.tryParse(value);
}

int _comparePreference(
  _FirestoreClient left,
  _FirestoreClient right,
  String phone,
) {
  final leftIsCanonical = phone.isNotEmpty && left.id == phone;
  final rightIsCanonical = phone.isNotEmpty && right.id == phone;
  if (leftIsCanonical != rightIsCanonical) return leftIsCanonical ? -1 : 1;
  return right.effectiveDate.compareTo(left.effectiveDate);
}

Future<void> _commitAssignments(
  String accessToken,
  List<_CodeAssignment> assignments,
) async {
  final writes = assignments
      .map(
        (assignment) => {
          'update': {
            'name': _documentName('clients/${assignment.clientId}'),
            'fields': {
              'clientCode': {'stringValue': assignment.code},
            },
          },
          'updateMask': {
            'fieldPaths': ['clientCode'],
          },
          'currentDocument': {'exists': true},
        },
      )
      .toList();
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$_projectId/databases/$_databaseId/documents:commit',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'writes': writes}),
  );
  if (response.statusCode != 200) {
    throw StateError('Could not update Firestore contacts: ${response.body}');
  }
}

String _documentName(String path) =>
    'projects/$_projectId/databases/$_databaseId/documents/$path';

class _FirestoreClient {
  final String id;
  final String phone;
  final String clientCode;
  final DateTime? createdDate;
  final DateTime? updatedDate;
  final DateTime? stageChangedAt;

  const _FirestoreClient(
    this.id,
    this.phone,
    this.clientCode,
    this.createdDate,
    this.updatedDate,
    this.stageChangedAt,
  );

  DateTime get effectiveDate =>
      updatedDate ??
      stageChangedAt ??
      createdDate ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

class _CodeAssignment {
  final String clientId;
  final String code;

  const _CodeAssignment(this.clientId, this.code);
}

int _nextSequentialNumber(Iterable<String> codes) {
  var highest = 0;
  for (final code in codes) {
    final match = RegExp(r'^A(\d+)$').firstMatch(code);
    final value = match == null ? null : int.tryParse(match.group(1)!);
    if (value != null && value > highest) highest = value;
  }
  return highest + 1;
}

Map<String, dynamic> _integer(int value) => {
  'integerValue': value.toString(),
};

Future<void> _setNextCodeNumber(String accessToken, int nextValue) async {
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$_projectId/databases/$_databaseId/documents:commit',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'writes': [
        {
          'update': {
            'name': _documentName('systemCounters/clientCodes'),
            'fields': {
              'nextValue': _integer(nextValue),
            },
          },
          'updateMask': {
            'fieldPaths': ['nextValue'],
          },
        },
      ],
    }),
  );
  if (response.statusCode != 200) {
    throw StateError('Could not update client code counter: ${response.body}');
  }
}