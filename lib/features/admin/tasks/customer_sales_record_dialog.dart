import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/tasks/plan_changes.dart';
import '../../../core/tasks/task_workflow.dart';
import '../../../core/widgets/feature_progress_widgets.dart';
import '../../../core/tasks/sales_record_options.dart';
import '../../../core/widgets/task_tracking_widgets.dart';

class CustomerSalesRecordDialog extends ConsumerStatefulWidget {
  final Client client;
  final List<Plan> plans;
  final bool previewOnly;

  const CustomerSalesRecordDialog({
    super.key,
    required this.client,
    required this.plans,
    this.previewOnly = false,
  });

  @override
  ConsumerState<CustomerSalesRecordDialog> createState() =>
      _CustomerSalesRecordDialogState();
}

class _CustomerSalesRecordDialogState
    extends ConsumerState<CustomerSalesRecordDialog> {
  late ClientStage _stage;
  String? _progress;
  bool _updateChanged = false;
  int _reminderChoiceRevision = 0;
  DateTime? _originalDueAt;
  DateTime? _dueAt;
  late final SalesTask? _legacyTask;
  late final List<SalesTask> _legacyTasks;
  late bool _doNotContact;
  late final TextEditingController _notes;
  bool _saving = false;
  String? _error;
  Object? _saveFailure;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(
      text: widget.client.salesRecord['notes']?.toString() ?? '',
    );
    _legacyTasks = salesTasks(
      widget.plans,
    ).where((task) => task.plan.clientId == widget.client.id).toList();
    final open =
        _legacyTasks
            .where(
              (task) =>
                  !salesTaskIsCompleted(task) &&
                  !taskIsArchived(task.plan, task.feature),
            )
            .toList()
          ..sort(compareSalesTaskDue);
    _legacyTask = widget.client.salesRecord.isEmpty && open.isNotEmpty
        ? open.first
        : null;
    final representative = customerSalesRecords(
      [widget.client],
      widget.plans,
    ).where((task) => task.plan.clientId == widget.client.id).firstOrNull;
    _originalDueAt = representative == null
        ? widget.client.followUpAt
        : taskDueAt(representative.plan, representative.feature);
    _doNotContact = widget.client.doNotContact;
    _stage = widget.client.stage;
    _dueAt = _doNotContact || _stage == ClientStage.lost
        ? null
        : _originalDueAt;
    _progress =
        salesStageUpdates[ClientStage.fromStoredName(_stage.name)]!.contains(
          widget.client.salesProgress,
        )
        ? widget.client.salesProgress
        : null;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final current = _dueAt?.toLocal() ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 10),
      lastDate: DateTime(
        (current.year > now.year ? current.year : now.year) + 10,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _error = null;
    });
  }

  Future<void> _contact(bool whatsapp) async {
    if (_doNotContact || widget.client.doNotContact) {
      setState(() => _error = 'This customer is marked Do not contact.');
      return;
    }
    final phone = widget.client.contactPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.replaceAll('+', '').isEmpty) {
      setState(() => _error = 'This customer has no usable phone number.');
      return;
    }
    try {
      final uri = whatsapp
          ? Uri.https('wa.me', '/${phone.replaceAll('+', '')}')
          : Uri(scheme: 'tel', path: phone);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No compatible application is available.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not open contact action: $error');
      }
    }
  }

  Future<void> _save(AppUser actor) async {
    final dueAt = _dueAt;
    if (dueAt != null &&
        dueAt != _originalDueAt &&
        !dueAt.isAfter(DateTime.now())) {
      setState(
        () => _error =
            'The selected time has passed. Choose a later time or another day.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _saveFailure = null;
    });
    try {
      final saved = await ref
          .read(firestoreServiceProvider)
          .saveCustomerSalesUpdate(
            client: widget.client,
            actor: actor,
            dueAt: _doNotContact || _stage == ClientStage.lost ? null : dueAt,
            stage: _stage,
            legacyTask: _legacyTask,
            doNotContact: _doNotContact,
            progress: _updateChanged ? _progress ?? '' : null,
            notes: _notes.text,
          );
      if (!mounted) return;
      final confirmed = ref.read(confirmedSalesClientsProvider.notifier);
      confirmed.state = {...confirmed.state, saved.id: saved};
      ref.invalidate(clientsListProvider);
      ref.invalidate(taskClientsProvider);
      ref.invalidate(clientProvider(widget.client.id));
      if (mounted) Navigator.pop(context);
    } catch (error, stack) {
      debugPrint('Sales record save failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() {
          _saveFailure = error;
          _error = error is PlanSaveConflict
              ? error.message
              : 'Could not save Sales record: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createReferral(AppUser actor) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final form = GlobalKey<FormState>();
    var saving = false;
    String? error;
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: const Text('Create referred lead'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Referred by ${widget.client.name}. A separate customer record and activity logs will be created.',
                        ),
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'New lead name',
                          ),
                          enabled: !saving,
                          validator: (value) => value?.trim().isNotEmpty == true
                              ? null
                              : 'Enter the lead name.',
                        ),
                        TextFormField(
                          controller: phone,
                          decoration: const InputDecoration(
                            labelText: 'New lead phone',
                          ),
                          keyboardType: TextInputType.phone,
                          enabled: !saving,
                          validator: (value) =>
                              (value ?? '')
                                      .replaceAll(RegExp(r'\D'), '')
                                      .length >=
                                  7
                              ? null
                              : 'Enter a usable phone number.',
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final lead = await ref
                                .read(firestoreServiceProvider)
                                .createReferredLead(
                                  source: widget.client,
                                  actor: actor,
                                  name: name.text,
                                  phone: phone.text,
                                );
                            ref.invalidate(clientsListProvider);
                            ref.invalidate(taskClientsProvider);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Referred lead ${lead.name} created.',
                                  ),
                                ),
                              );
                            }
                          } catch (failure, stack) {
                            debugPrint(
                              'Could not create referred lead: $failure',
                            );
                            debugPrintStack(stackTrace: stack);
                            if (context.mounted) {
                              setDialogState(() {
                                saving = false;
                                error =
                                    'Could not create referred lead: $failure';
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Creating...' : 'Create lead'),
                ),
              ],
            ),
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      name.dispose();
      phone.dispose();
    }
  }

  Future<void> _reopenLatest() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      final latest = await service.getClient(
        widget.client.id,
        serverOnly: true,
      );
      if (latest == null) {
        throw StateError('This customer no longer exists.');
      }
      final plans = [...widget.plans];
      if (latest.salesRecord.isEmpty && _legacyTask != null) {
        final plan = await service.getPlanOnce(_legacyTask.plan.id);
        plans.removeWhere((item) => item.id == _legacyTask.plan.id);
        if (plan != null) plans.add(plan);
      }
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      await showDialog<void>(
        context: navigator.context,
        builder: (_) => CustomerSalesRecordDialog(client: latest, plans: plans),
      );
    } catch (error, stack) {
      debugPrint('Could not reopen Sales record: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _error = 'Could not reopen Sales record: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _log(Map<String, dynamic> entry) {
    String date(Object? value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed == null
          ? 'Not recorded'
          : salesTaskDueLabel(context, parsed, DateTime(1900));
    }

    return ExpansionTile(
      title: Text(
        '${entry['event'] ?? 'Contact'}: ${entry['title'] ?? entry['method'] ?? 'Sales activity'}',
      ),
      subtitle: Text(
        '${entry['recordedByName'] ?? entry['recordedBy'] ?? 'Unknown author'} • ${date(entry['at'])}',
      ),
      children: [
        ListTile(
          title: Text('Outcome: ${entry['outcome'] ?? 'Not recorded'}'),
          subtitle: Text(
            [
              'Action: ${entry['method'] ?? 'Not recorded'}',
              if (entry['customerResponse'] != null)
                'Customer response: ${entry['customerResponse']}',
              if (entry['summary'] != null) 'Summary: ${entry['summary']}',
              if (entry['notes']?.toString().isNotEmpty == true)
                'Previous notes: ${entry['notes']}',
              if (entry['nextStep'] != null) 'Next step: ${entry['nextStep']}',
              if (entry['reminderDays'] != null)
                'Reminder interval: ${salesReminderDays[entry['reminderDays']]}',
              if (entry['doNotContact'] == true)
                'Contact permission: Do not contact',
              if (entry['previousReminder'] != null)
                'Previous reminder: ${date(entry['previousReminder'])}',
              'Next reminder: ${entry['nextReminder'] == null ? 'None' : date(entry['nextReminder'])}',
              if (entry['nextTitle'] != null)
                'Next action: ${entry['nextAction']} - ${entry['nextTitle']}',
              if (entry['stage'] != null)
                'Customer stage: ${ClientStage.fromStoredName(entry['stage'].toString()).displayName}',
              if (entry['previousStage'] != null)
                'Previous stage: ${ClientStage.fromStoredName(entry['previousStage'].toString()).displayName}',
              if (entry['progress']?.toString().isNotEmpty == true)
                'Progress: ${entry['progress']}',
              if (entry['previousProgress']?.toString().isNotEmpty == true)
                'Previous progress: ${entry['previousProgress']}',
              if (entry['referredLeadId'] != null)
                'Referred lead ID: ${entry['referredLeadId']}',
              if (entry['referredByClientId'] != null)
                'Referring customer ID: ${entry['referredByClientId']}',
            ].join('\n'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentUserProfileProvider).valueOrNull;
    final canEdit =
        actor != null &&
        (actor.canAccessPanel('leads') || actor.canAccessPanel('clients'));
    final editable = canEdit && !_saving;
    final canRemind = editable && !_doNotContact && _stage != ClientStage.lost;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales record'),
            Text(
              widget.client.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.client.contactPhone.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed:
                        widget.previewOnly ||
                            _saving ||
                            _doNotContact ||
                            widget.client.doNotContact
                        ? null
                        : () => _contact(false),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call customer'),
                  ),
                  TextButton.icon(
                    onPressed:
                        widget.previewOnly ||
                            _saving ||
                            _doNotContact ||
                            widget.client.doNotContact
                        ? null
                        : () => _contact(true),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ],
              ),
          ],
        ),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.previewOnly)
                  const Text('Example only. Nothing is saved or sent.'),
                if (!canEdit)
                  const Text(
                    'Customer record edit access is required to change this record.',
                  ),
                DropdownButtonFormField<ClientStage>(
                  key: const ValueKey('customer-sales-stage'),
                  initialValue: _stage,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Main stage'),
                  items: [
                    for (final stage in chatFunnelStages)
                      DropdownMenuItem(
                        value: stage,
                        child: Text(stage.displayName),
                      ),
                  ],
                  onChanged: editable
                      ? (value) => setState(() {
                          _stage = value!;
                          _progress = null;
                          _updateChanged = true;
                          if (_stage == ClientStage.lost) {
                            _dueAt = null;
                          }
                        })
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('customer-sales-progress-$_stage'),
                  initialValue: _progress,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Update'),
                  items: [
                    for (final progress
                        in salesStageUpdates[ClientStage.fromStoredName(
                          _stage.name,
                        )]!)
                      DropdownMenuItem(value: progress, child: Text(progress)),
                  ],
                  onChanged: editable
                      ? (value) => setState(() {
                          _progress = value;
                          _updateChanged = true;
                        })
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('customer-sales-notes'),
                  controller: _notes,
                  enabled: editable,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                if ({
                  ClientStage.retain,
                  ClientStage.refer,
                }.contains(widget.client.stage))
                  TextButton.icon(
                    onPressed: editable && !widget.previewOnly
                        ? () => _createReferral(actor)
                        : null,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Create referred lead'),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<bool>(
                  key: ValueKey(
                    'customer-sales-reminder-choice-${_dueAt != null}-$_reminderChoiceRevision',
                  ),
                  initialValue: _dueAt != null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Reminder'),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('No reminder')),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Set date & time'),
                    ),
                  ],
                  onChanged: canRemind
                      ? (value) async {
                          if (value == true) {
                            await _pickReminder();
                            if (mounted) {
                              setState(() => _reminderChoiceRevision++);
                            }
                          } else {
                            setState(() => _dueAt = null);
                          }
                        }
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Do not contact'),
                  value: _doNotContact,
                  onChanged: editable
                      ? (value) => setState(() {
                          _doNotContact = value;
                          if (value) _dueAt = null;
                        })
                      : null,
                ),
                if (_dueAt != null) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    key: const ValueKey('customer-sales-reminder'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      'Reminder: ${MaterialLocalizations.of(context).formatMediumDate(_dueAt!.toLocal())}, '
                      '${TimeOfDay.fromDateTime(_dueAt!.toLocal()).format(context)}',
                    ),
                    onTap: canRemind ? _pickReminder : null,
                    trailing: IconButton(
                      tooltip: 'Clear reminder',
                      icon: const Icon(Icons.clear),
                      onPressed: editable && !_doNotContact
                          ? () => setState(() => _dueAt = null)
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (!widget.previewOnly &&
                    widget.client.salesContacts.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      'Previous contacts (${widget.client.salesContacts.length})',
                    ),
                    children: [
                      for (final entry in widget.client.salesContacts.reversed)
                        _log(entry),
                    ],
                  ),
                if (_legacyTasks.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      'Preserved task history (${_legacyTasks.length})',
                    ),
                    children: [
                      for (final task in _legacyTasks)
                        ExpansionTile(
                          title: Text(parseFeature(task.feature).text),
                          subtitle: Text(
                            '${salesTaskStatusLabel(task)} • ${taskAssigneeName(task.plan, task.feature) ?? 'Not assigned'}',
                          ),
                          children: [
                            Text(taskInternalNotes(task.plan, task.feature)),
                            Text(
                              'Reminder: ${salesTaskDueLabel(context, taskDueAt(task.plan, task.feature), DateTime.now())}',
                            ),
                            TaskTrackingSection(
                              plan: task.plan,
                              workflowKey: task.feature,
                            ),
                          ],
                        ),
                    ],
                  ),
                ExpansionTile(
                  title: const Text('Customer details'),
                  children: [
                    if (widget.client.salesProgress.isNotEmpty)
                      Text('Saved update: ${widget.client.salesProgress}'),
                    if (widget.client.referredByClientId != null)
                      Text(
                        'Referred by customer: ${widget.client.referredByClientId}',
                      ),
                    Text(
                      'Code: ${widget.client.clientCode}\nPhone: ${widget.client.contactPhone}\nEmail: ${widget.client.contactEmail}',
                    ),
                    if (widget.client.notes?.isNotEmpty == true)
                      Text('Customer notes: ${widget.client.notes}'),
                  ],
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saveFailure is PlanSaveConflict) ...[
                  const Text(
                    'Reopening discards these unsaved selections. Review the latest record before saving again.',
                  ),
                  TextButton(
                    onPressed: _saving ? null : _reopenLatest,
                    child: const Text('Reopen latest record'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: !editable || widget.previewOnly
                ? null
                : () => _save(actor),
            child: Text(_saving ? 'Saving...' : 'Save record'),
          ),
        ],
      ),
    );
  }
}
