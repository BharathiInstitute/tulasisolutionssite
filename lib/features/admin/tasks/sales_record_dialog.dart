import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/tasks/task_workflow.dart';
import '../../../core/widgets/feature_progress_widgets.dart';
import 'task_deletion_dialog.dart';
import '../../../core/widgets/task_tracking_widgets.dart';
import '../../../core/widgets/retained_task_edits.dart';
import 'customer_sales_record_dialog.dart';

class SalesRecordDialog extends ConsumerStatefulWidget {
  final Client client;
  final List<Plan> plans;
  final SalesTask? initialTask;
  final bool createTask;
  final bool allowDeletion;
  final Map<String, String> retainedEdits;
  final bool replaceFailedSave;
  final bool previewOnly;
  final bool customerRecord;

  const SalesRecordDialog({
    super.key,
    required this.client,
    required this.plans,
    this.initialTask,
    this.createTask = false,
    this.allowDeletion = true,
    this.retainedEdits = const {},
    this.replaceFailedSave = false,
    this.previewOnly = false,
    this.customerRecord = false,
  });

  @override
  ConsumerState<SalesRecordDialog> createState() => _SalesRecordDialogState();
}

class _SalesRecordDialogState extends ConsumerState<SalesRecordDialog> {
  final _notes = TextEditingController();
  final _title = TextEditingController();
  final _nextTitle = TextEditingController();
  bool _scheduleNext = false;
  String _nextAction = 'Call';
  DateTime? _nextDueAt;
  final _newPlanId = const Uuid().v4();
  final _retiredContacts = <_ContactDraft>[];
  late final List<SalesTask> _tasks;
  late final List<_ContactDraft> _contacts;
  late ClientStage _stage;
  int _selectedIndex = -1;
  bool _createTask = false;
  String _action = 'Call';
  String _initialNotes = '';
  DateTime? _dueAt;
  DateTime? _initialDue;
  bool _saving = false;
  bool _showContacts = false;
  String? _error;

  SalesTask? get _task => _selectedIndex < 0 ? null : _tasks[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _stage = widget.client.stage;
    _createTask = widget.createTask;
    _tasks = [
      for (final plan in widget.plans.where(
        (plan) => plan.clientId == widget.client.id,
      ))
        for (final feature in plan.features.toSet())
          if (isSalesTaskFeature(feature)) (plan: plan, feature: feature),
    ];
    if (widget.initialTask != null) {
      _selectedIndex = _tasks.indexWhere(
        (task) =>
            task.plan.id == widget.initialTask!.plan.id &&
            task.feature == widget.initialTask!.feature,
      );
      if (_selectedIndex < 0) {
        _tasks.add(widget.initialTask!);
        _selectedIndex = _tasks.length - 1;
      }
    } else if (!_createTask && _tasks.isNotEmpty) {
      final open = openSalesTasksByClient(
        widget.plans,
      )[widget.client.id]?.firstOrNull;
      _selectedIndex = open == null
          ? 0
          : _tasks.indexWhere(
              (task) =>
                  task.plan.id == open.plan.id && task.feature == open.feature,
            );
    }
    _contacts = widget.client.salesContacts.map(_ContactDraft.new).toList();
    _loadTask();
  }

  void _loadTask() {
    final task = _task;
    _notes.text = _initialNotes = salesRecordNotes(widget.client, task);
    _dueAt = _initialDue = task == null
        ? widget.client.followUpAt
        : taskDueAt(task.plan, task.feature);
    _title.text = task == null
        ? 'Sales follow-up'
        : parseFeature(task.feature).text;
    _action = task == null
        ? 'Call'
        : parseFeatureCategory(
                parseFeature(task.feature).category,
              ).subcategory ??
              'Other';
    _error = null;
  }

  @override
  void dispose() {
    _notes.dispose();
    _title.dispose();
    _nextTitle.dispose();
    for (final contact in [..._contacts, ..._retiredContacts]) {
      contact.notes.dispose();
    }
    super.dispose();
  }

