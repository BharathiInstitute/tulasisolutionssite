import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _projectId = 'newproject1234561';
const _databaseId = '(default)';
const _batchSize = 400;

Future<void> main(List<String> arguments) async {
  final accessToken = await _gcloudAccessToken();
  final clientDocuments = await _queryStage(
    accessToken,
    collectionId: 'clients',
    allDescendants: false,
  );
  final conversationDocuments = await _queryStage(
    accessToken,
    collectionId: 'conversations',
    allDescendants: true,
  );
  final documents = [...clientDocuments, ...conversationDocuments];

  stdout.writeln('Legacy Refer clients: ${clientDocuments.length}');
  stdout.writeln('Legacy Refer conversations: ${conversationDocuments.length}');
  stdout.writeln('Documents to update: ${documents.length}');
  for (final document in documents.take(10)) {
    stdout.writeln('  ${document.split('/documents/').last}');
  }

  if (!arguments.contains('--apply')) {
    stdout.writeln('Preview only. Add --apply to merge them into Retain / Refer.');
    return;
  }

  for (var offset = 0; offset < documents.length; offset += _batchSize) {
    final end = (offset + _batchSize).clamp(0, documents.length);
    await _commit(accessToken, documents.sublist(offset, end));
    stdout.writeln('Updated $end/${documents.length}');
  }
  stdout.writeln('Retain / Refer migration complete.');
}

Future<String> _gcloudAccessToken() async {
  final executable = Platform.isWindows ? 'gcloud.cmd' : 'gcloud';
  final result = await Process.run(executable, ['auth', 'print-access-token']);
  if (result.exitCode != 0) {
    throw StateError('No active gcloud login is available.');
  }
  return result.stdout.toString().trim();
}

Future<List<String>> _queryStage(
  String accessToken, {
  required String collectionId,
  required bool allDescendants,
}) async {
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$_projectId/databases/$_databaseId/documents:runQuery',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'structuredQuery': {
        'from': [
          {
            'collectionId': collectionId,
            'allDescendants': allDescendants,
          },
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'stage'},
            'op': 'EQUAL',
            'value': {'stringValue': 'refer'},
          },
        },
      },
    }),
  );
  if (response.statusCode == 400 &&
      collectionId == 'conversations' &&
      allDescendants) {
    return _findLegacyConversations(accessToken);
  }
  if (response.statusCode != 200) {
    throw StateError('Could not query $collectionId: ${response.body}');
  }
  final results = jsonDecode(response.body) as List<dynamic>;
  return results
      .map((result) => result as Map<String, dynamic>)
      .map((result) => result['document'] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .map((document) => document['name'].toString())
      .toList();
}

Future<List<String>> _findLegacyConversations(String accessToken) async {
  final clientNames = await _listDocuments(accessToken, 'clients');
  final matches = <String>[];
  for (var offset = 0; offset < clientNames.length; offset += 40) {
    final end = (offset + 40).clamp(0, clientNames.length);
    final results = await Future.wait(
      clientNames.sublist(offset, end).map((clientName) async {
        final clientId = clientName.split('/').last;
        return _listDocuments(
          accessToken,
          'clients/$clientId/conversations',
          stage: 'refer',
        );
      }),
    );
    matches.addAll(results.expand((documents) => documents));
  }
  return matches;
}

Future<List<String>> _listDocuments(
  String accessToken,
  String collectionPath, {
  String? stage,
}) async {
  final documents = <String>[];
  String? pageToken;
  do {
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/$_databaseId/documents/'
          '$collectionPath',
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
      throw StateError('Could not list $collectionPath: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    for (final raw in body['documents'] as List<dynamic>? ?? const []) {
      final document = raw as Map<String, dynamic>;
      final fields = document['fields'] as Map<String, dynamic>? ?? const {};
      final documentStage =
          (fields['stage'] as Map<String, dynamic>?)?['stringValue'];
      if (stage == null || documentStage == stage) {
        documents.add(document['name'].toString());
      }
    }
    pageToken = body['nextPageToken']?.toString();
  } while (pageToken != null && pageToken.isNotEmpty);
  return documents;
}

Future<void> _commit(String accessToken, List<String> documents) async {
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
      'writes': documents
          .map(
            (name) => {
              'update': {
                'name': name,
                'fields': {
                  'stage': {'stringValue': 'retain'},
                },
              },
              'updateMask': {
                'fieldPaths': ['stage'],
              },
              'currentDocument': {'exists': true},
            },
          )
          .toList(),
    }),
  );
  if (response.statusCode != 200) {
    throw StateError('Could not update stages: ${response.body}');
  }
}