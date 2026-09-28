import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';

import 'lead_csv.dart';
import 'lead_csv_download.dart';
import 'lead_csv_picker.dart';

Future<bool> importLeadFile({
  required BuildContext context,
  required WidgetRef ref,
  required List<Client> clients,
}) async {
  final bytes = await pickLeadCsvBytes();
  if (bytes == null || !context.mounted) return false;

  try {
    final result = parseLeadFile(bytes);
    final chat = ref.read(chatProvider);
    final knownNumbers = <String>{
      ...clients.map((client) => normalizeLeadNumber(client.contactPhone)),
      ...chat.conversations.map(
        (conversation) => normalizeLeadNumber(conversation.contactPhone),
      ),
    }..remove('');
    final knownCodes = clients
        .map((client) => client.clientCode.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ImportPreviewDialog(
        result: result,
        knownNumbers: knownNumbers,
        knownCodes: knownCodes,
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final firestore = ref.read(firestoreServiceProvider);
    final progress = ValueNotifier<_ImportProgress>(
      _ImportProgress(
        total: result.leads.length + result.invalidRows + result.duplicateRows,
        invalid: result.invalidRows,
        duplicateInFile: result.duplicateRows,
      ),
    );
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ImportProgressDialog(progress: progress),
    );

    for (final lead in result.leads) {
      final normalized = normalizeLeadNumber(lead.number);
      final code = lead.code.trim().toUpperCase();
      if (knownNumbers.contains(normalized) ||
          (code.isNotEmpty && knownCodes.contains(code))) {
        progress.value = progress.value.copyWith(
          skipped: progress.value.skipped + 1,
          currentNumber: normalized,
        );
        continue;
      }

      knownNumbers.add(normalized);
      if (code.isNotEmpty) knownCodes.add(code);
      try {
        final created = await firestore.createClientIfAbsent(
          Client(
            id: normalized,
            clientCode: code,
            name: lead.name,
            category: '',
            contactEmail: '',
            contactPhone: lead.number,
            stage: ClientStage.reach,
            createdDate: DateTime.now(),
            stageChangedAt: DateTime.now(),
          ),
        );
        if (!created) {
          progress.value = progress.value.copyWith(
            skipped: progress.value.skipped + 1,
            currentNumber: normalized,
          );
          continue;
        }
        final conversation = await chat.createConversation(
          contactId: normalized,
          contactName: lead.name,
          contactPhone: lead.number,
          ownerClientId: normalized,
        );
        if (conversation == null) {
          await firestore.deleteClient(normalized);
          throw StateError(chat.error ?? 'Could not create chat');
        }
        progress.value = progress.value.copyWith(
          completed: progress.value.completed + 1,
          currentNumber: normalized,
        );
      } catch (error) {
        knownNumbers.remove(normalized);
        if (code.isNotEmpty) knownCodes.remove(code);
        progress.value = progress.value.copyWith(
          failed: progress.value.failed + 1,
          currentNumber: normalized,
          errors: [...progress.value.errors, '$normalized: $error'],
        );
      }
    }

    ref.invalidate(clientsListProvider);
    chat.loadConversations();
    progress.value = progress.value.copyWith(done: true, currentNumber: '');
    await progressDialog;
    progress.dispose();
    return true;
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $error')),
      );
    }
  }
  return false;
}

Future<void> exportLeadFile({
  required BuildContext context,
  required List<Client> clients,
}) async {
  if (clients.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No leads to export.')),
    );
    return;
  }
  try {
    final content = encodeClientExportCsv(clients);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await saveLeadCsv(
      'leads-$date.csv',
      Uint8List.fromList(utf8.encode(content)),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${clients.length} leads exported.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }
}

class _ImportPreviewDialog extends StatelessWidget {
  final LeadCsvImportResult result;
  final Set<String> knownNumbers;
  final Set<String> knownCodes;

  const _ImportPreviewDialog({
    required this.result,
    required this.knownNumbers,
    required this.knownCodes,
  });

  @override
  Widget build(BuildContext context) {
    bool alreadyExists(LeadCsvRow lead) =>
        knownNumbers.contains(normalizeLeadNumber(lead.number)) ||
        (lead.code.isNotEmpty &&
            knownCodes.contains(lead.code.trim().toUpperCase()));
    final existing = result.leads.where(alreadyExists).toList();
    final ready = result.leads.length - existing.length;
    return AlertDialog(
      title: const Text('Review lead import'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('$ready ready'),
                  Text('${existing.length} already exists'),
                  Text('${result.duplicateRows} duplicate rows'),
                  Text('${result.invalidRows} invalid rows'),
                ],
              ),
              if (result.issues.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Rows requiring attention',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final issue in result.issues.take(10))
                  Text(
                    'Row ${issue.rowNumber}: ${issue.reason}'
                    '${issue.number.isEmpty ? '' : ' - ${issue.number}'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text('First records', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final lead in result.leads.take(8))
                Text(
                  '${lead.code.isEmpty ? 'No code' : lead.code} - '
                  '${lead.name} - ${lead.number}',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: ready == 0 ? null : () => Navigator.pop(context, true),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text('Import $ready leads'),
        ),
      ],
    );
  }
}

class _ImportProgress {
  final int total;
  final int completed;
  final int skipped;
  final int duplicateInFile;
  final int failed;
  final int invalid;
  final String currentNumber;
  final List<String> errors;
  final bool done;

  const _ImportProgress({
    required this.total,
    this.completed = 0,
    this.skipped = 0,
    this.duplicateInFile = 0,
    this.failed = 0,
    this.invalid = 0,
    this.currentNumber = '',
    this.errors = const [],
    this.done = false,
  });

  int get processed => completed + skipped + duplicateInFile + failed + invalid;
  int get attempted => completed + failed;
  int get successRate => attempted == 0 ? 100 : (completed * 100 / attempted).round();

  _ImportProgress copyWith({
    int? completed,
    int? skipped,
    int? failed,
    String? currentNumber,
    List<String>? errors,
    bool? done,
  }) => _ImportProgress(
    total: total,
    completed: completed ?? this.completed,
    skipped: skipped ?? this.skipped,
    duplicateInFile: duplicateInFile,
    failed: failed ?? this.failed,
    invalid: invalid,
    currentNumber: currentNumber ?? this.currentNumber,
    errors: errors ?? this.errors,
    done: done ?? this.done,
  );
}

class _ImportProgressDialog extends StatelessWidget {
  final ValueNotifier<_ImportProgress> progress;

  const _ImportProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: progress,
    builder: (context, value, _) {
      final fraction = value.total == 0 ? 1.0 : value.processed / value.total;
      return AlertDialog(
        title: Text(value.done ? 'Import completed' : 'Importing leads'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: fraction.clamp(0, 1)),
              const SizedBox(height: 8),
              Text('${value.processed} of ${value.total} processed'),
              if (value.currentNumber.isNotEmpty) Text(value.currentNumber),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip('Success', value.completed, Colors.green),
                  _CountChip('Skipped', value.skipped, Colors.orange),
                  _CountChip(
                    'Duplicate file rows',
                    value.duplicateInFile,
                    Colors.amber.shade800,
                  ),
                  _CountChip('Invalid', value.invalid, Colors.grey),
                  _CountChip('Errors', value.failed, Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Success rate: ${value.successRate}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (value.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Errors',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 130),
                  child: ListView(
                    shrinkWrap: true,
                    children: value.errors.map(Text.new).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (value.done)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
        ],
      );
    },
  );
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(
      backgroundColor: color,
      child: Text('$count', style: const TextStyle(color: Colors.white)),
    ),
    label: Text(label),
  );
}