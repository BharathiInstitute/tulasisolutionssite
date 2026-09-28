import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tulasisolutionssite/features/chat/lead_csv.dart';

const _projectId = 'newproject1234561';
const _databaseId = '(default)';
const _referenceCollections = [
  'consultations',
  'plans',
  'weekly_reports',
  'payments',
];

Future<void> main(List<String> arguments) async {
  final accessToken = await _gcloudAccessToken();
  final clients = await _loadCollection(accessToken, 'clients');
  final groups = <String, List<_ClientDocument>>{};
  for (final document in clients) {
    final phone = normalizeLeadNumber(document.phone);
    final key = phone.isEmpty ? 'id:${document.id}' : phone;
    groups.putIfAbsent(key, () => []).add(document);
  }

  final duplicateToCanonical = <String, String>{};
  for (final entry in groups.entries) {
    if (entry.value.length < 2 || entry.key.startsWith('id:')) continue;
    final ordered = [...entry.value]
      ..sort((left, right) => _comparePreference(left, right, entry.key));
    for (final duplicate in ordered.skip(1)) {
      duplicateToCanonical[duplicate.id] = ordered.first.id;
    }
  }

  final subcollectionsByClient = <String, List<String>>{};
  final duplicateIds = duplicateToCanonical.keys.toList();
  for (var offset = 0; offset < duplicateIds.length; offset += 25) {
    final end = (offset + 25).clamp(0, duplicateIds.length);
    final batch = duplicateIds.sublist(offset, end);
    final results = await Future.wait(
      batch.map(
        (id) async => MapEntry(
          id,
          await _listCollectionIds(accessToken, 'clients/$id'),
        ),
      ),
    );
    for (final result in results) {
      if (result.value.isNotEmpty) {
        subcollectionsByClient[result.key] = result.value;
      }
    }
  }

  final referencedClients = <String, List<String>>{};
  for (final collection in _referenceCollections) {
    final documents = await _loadCollection(accessToken, collection);
    for (final document in documents) {
      final clientId = _stringValue(document.fields, 'clientId');
      if (duplicateToCanonical.containsKey(clientId)) {
        referencedClients.putIfAbsent(clientId, () => []).add(
          '$collection/${document.id}',
        );
      }
    }
  }

  final subcollectionCounts = <String, int>{};
  for (final collections in subcollectionsByClient.values) {
    for (final collection in collections) {
      subcollectionCounts[collection] =
          (subcollectionCounts[collection] ?? 0) + 1;
    }
  }
  final referenceCounts = <String, int>{};
  for (final references in referencedClients.values) {
    for (final reference in references) {
      final collection = reference.split('/').first;
      referenceCounts[collection] = (referenceCounts[collection] ?? 0) + 1;
    }
  }

  stdout.writeln('Firestore client documents: ${clients.length}');
  stdout.writeln('Unique phone contacts to keep: '
      '${clients.length - duplicateToCanonical.length}');
  stdout.writeln('Duplicate client documents found: '
      '${duplicateToCanonical.length}');
  stdout.writeln('Duplicates with subcollections: '
      '${subcollectionsByClient.length} $subcollectionCounts');
  stdout.writeln('Duplicates referenced by top-level records: '
      '${referencedClients.length} $referenceCounts');
  for (final entry in subcollectionsByClient.entries) {
    stdout.writeln(
      '  related ${entry.key} -> ${duplicateToCanonical[entry.key]}: '
      '${entry.value.join(', ')}',
    );
    for (final collection in entry.value) {
      final sourceDocuments = await _loadCollection(
        accessToken,
        'clients/${entry.key}/$collection',
      );
      final targetDocuments = await _loadCollection(
        accessToken,
        'clients/${duplicateToCanonical[entry.key]}/$collection',
      );
      stdout.writeln(
        '    $collection source=${sourceDocuments.map((doc) => doc.id).toList()} '
        'target=${targetDocuments.map((doc) => doc.id).toList()}',
      );
    }
  }
  for (final entry in duplicateToCanonical.entries.take(10)) {
    stdout.writeln('  delete ${entry.key} -> keep ${entry.value}');
  }

  if (arguments.contains('--apply')) {
    if (referencedClients.isNotEmpty) {
      throw StateError(
        'Deletion blocked: top-level references must be migrated first.',
      );
    }
    final copyWrites = <Map<String, dynamic>>[];
    final relatedDocumentPaths = <String>[];
    for (final entry in subcollectionsByClient.entries) {
      final canonicalId = duplicateToCanonical[entry.key]!;
      for (final collection in entry.value) {
        await _collectCollectionMigration(
          accessToken: accessToken,
          sourceCollectionPath: 'clients/${entry.key}/$collection',
          targetCollectionPath: 'clients/$canonicalId/$collection',
          sourceClientId: entry.key,
          targetClientId: canonicalId,
          writes: copyWrites,
          sourceDocumentPaths: relatedDocumentPaths,
        );
      }
    }
    await _commitWrites(accessToken, copyWrites);
    relatedDocumentPaths.sort(
      (left, right) => right.split('/').length.compareTo(left.split('/').length),
    );
    await _deletePaths(accessToken, relatedDocumentPaths);
    await _deletePaths(
      accessToken,
      duplicateIds.map((id) => 'clients/$id').toList(),
    );
    stdout.writeln('Migrated ${copyWrites.length} related documents.');
    stdout.writeln('Deleted ${duplicateIds.length} duplicate clients.');
  } else {
    stdout.writeln('Preview only. No documents were changed.');
  }
}

