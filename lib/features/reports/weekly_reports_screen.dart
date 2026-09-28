import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/models/weekly_report.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class WeeklyReportsScreen extends ConsumerStatefulWidget {
  const WeeklyReportsScreen({super.key});

  @override
  ConsumerState<WeeklyReportsScreen> createState() =>
      _WeeklyReportsScreenState();
}

class _WeeklyReportsScreenState extends ConsumerState<WeeklyReportsScreen> {
  String? _selectedClientId;

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsListProvider).valueOrNull ?? const <Client>[];
    final clientId = _selectedClientId;
    final reports = clientId == null
        ? const AsyncValue<List<WeeklyReport>>.data([])
        : ref.watch(weeklyReportsProvider(clientId));
    final plans =
        ref.watch(allPlansStreamProvider).valueOrNull ?? const <Plan>[];
    final selectedClient = clients
        .where((client) => client.id == clientId)
        .firstOrNull;

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/reports',
      title: 'Weekly Reports',
      floatingActionButton: clientId != null
          ? FloatingActionButton.extended(
              onPressed: () => _createReport(
                context,
                clientId,
                selectedClient?.name ?? 'Client',
                plans.where((plan) => plan.clientId == clientId).toList(),
              ),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Create report'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedClientId,
              decoration: const InputDecoration(labelText: 'Client'),
              items: clients
                  .map(
                    (client) => DropdownMenuItem(
                      value: client.id,
                      child: Text(client.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedClientId = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: clientId == null
                  ? const Center(
                      child: Text('Select a client to view reports.'),
                    )
                  : reports.when(
                      loading: () => const LoadingWidget(),
                      error: (error, stackTrace) => CustomErrorWidget(
                        message: 'Could not load reports: $error',
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return const Center(
                            child: Text('No weekly reports yet.'),
                          );
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _ReportCard(report: items[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createReport(
    BuildContext context,
    String clientId,
    String clientName,
    List<Plan> plans,
  ) async {
    final report = await showDialog<WeeklyReport>(
      context: context,
      builder: (_) => _CreateWeeklyReportDialog(
        clientId: clientId,
        clientName: clientName,
        plans: plans,
      ),
    );
    if (report == null) return;
    try {
      await ref.read(firestoreServiceProvider).saveWeeklyReport(report);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weekly report published')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish report: $error')),
        );
      }
    }
  }
}

class _CreateWeeklyReportDialog extends StatefulWidget {
  final String clientId;
  final String clientName;
  final List<Plan> plans;

  const _CreateWeeklyReportDialog({
    required this.clientId,
    required this.clientName,
    required this.plans,
  });

  @override
  State<_CreateWeeklyReportDialog> createState() =>
      _CreateWeeklyReportDialogState();
}

class _CreateWeeklyReportDialogState extends State<_CreateWeeklyReportDialog> {
  final _summaryController = TextEditingController();

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed = <String>[];
    final inProgress = <String>[];
    final awaitingApproval = <String>[];
    for (final plan in widget.plans) {
      for (final feature in plan.features) {
        final status = taskStatus(plan, feature);
        final text = _taskLabel(feature);
        if (status == TaskStatus.completed) {
          completed.add(text);
        } else if (draftCycleStage(plan, feature) ==
            DraftCycleStage.confirmation) {
          awaitingApproval.add(text);
        } else if (status != TaskStatus.notAssigned &&
            status != TaskStatus.assigned) {
          inProgress.add(text);
        }
      }
    }
    final end = DateUtils.dateOnly(DateTime.now());
    final start = end.subtract(const Duration(days: 6));
    return AlertDialog(
      title: Text('Weekly report: ${widget.clientName}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}',
              ),
              const SizedBox(height: 12),
              Text(
                '${completed.length} completed | ${inProgress.length} in progress | ${awaitingApproval.length} awaiting approval',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _summaryController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Client-facing weekly summary',
                  hintText: 'Progress, outcomes, and next steps for this week',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            WeeklyReport(
              id: const Uuid().v4(),
              clientId: widget.clientId,
              periodStart: start,
              periodEnd: end,
              completedWork: completed,
              inProgressWork: inProgress,
              awaitingApprovalWork: awaitingApproval,
              summary: _summaryController.text,
              published: true,
              createdAt: DateTime.now(),
              publishedAt: DateTime.now(),
            ),
          ),
          child: const Text('Publish report'),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final WeeklyReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text('Week ending ${DateFormat.yMMMd().format(report.periodEnd)}'),
      subtitle: Text(report.published ? 'Published' : 'Draft'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (report.summary.isNotEmpty)
          Align(alignment: Alignment.centerLeft, child: Text(report.summary)),
        _ReportItems(title: 'Completed', items: report.completedWork),
        _ReportItems(title: 'In progress', items: report.inProgressWork),
        _ReportItems(
          title: 'Awaiting approval',
          items: report.awaitingApprovalWork,
        ),
      ],
    ),
  );
}

class _ReportItems extends StatelessWidget {
  final String title;
  final List<String> items;

  const _ReportItems({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final item in items) Text('• $item'),
        ],
      ),
    );
  }
}

String _taskLabel(String feature) {
  final separator = feature.indexOf(': ');
  return separator < 0 ? feature : feature.substring(separator + 2);
}
