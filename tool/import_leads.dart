import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tulasisolutionssite/features/chat/lead_csv.dart';

const _projectId = 'newproject1234561';
const _databaseId = '(default)';
const _batchLeadCount = 200;

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/import_leads.dart <file.xlsx|csv> [--apply]',
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
  final accessToken = await _gcloudAccessToken();
  final existingNumbers = await _loadExistingNumbers(accessToken);
  final newLeads = parsed.leads
      .where(
        (lead) => !existingNumbers.contains(normalizeLeadNumber(lead.number)),
      )
      .toList();

  stdout.writeln('Valid unique rows: ${parsed.leads.length}');
  stdout.writeln('Invalid rows: ${parsed.invalidRows}');
  stdout.writeln('Duplicates in file: ${parsed.duplicateRows}');
  stdout.writeln(
    'Already in Firestore: ${parsed.leads.length - newLeads.length}',
  );
  stdout.writeln('Ready to import: ${newLeads.length}');
  for (final lead in newLeads.take(10)) {
    stdout.writeln('  ${lead.code} | ${lead.name} | ${lead.number}');
  }

  if (!arguments.contains('--apply')) {
    stdout.writeln('Preview only. Add --apply to import these leads.');
    return;
  }

  var imported = 0;
  var skipped = 0;
  var failed = 0;
  for (var offset = 0; offset < newLeads.length; offset += _batchLeadCount) {
    final end = (offset + _batchLeadCount).clamp(0, newLeads.length);
    final batch = newLeads.sublist(offset, end);
    try {
      await _commitLeads(accessToken, batch);
      imported += batch.length;
    } catch (_) {
      for (final lead in batch) {
        try {
          await _commitLeads(accessToken, [lead]);
          imported++;
        } on FirestoreImportException catch (error) {
          if (error.statusCode == 409) {
            skipped++;
          } else {
            failed++;
            stderr.writeln('Failed ${lead.number}: ${error.message}');
          }
        }
      }
    }
    stdout.writeln('Processed $end/${newLeads.length}');
  }

  stdout.writeln(
    'Import complete: $imported imported, $skipped skipped, $failed failed.',
  );
  if (failed > 0) exitCode = 1;
}

Future<String> _gcloudAccessToken() async {
  final executable = Platform.isWindows ? 'gcloud.cmd' : 'gcloud';
  final result = await Process.run(executable, ['auth', 'print-access-token']);
  if (result.exitCode != 0) {
    throw StateError('No active gcloud login is available.');
  }
  return result.stdout.toString().trim();
}

Future<Set<String>> _loadExistingNumbers(String accessToken) async {
  final numbers = <String>{};
  String? pageToken;
  do {
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/$_databaseId/documents/clients',
      {
        'pageSize': '1000',
        'mask.fieldPaths': 'contactPhone',
        if (pageToken != null) 'pageToken': pageToken,
      },
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw FirestoreImportException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    for (final rawDocument in body['documents'] as List<dynamic>? ?? const []) {
      final document = rawDocument as Map<String, dynamic>;
      final fields = document['fields'] as Map<String, dynamic>? ?? const {};
      final phone =
          (fields['contactPhone'] as Map<String, dynamic>?)?['stringValue']
              ?.toString();
      final normalized = normalizeLeadNumber(phone ?? '');
      if (normalized.isNotEmpty) numbers.add(normalized);
      final id = document['name'].toString().split('/').last;
      final normalizedId = normalizeLeadNumber(id);
      if (normalizedId.isNotEmpty) numbers.add(normalizedId);
    }
    pageToken = body['nextPageToken']?.toString();
  } while (pageToken != null && pageToken.isNotEmpty);
  return numbers;
}

Future<void> _commitLeads(String accessToken, List<LeadCsvRow> leads) async {
  final now = DateTime.now().toUtc().toIso8601String();
  final writes = <Map<String, dynamic>>[];
  for (final lead in leads) {
    final phone = normalizeLeadNumber(lead.number);
    final clientName = _documentName('clients/$phone');
    final conversationName = _documentName(
      'clients/$phone/conversations/import-$phone',
    );
    writes.add({
      'update': {
        'name': clientName,
        'fields': {
          'clientCode': _string(lead.code),
          'name': _string(lead.name),
          'category': _string(''),
          'contactEmail': _string(''),
          'contactPhone': _string(lead.number),
          'stage': _string('reach'),
          'createdDate': _timestamp(now),
          'stageChangedAt': _timestamp(now),
          'isArchived': _boolean(false),
          'sendAttemptCount': _integer(0),
          'doNotContact': _boolean(false),
        },
      },
      'currentDocument': {'exists': false},
    });
    writes.add({
      'update': {
        'name': conversationName,
        'fields': {
          'contactId': _string(phone),
          'contactName': _string(lead.name),
          'contactPhone': _string(lead.number),
          'channel': _string('whatsapp'),
          'unreadCount': _integer(0),
          'isActive': _boolean(true),
          'isArchived': _boolean(false),
          'stage': _string('reach'),
          'createdAt': _timestamp(now),
          'lastMessageAt': {'nullValue': null},
        },
      },
      'currentDocument': {'exists': false},
    });
  }

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
    throw FirestoreImportException(response.statusCode, response.body);
  }
}

String _documentName(String path) =>
    'projects/$_projectId/databases/$_databaseId/documents/$path';

Map<String, dynamic> _string(String value) => {'stringValue': value};
Map<String, dynamic> _boolean(bool value) => {'booleanValue': value};
Map<String, dynamic> _integer(int value) => {'integerValue': value.toString()};
Map<String, dynamic> _timestamp(String value) => {'timestampValue': value};

class FirestoreImportException implements Exception {
  final int statusCode;
  final String message;

  const FirestoreImportException(this.statusCode, this.message);

  @override
  String toString() => 'Firestore import failed ($statusCode): $message';
}