Future<String> _gcloudAccessToken() async {
  final executable = Platform.isWindows ? 'gcloud.cmd' : 'gcloud';
  final result = await Process.run(executable, ['auth', 'print-access-token']);
  if (result.exitCode != 0) {
    throw StateError('No active gcloud login is available.');
  }
  return result.stdout.toString().trim();
}

Future<List<_ClientDocument>> _loadCollection(
  String accessToken,
  String collection,
) async {
  final documents = <_ClientDocument>[];
  String? pageToken;
  do {
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/$_databaseId/documents/$collection',
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
      throw StateError('Could not load $collection: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    for (final raw in body['documents'] as List<dynamic>? ?? const []) {
      final document = raw as Map<String, dynamic>;
      final fields = document['fields'] as Map<String, dynamic>? ?? const {};
      documents.add(
        _ClientDocument(
          document['name'].toString().split('/').last,
          fields,
        ),
      );
    }
    pageToken = body['nextPageToken']?.toString();
  } while (pageToken != null && pageToken.isNotEmpty);
  return documents;
}

Future<List<String>> _listCollectionIds(
  String accessToken,
  String documentPath,
) async {
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$_projectId/databases/$_databaseId/documents/'
        '$documentPath:listCollectionIds',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'pageSize': 100}),
  );
  if (response.statusCode != 200) {
    throw StateError('Could not inspect $documentPath: ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return (body['collectionIds'] as List<dynamic>? ?? const [])
      .map((value) => value.toString())
      .toList();
}

Future<void> _collectCollectionMigration({
  required String accessToken,
  required String sourceCollectionPath,
  required String targetCollectionPath,
  required String sourceClientId,
  required String targetClientId,
  required List<Map<String, dynamic>> writes,
  required List<String> sourceDocumentPaths,
}) async {
  final documents = await _loadCollection(accessToken, sourceCollectionPath);
  for (final document in documents) {
    final sourcePath = '$sourceCollectionPath/${document.id}';
    final targetPath = '$targetCollectionPath/${document.id}';
    writes.add({
      'update': {
        'name': _documentName(targetPath),
        'fields': _rewriteClientReferences(
          document.fields,
          sourceClientId,
          targetClientId,
        ),
      },
      'currentDocument': {'exists': false},
    });
    sourceDocumentPaths.add(sourcePath);
    final childCollections = await _listCollectionIds(accessToken, sourcePath);
    for (final childCollection in childCollections) {
      await _collectCollectionMigration(
        accessToken: accessToken,
        sourceCollectionPath: '$sourcePath/$childCollection',
        targetCollectionPath: '$targetPath/$childCollection',
        sourceClientId: sourceClientId,
        targetClientId: targetClientId,
        writes: writes,
        sourceDocumentPaths: sourceDocumentPaths,
      );
    }
  }
}

Map<String, dynamic> _rewriteClientReferences(
  Map<String, dynamic> fields,
  String sourceClientId,
  String targetClientId,
) {
  final rewritten = Map<String, dynamic>.from(fields);
  for (final key in const ['clientId', 'ownerClientId']) {
    final field = rewritten[key];
    if (field is Map<String, dynamic> &&
        field['stringValue'] == sourceClientId) {
      rewritten[key] = {'stringValue': targetClientId};
    }
  }
  return rewritten;
}

Future<void> _commitWrites(
  String accessToken,
  List<Map<String, dynamic>> writes,
) async {
  for (var offset = 0; offset < writes.length; offset += 400) {
    final end = (offset + 400).clamp(0, writes.length);
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
      body: jsonEncode({'writes': writes.sublist(offset, end)}),
    );
    if (response.statusCode != 200) {
      throw StateError('Could not migrate related data: ${response.body}');
    }
  }
}

Future<void> _deletePaths(String accessToken, List<String> paths) async {
  final writes = paths
      .map((path) => {'delete': _documentName(path)})
      .toList();
  await _commitWrites(accessToken, writes);
}

String _documentName(String path) =>
    'projects/$_projectId/databases/$_databaseId/documents/$path';

String _stringValue(Map<String, dynamic> fields, String key) =>
    (fields[key] as Map<String, dynamic>?)?['stringValue']?.toString() ?? '';

DateTime? _timestampValue(Map<String, dynamic> fields, String key) {
  final value =
      (fields[key] as Map<String, dynamic>?)?['timestampValue']?.toString();
  return value == null ? null : DateTime.tryParse(value);
}

int _comparePreference(
  _ClientDocument left,
  _ClientDocument right,
  String phone,
) {
  final leftIsCanonical = left.id == phone;
  final rightIsCanonical = right.id == phone;
  if (leftIsCanonical != rightIsCanonical) return leftIsCanonical ? -1 : 1;
  return right.effectiveDate.compareTo(left.effectiveDate);
}

class _ClientDocument {
  final String id;
  final Map<String, dynamic> fields;

  const _ClientDocument(this.id, this.fields);

  String get phone => _stringValue(fields, 'contactPhone');

  DateTime get effectiveDate =>
      _timestampValue(fields, 'updatedDate') ??
      _timestampValue(fields, 'stageChangedAt') ??
      _timestampValue(fields, 'createdDate') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}