  Future<void> _selectTask(int index) async {
    if (_notes.text != _initialNotes || _dueAt != _initialDue || _scheduleNext) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved task changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _selectedIndex = index;
      _createTask = index < 0;
      _scheduleNext = false;
      _nextTitle.clear();
      _nextDueAt = null;
      _loadTask();
    });
  }

  Future<void> _pickReminder({bool next = false}) async {
    final current = next ? _nextDueAt : _dueAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime((current ?? DateTime.now()).year - 10),
      lastDate: DateTime((current ?? DateTime.now()).year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (time != null && mounted) {
      setState(() {
        final selected = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (next) {
          _nextDueAt = selected;
        } else {
          _dueAt = selected;
        }
      });
    }
  }

  Future<void> _save(bool editCustomer, bool editTask) async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'Your profile is not available. Reopen this task.');
      return;
    }
    if (_createTask && (_title.text.trim().isEmpty || _dueAt == null)) {
      setState(
        () => _error = 'A task title and reminder date/time are required.',
      );
      return;
    }
    Plan? plan = _task?.plan;
    String? feature = _task?.feature;
    if (_scheduleNext &&
        (!editTask || _nextTitle.text.trim().isEmpty || _nextDueAt == null)) {
      setState(() => _error = 'A next follow-up title and date/time are required.');
      return;
    }
    if (_createTask) {
      final base =
          widget.plans
              .where(
                (plan) =>
                    plan.clientId == widget.client.id &&
                    plan.name == 'Sales Tasks',
              )
              .firstOrNull ??
          Plan(
            id: _newPlanId,
            clientId: widget.client.id,
            type: PlanType.setup,
            name: 'Sales Tasks',
            price: 0,
            features: const [],
            startDate: DateTime.now(),
          );
      final task = ClientTask(
        id: const Uuid().v4(),
        category: encodeFeatureCategory(salesFeatureCategory, _action),
        title: _title.text.trim(),
        order: base.tasks.length,
        source: ClientTaskSource.customIncluded,
        addedReason: _notes.text.trim().isEmpty
            ? _title.text.trim()
            : _notes.text.trim(),
      );
      feature = task.feature;
      if (base.features.contains(feature)) {
        setState(() => _error = 'A sales task with this title already exists.');
        return;
      }
      final createdAt = DateTime.now();
      plan = updateTaskAssignment(
        recordTaskCreation(
          base.copyWith(
            features: [...base.features, feature],
            tasks: [...base.tasks, task],
          ),
          feature,
          actor: profile,
          now: createdAt,
        ),
        feature,
        assignedTo: profile.uid,
        assignedToName: profile.name.isEmpty ? profile.email : profile.name,
        priority: 'normal',
        actor: profile,
        now: createdAt,
      );
    }
    String? nextFeature;
    if (_scheduleNext && plan != null) {
      final nextTask = ClientTask(
        id: const Uuid().v4(),
        category: encodeFeatureCategory(salesFeatureCategory, _nextAction),
        title: _nextTitle.text.trim(),
        order: plan.tasks.length,
        source: ClientTaskSource.customIncluded,
        addedReason: 'Next follow-up for ${_title.text.trim()}',
      );
      nextFeature = nextTask.feature;
      if (plan.features.contains(nextFeature)) {
        setState(() => _error = 'A sales task with this title already exists.');
        return;
      }
      plan = updateTaskAssignment(
        recordTaskCreation(
          plan.copyWith(
            features: [...plan.features, nextFeature],
            tasks: [...plan.tasks, nextTask],
          ),
          nextFeature,
          actor: profile,
        ),
        nextFeature,
        assignedTo: profile.uid,
        assignedToName: profile.name.isEmpty ? profile.email : profile.name,
        priority: 'normal',
        actor: profile,
      );
      plan = updateSalesRecordTask(plan, nextFeature, '', _nextDueAt, actor: profile);
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(firestoreServiceProvider);
      final submittedPlan = plan;
      final submittedFeature = feature;
      final addTask = _createTask;
      final notes = _notes.text;
      final dueAt = _dueAt;
      final stage = _stage;
      final contacts = _contacts.map((contact) => contact.toMap()).toList();
      final client = widget.client;
      Future<void> persist() => service.saveSalesRecord(
        client: client,
        plan: submittedPlan,
        feature: submittedFeature,
        addTask: addTask,
        notes: notes,
        dueAt: dueAt,
        stage: stage,
        contacts: contacts,
        editCustomer: editCustomer,
        editTask: editTask,
        actor: profile,
        nextFeature: nextFeature,
      );
      if (submittedPlan != null && submittedFeature != null) {
        final desired = editTask
            ? updateSalesRecordTask(
                submittedPlan,
                submittedFeature,
                notes,
                dueAt,
                actor: profile,
              )
            : submittedPlan;
        ref
            .read(taskSavesProvider.notifier)
            .submit(
              desired: desired,
              previous: widget.plans
                  .where((existing) => existing.id == submittedPlan.id)
                  .firstOrNull,
              label: 'Sales record - ${client.name}',
              persist: persist,
              refreshClientId: client.id,
              workflowKey: submittedFeature,
              lockedAssigneeId: widget.allowDeletion ? null : profile.uid,
              replaceFailed: widget.replaceFailedSave,
              recoveryText: {
                'Sales notes': notes,
                if (nextFeature != null) ...{
                  'Next follow-up title': _nextTitle.text.trim(),
                  'Next follow-up action': _nextAction,
                  'Next follow-up date': _nextDueAt!.toIso8601String(),
                },
                for (var index = 0; index < contacts.length; index++)
                  'Contact ${index + 1} notes':
                      contacts[index]['notes']?.toString() ?? '',
              },
            );
      } else {
        await persist();
        if (!mounted) return;
        ref.invalidate(clientsListProvider);
        ref.invalidate(clientProvider(client.id));
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save sales record: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateLabel(DateTime due) =>
      '${MaterialLocalizations.of(context).formatShortDate(due)} ${TimeOfDay.fromDateTime(due).format(context)}';

  Future<void> _contactCustomer(bool whatsapp) async {
    if (widget.client.doNotContact) {
      setState(() => _error = 'This customer is marked Do not contact.');
      return;
    }
    final phone = widget.client.contactPhone.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() => _error = 'This customer has no usable phone number.');
      return;
    }
    try {
      final uri = whatsapp
          ? Uri.https('wa.me', '/$digits')
          : Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('No compatible application is available.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not open ${whatsapp ? 'WhatsApp' : 'the phone dialer'}: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customerRecord) {
      return CustomerSalesRecordDialog(
        client: ref.read(confirmedSalesClientsProvider)[widget.client.id] ?? widget.client,
        plans: widget.plans,
        previewOnly: widget.previewOnly,
      );
    }
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final manage = profile?.canAccessPanel('tasks') == true;
    final staffIds = manage
        ? const <String>[]
        : ref.watch(currentStaffIdsProvider);
    final editCustomer =
        profile?.canAccessPanel('leads') == true ||
        profile?.canAccessPanel('clients') == true;
    final editTask =
        manage ||
        (_task != null &&
            profile?.canAccessPanel('myTasks') == true &&
            staffIds.contains(taskAssigneeId(_task!.plan, _task!.feature)));
    final identityReady =
        (!_createTask && !_scheduleNext) ||
        ref.watch(currentStaffIdsProvider).contains(profile?.uid);
    final editNotes = editTask || (_task == null && editCustomer);
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.initialTask != null || _createTask ? 'Sales task' : 'Sales record')),
              if (!widget.previewOnly && widget.allowDeletion &&
                  profile?.isAdmin == true &&
                  _task != null &&
                  !_createTask)
                IconButton(
                  tooltip: 'Delete task',
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          final task = _task!;
                          final deleted = await confirmTaskDeletion(
                            context,
                            ref,
                            planId: task.plan.id,
                            feature: task.feature,
                          );
                          if (deleted && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                ),
            ],
          ),
          Text(
            widget.client.name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (widget.client.contactPhone.trim().isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _saving || widget.previewOnly || widget.client.doNotContact ? null : () => _contactCustomer(false),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call customer'),
                ),
                TextButton.icon(
                  onPressed: _saving || widget.previewOnly || widget.client.doNotContact ? null : () => _contactCustomer(true),
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
              RetainedTaskEdits(edits: widget.retainedEdits),
              if (widget.previewOnly)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Example preview: changes are temporary. Saving and contact actions are disabled.'),
                ),
              if (_task != null && !_createTask)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Task history'),
                  children: [
                    TaskTrackingSection(
                      plan: _task!.plan,
                      workflowKey: _task!.feature,
                    ),
                  ],
                ),
              if (_tasks.length > 1 || (_createTask && _tasks.isNotEmpty)) ...[
                DropdownButtonFormField<int>(
                  key: ValueKey('sales-record-selection-$_selectedIndex'),
                  initialValue: _selectedIndex,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sales task'),
                  items: [
                    if (manage || _selectedIndex < 0)
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('New sales task'),
                      ),
                    for (var index = 0; index < _tasks.length; index++)
                      DropdownMenuItem(
                        value: index,
                        child: Text(
                          parseFeature(_tasks[index].feature).text,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving ? null : (index) => _selectTask(index!),
                ),
                const SizedBox(height: 12),
              ],
              if (_task != null || _createTask) ...[
                TextField(
                  key: const ValueKey('sales-record-title'),
                  controller: _title,
                  readOnly: !_createTask || !editTask || _saving,
                  decoration: const InputDecoration(labelText: 'Task title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('sales-record-action-$_selectedIndex'),
                  initialValue: _action,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: [
                    for (final action in {
                      _action,
                      ...planFeatureSubcategories[salesFeatureCategory]!,
                    })
                      DropdownMenuItem(value: action, child: Text(action)),
                  ],
                  onChanged: _createTask && editTask && !_saving
                      ? (action) => setState(() => _action = action!)
                      : null,
                ),
                if (_task != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${salesTaskStatusLabel(_task!)}'),
                        if (manage)
                          Text('Assignee: ${taskAssigneeName(_task!.plan, _task!.feature) ?? taskAssigneeId(_task!.plan, _task!.feature) ?? 'Not assigned'}'),
                        const Text('Task completion is managed in Assign Tasks.'),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ] else if (manage)
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _createTask = true;
                        }),
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('Add sales task'),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('sales-record-reminder'),
                      onPressed: editNotes && !_saving ? _pickReminder : null,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _dueAt == null ? 'Set reminder' : salesTaskDueLabel(context, _dueAt, DateTime.now()),
                      ),
                    ),
                  ),
                  if (_dueAt != null)
                    IconButton(
                      tooltip: 'Clear reminder',
                      icon: const Icon(Icons.event_busy_outlined),
                      onPressed: editNotes && !_saving
                          ? () => setState(() => _dueAt = null)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('sales-record-notes'),
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                readOnly: !editNotes || _saving,
                decoration: const InputDecoration(
                  labelText: 'Sales / follow-up notes',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contact history (${_contacts.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Log contact',
                    icon: const Icon(Icons.add_comment_outlined),
                    onPressed: editCustomer && !_saving
                        ? () {
                            _showContacts = true;
                            setState(
                              () => _contacts.add(
                                _ContactDraft({
                                  'id': const Uuid().v4(),
                                  'method': 'Call',
                                  'outcome': 'Other',
                                  'notes': '',
                                  'recordedBy': profile!.uid,
                                  'at': DateTime.now().toIso8601String(),
                                }),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
              if (_contacts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Latest activity: ${_contacts.last.method} - ${_contacts.last.outcome}'
                    '${_contacts.last.notes.text.trim().isEmpty ? '' : '\n${_contacts.last.notes.text.trim()}'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ExpansionTile(
                key: ValueKey('sales-contact-entries-${_contacts.length}'),
                tilePadding: EdgeInsets.zero,
                title: const Text('Contact entries'),
                initiallyExpanded: _showContacts,
                onExpansionChanged: (expanded) => _showContacts = expanded,
                children: [
              for (final contact in _contacts.reversed)
                ExpansionTile(
                  key: ValueKey(salesContactKey(contact.original)),
                  initiallyExpanded: !widget.client.salesContacts.any(
                    (old) =>
                        salesContactKey(old) ==
                        salesContactKey(contact.original),
                  ),
                  tilePadding: EdgeInsets.zero,
                  title: Text('${contact.method} - ${contact.outcome}'),
                  subtitle: Text(
                    DateTime.tryParse(
                              contact.original['at']?.toString() ?? '',
                            ) ==
                            null
                        ? ''
                        : _dateLabel(
                            DateTime.parse(contact.original['at'].toString()),
                          ),
                  ),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: contact.method,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Contact method',
                      ),
                      items: [
                        for (final method in {
                          contact.method,
                          'Call',
                          'WhatsApp',
                          'Meeting',
                          'Email',
                          'Other',
                        })
                          DropdownMenuItem(value: method, child: Text(method)),
                      ],
                      onChanged: editCustomer && !_saving
                          ? (method) => setState(() => contact.method = method!)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: contact.outcome,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Outcome'),
                      items: [
                        for (final outcome in {
                          contact.outcome,
                          'Interested',
                          'No answer',
                          'Call back',
                          'Asked to call later',
                          'Meeting scheduled',
                          'Not interested',
                          'Proposal requested',
                          'Proposal accepted',
                          'Payment pending',
                          'Renewal discussed',
                          'Referral received',
                          'Other',
                        })
                          DropdownMenuItem(
                            value: outcome,
                            child: Text(outcome),
                          ),
                      ],
                      onChanged: editCustomer && !_saving
                          ? (outcome) =>
                                setState(() => contact.outcome = outcome!)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contact.notes,
                      maxLines: 3,
                      maxLength: 1000,
                      readOnly: !editCustomer || _saving,
                      decoration: const InputDecoration(
                        labelText: 'Contact notes',
                      ),
                    ),
                    if (editCustomer && widget.allowDeletion)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Delete contact entry',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _contacts.remove(contact);
                                  _retiredContacts.add(contact);
                                }),
                        ),
                      ),
                  ],
                ),
                ],
              ),
              if (_task != null && !_createTask && manage) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Schedule next follow-up'),
                  subtitle: const Text('Creates a new task; keeps this task and its history.'),
                  value: _scheduleNext,
                  onChanged: _saving ? null : (value) => setState(() => _scheduleNext = value),
                ),
                if (_scheduleNext) ...[
                  TextField(
                    key: const ValueKey('sales-next-title'),
                    controller: _nextTitle,
                    readOnly: _saving,
                    decoration: const InputDecoration(labelText: 'Next follow-up title'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _nextAction,
                    decoration: const InputDecoration(labelText: 'Next action'),
                    items: [
                      for (final action in planFeatureSubcategories[salesFeatureCategory]!)
                        DropdownMenuItem(value: action, child: Text(action)),
                    ],
                    onChanged: _saving ? null : (value) => setState(() => _nextAction = value!),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('sales-next-reminder'),
                    onPressed: _saving ? null : () => _pickReminder(next: true),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_nextDueAt == null ? 'Set next follow-up date' : _dateLabel(_nextDueAt!)),
                  ),
                  const Text('The new follow-up is assigned to you. This task is not automatically completed.'),
                ],
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Customer details'),
                children: [
                  DropdownButtonFormField<ClientStage>(
                    initialValue: _stage,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sales stage'),
                    items: [
                      for (final stage in chatFunnelStages)
                        DropdownMenuItem(value: stage, child: Text(stage.displayName)),
                    ],
                    onChanged: editCustomer && !_saving
                        ? (stage) => setState(() => _stage = stage!)
                        : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Code: ${widget.client.clientCode}'),
                    subtitle: Text(
                      'Phone: ${widget.client.contactPhone}\nEmail: ${widget.client.contactEmail}\nCategory: ${widget.client.category}',
                    ),
                  ),
                  if (widget.client.ownerName?.isNotEmpty == true)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Business owner'),
                      subtitle: Text(widget.client.ownerName!),
                    ),
                  if (widget.client.alternatePhone?.isNotEmpty == true)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alternate phone'),
                      subtitle: Text(widget.client.alternatePhone!),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Created'),
                    subtitle: Text(_dateLabel(widget.client.createdDate)),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
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
          onPressed: widget.previewOnly || _saving || !identityReady || (!editCustomer && !editTask)
              ? null
              : () => _save(editCustomer, editTask),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.initialTask != null || _createTask ? 'Save changes' : 'Save sales record'),
        ),
      ],
    );
  }
}

class _ContactDraft {
  final Map<String, dynamic> original;
  late String method;
  late String outcome;
  late final TextEditingController notes;
  _ContactDraft(Map<String, dynamic> contact)
    : original = Map<String, dynamic>.from(contact) {
    method = contact['method']?.toString() ?? 'Call';
    outcome = contact['outcome']?.toString() ?? 'Other';
    notes = TextEditingController(text: contact['notes']?.toString() ?? '');
  }
  Map<String, dynamic> toMap() => {
    ...original,
    'method': method,
    'outcome': outcome,
    'notes': notes.text.trim(),
  };
}
