import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _projectId = 'newproject1234561';
const _databaseId = '(default)';
const _stageMerges = {'reach': 'click', 'followUp': 'consult'};

Future<void> main(List<String> arguments) async {
  final tokenResult = await Process.run(
    Platform.isWindows ? 'gcloud.cmd' : 'gcloud',
    ['auth', 'print-access-token'],
  );
  if (tokenResult.exitCode != 0) {
    throw StateError('An active gcloud login is required.');
  }
  final token = tokenResult.stdout.toString().trim();
  final client = http.Client();
  try {
    final writes = <Map<String, dynamic>>[];
    final collections = arguments.contains('--clients-only')
        ? ['clients']
        : ['conversations', 'clients'];
    for (final collection in collections) {
      for (final merge in _stageMerges.entries) {
        final documents = await _queryStage(
          client,
          token,
          collection,
          merge.key,
        );
        stdout.writeln(
          '$collection: ${documents.length} ${merge.key} -> ${merge.value}',
        );
        for (final document in documents) {
          writes.add({
            'update': {
              'name': document['name'],
              'fields': {
                'stage': {'stringValue': merge.value},
              },
            },
            'updateMask': {
              'fieldPaths': ['stage'],
            },
            'currentDocument': {'updateTime': document['updateTime']},
          });
        }
      }
    }
    stdout.writeln('Stage-only updates: ${writes.length}');
    if (!arguments.contains('--apply')) {
      stdout.writeln('Preview only. Add --apply to merge the saved stages.');
      return;
    }
    for (var offset = 0; offset < writes.length; offset += 400) {
      final end = (offset + 400).clamp(0, writes.length);
      final response = await client.post(
        _endpoint('commit'),
        headers: _headers(token),
        body: jsonEncode({'writes': writes.sublist(offset, end)}),
      );
      if (response.statusCode != 200) {
        throw StateError('Stage migration stopped: ${response.body}');
      }
      stdout.writeln('Updated $end/${writes.length}');
    }
  } finally {
    client.close();
  }
}

Uri _endpoint(String method) => Uri.https(
  'firestore.googleapis.com',
  '/v1/projects/$_projectId/databases/$_databaseId/documents:$method',
);

Map<String, String> _headers(String token) => {
  'Authorization': 'Bearer $token',
  'Content-Type': 'application/json',
};

Future<List<Map<String, dynamic>>> _queryStage(
  http.Client client,
  String token,
  String collection,
  String stage,
) async {
  final documents = <Map<String, dynamic>>[];
  String? lastName;
  while (true) {
    final response = await client.post(
      _endpoint('runQuery'),
      headers: _headers(token),
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {
              'collectionId': collection,
              'allDescendants': collection == 'conversations',
            },
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'stage'},
              'op': 'EQUAL',
              'value': {'stringValue': stage},
            },
          },
          'orderBy': [
            {
              'field': {'fieldPath': '__name__'},
              'direction': 'ASCENDING',
            },
          ],
          'limit': 500,
          if (lastName != null)
            'startAt': {
              'values': [
                {'referenceValue': lastName},
              ],
              'before': false,
            },
        },
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Could not query $collection/$stage: ${response.body}');
    }
    final page = (jsonDecode(response.body) as List<dynamic>)
        .map((result) => (result as Map<String, dynamic>)['document'])
        .whereType<Map<String, dynamic>>()
        .toList();
    documents.addAll(page);
    if (page.length < 500) return documents;
    lastName = page.last['name'] as String;
  }
}
