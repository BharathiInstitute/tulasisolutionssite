import '../models/models.dart';
import '../constants/enums.dart';
import '../widgets/feature_progress_widgets.dart';

typedef SalesTask = ({Plan plan, String feature});

bool canReadSalesTasks(AppUser? profile) => [
  'tasks',
  'myTasks',
  'plans',
  'myDashboard',
].any((panel) => profile?.canAccessPanel(panel) == true);

enum SalesQueue { today, overdue, upcoming, noNextAction }

enum SalesTaskQueue {
  todayAndOverdue,
  upcoming,
  unscheduled,
  active,
  completed,
}

enum TaskDueFilter { todayAndOverdue, upcoming, unscheduled }

bool matchesTaskDueFilter(
  Plan plan,
  String key,
  TaskDueFilter filter,
  DateTime now,
) {
  final due = taskDueAt(plan, key)?.toLocal();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return switch (filter) {
    TaskDueFilter.todayAndOverdue => due != null && due.isBefore(tomorrow),
    TaskDueFilter.upcoming => due != null && !due.isBefore(tomorrow),
    TaskDueFilter.unscheduled => due == null,
  };
}

List<SalesTask> salesTasks(Iterable<Plan> plans) => [
  for (final plan in plans)
    for (final feature in plan.features.toSet())
      if (isSalesTaskFeature(feature)) (plan: plan, feature: feature),
];

List<SalesTask> customerSalesRecords(List<Client> clients, List<Plan> plans) {
  final grouped = <String, List<SalesTask>>{};
  for (final task in salesTasks(plans)) {
    grouped.putIfAbsent(task.plan.clientId, () => []).add(task);
  }
  final result = <SalesTask>[];
  for (final client in clients) {
    final record = client.salesRecord;
    if (record.isNotEmpty || (client.followUpAt != null && !grouped.containsKey(client.id))) {
      final feature = 'Sales / ${record['action'] ?? 'Call'}: ${record['title'] ?? 'Sales follow-up'}';
      final plan = Plan(
        id: 'customer-sales-${client.id}',
        clientId: client.id,
        type: PlanType.setup,
        name: 'Customer Sales record',
        price: 0,
        startDate: client.createdDate,
        features: [feature],
        taskWorkflow: {
          feature: {
            'status': record['status'] ?? 'assigned',
            'assignedTo': record['assignedTo'] ?? client.assignedManager,
            'assignedToName': record['assignedToName'],
            'dueAt': record['dueAt'] ?? client.followUpAt?.toIso8601String(),
            'internalNotes': record['notes'] ?? client.followUpNotes ?? client.notes ?? '',
          },
        },
      );
      result.add((plan: plan, feature: feature));
      grouped.remove(client.id);
    }
  }
  for (final tasks in grouped.values) {
    final active = tasks.where((task) => !taskIsArchived(task.plan, task.feature) && !salesTaskIsCompleted(task)).toList()
      ..sort(compareSalesTaskDue);
    final completed = tasks.where((task) => !taskIsArchived(task.plan, task.feature)).toList()
      ..sort(compareSalesTaskDue);
    result.add(active.isNotEmpty ? active.first : completed.isNotEmpty ? completed.first : tasks.first);
  }
  return result..sort(compareSalesTaskDue);
}

bool salesTaskIsCompleted(SalesTask task) =>
    taskStatus(task.plan, task.feature) == TaskStatus.completed ||
    task.plan.completedFeatures.contains(task.feature);

String salesTaskStatusLabel(SalesTask task) => salesTaskIsCompleted(task)
    ? 'Completed'
    : switch (taskStatus(task.plan, task.feature)) {
        TaskStatus.notAssigned => 'Not assigned',
        TaskStatus.assigned => 'Assigned',
        TaskStatus.started => 'In progress',
        TaskStatus.draftCycle => 'Draft cycle',
        TaskStatus.completed => 'Completed',
      };

bool matchesSalesTaskQueue(SalesTask task, SalesTaskQueue queue, DateTime now) {
  if (taskIsArchived(task.plan, task.feature)) return false;
  final completed = salesTaskIsCompleted(task);
  if (queue == SalesTaskQueue.completed) return completed;
  if (completed) return false;
  return switch (queue) {
    SalesTaskQueue.todayAndOverdue => matchesTaskDueFilter(
      task.plan,
      task.feature,
      TaskDueFilter.todayAndOverdue,
      now,
    ),
    SalesTaskQueue.upcoming => matchesTaskDueFilter(
      task.plan,
      task.feature,
      TaskDueFilter.upcoming,
      now,
    ),
    SalesTaskQueue.unscheduled => matchesTaskDueFilter(
      task.plan,
      task.feature,
      TaskDueFilter.unscheduled,
      now,
    ),
    SalesTaskQueue.active => true,
    SalesTaskQueue.completed => false,
  };
}

int compareSalesTaskDue(SalesTask left, SalesTask right) {
  final a = taskDueAt(left.plan, left.feature);
  final b = taskDueAt(right.plan, right.feature);
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

bool isSalesTaskFeature(String feature) =>
    parseFeatureCategory(parseFeature(feature).category).category ==
    salesFeatureCategory;

String salesRecordNotes(Client client, SalesTask? task) {
  var notes = task == null
      ? ''
      : taskInternalNotes(task.plan, task.feature).trim();
  if (task != null &&
      task.plan.taskWorkflow[task.feature]?['salesRecordMerged'] == true) {
    return notes;
  }
  for (final legacy in [client.notes, client.followUpNotes]) {
    final text = legacy?.trim() ?? '';
    if (text.isNotEmpty && !notes.contains(text)) {
      notes = notes.isEmpty ? text : '$notes\n\n$text';
    }
  }
  return notes;
}

Map<String, List<SalesTask>> openSalesTasksByClient(Iterable<Plan> plans) {
  final grouped = <String, List<SalesTask>>{};
  for (final plan in plans) {
    for (final feature in plan.features.toSet()) {
      if (!isSalesTaskFeature(feature) ||
          taskIsArchived(plan, feature) ||
          taskStatus(plan, feature) == TaskStatus.completed ||
          plan.completedFeatures.contains(feature)) {
        continue;
      }
      grouped.putIfAbsent(plan.clientId, () => []).add((
        plan: plan,
        feature: feature,
      ));
    }
  }
  for (final tasks in grouped.values) {
    tasks.sort((left, right) {
      final leftDue = taskDueAt(left.plan, left.feature);
      final rightDue = taskDueAt(right.plan, right.feature);
      if (leftDue == null) return rightDue == null ? 0 : 1;
      if (rightDue == null) return -1;
      return leftDue.compareTo(rightDue);
    });
  }
  return grouped;
}

String salesContactKey(Map<String, dynamic> contact) =>
    contact['id']?.toString() ?? '${contact['at']}|${contact['recordedBy']}';

List<Map<String, dynamic>> mergeSalesRecordContacts(
  List<Map<String, dynamic>> current,
  List<Map<String, dynamic>> baseline,
  List<Map<String, dynamic>> edited,
) {
  final result = current
      .map((contact) => Map<String, dynamic>.from(contact))
      .toList();
  for (final original in baseline) {
    final key = salesContactKey(original);
    final replacement = edited
        .where((contact) => salesContactKey(contact) == key)
        .firstOrNull;
    final changed =
        replacement == null ||
        [
          'method',
          'outcome',
          'notes',
        ].any((field) => replacement[field] != original[field]);
    if (!changed) continue;
    final matches = result
        .where((contact) => salesContactKey(contact) == key)
        .toList();
    if (matches.length != 1 ||
        [
          'method',
          'outcome',
          'notes',
        ].any((field) => matches.single[field] != original[field])) {
      throw StateError(
        'Contact history changed. Reopen the sales record before saving.',
      );
    }
    final index = result.indexOf(matches.single);
    if (replacement == null) {
      result.removeAt(index);
    } else {
      result[index] = {
        ...matches.single,
        for (final field in ['method', 'outcome', 'notes'])
          field: replacement[field],
      };
    }
  }
  final previousKeys = baseline.map(salesContactKey).toSet();
  for (final contact in edited.where(
    (contact) => !previousKeys.contains(salesContactKey(contact)),
  )) {
    if (!result.any(
      (saved) => salesContactKey(saved) == salesContactKey(contact),
    )) {
      result.add(Map<String, dynamic>.from(contact));
    }
  }
  return result.length > 50 ? result.sublist(result.length - 50) : result;
}

Plan updateSalesRecordTask(
  Plan plan,
  String feature,
  String notes,
  DateTime? dueAt, {
  AppUser? actor,
}) {
  final updated = updateTaskManagementDetails(
    plan,
    feature,
    dueAt: dueAt,
    internalNotes: notes,
    actor: actor,
  );
  return updated.copyWith(
    taskWorkflow: {
      ...updated.taskWorkflow,
      feature: {...?updated.taskWorkflow[feature], 'salesRecordMerged': true},
    },
  );
}

bool matchesSalesQueue(
  Client client,
  List<SalesTask> tasks,
  SalesQueue queue,
  DateTime now,
) {
  final dates = tasks
      .map((task) => taskDueAt(task.plan, task.feature))
      .whereType<DateTime>();
  DateTime? nextDue;
  for (final due in dates) {
    if (nextDue == null || due.isBefore(nextDue)) nextDue = due;
  }
  nextDue ??= client.followUpAt;
  if (nextDue == null) return queue == SalesQueue.noNextAction;
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return switch (queue) {
    SalesQueue.today => !nextDue.isBefore(today) && nextDue.isBefore(tomorrow),
    SalesQueue.overdue => nextDue.isBefore(today),
    SalesQueue.upcoming => !nextDue.isBefore(tomorrow),
    SalesQueue.noNextAction => false,
  };
}

String taskKey(String rawFeature, int? unitIndex) =>
    unitIndex == null ? rawFeature : '$rawFeature#$unitIndex';

Plan removePlanTask(Plan plan, String feature) {
  if (!plan.features.contains(feature)) {
    throw StateError('Task no longer exists. Refresh the task list.');
  }
  bool belongsToTask(String key) =>
      key == feature || key.startsWith('$feature#');
  return plan.copyWith(
    features: plan.features.where((value) => value != feature).toList(),
    tasks: plan.tasks.where((task) => task.feature != feature).toList(),
    completedFeatures: plan.completedFeatures
        .where((key) => !belongsToTask(key))
        .toList(),
    featureProgress: {
      for (final entry in plan.featureProgress.entries)
        if (!belongsToTask(entry.key)) entry.key: entry.value,
    },
    taskWorkflow: {
      for (final entry in plan.taskWorkflow.entries)
        if (!belongsToTask(entry.key)) entry.key: entry.value,
    },
  );
}

Plan renamePlanTask(
  Plan plan,
  String oldFeature, {
  required String category,
  required String title,
}) {
  final newFeature = encodePlanTaskFeature(category, title);
  if (newFeature == oldFeature) return plan;

  String migrateKey(String key) {
    if (key == oldFeature) return newFeature;
    final unitPrefix = '$oldFeature#';
    return key.startsWith(unitPrefix)
        ? '$newFeature#${key.substring(unitPrefix.length)}'
        : key;
  }

  final tasks = [
    for (final task in plan.tasks)
      if (task.feature == oldFeature)
        ClientTask(
          id: task.id,
          category: category,
          title: title,
          instructions: task.instructions,
          order: task.order,
          source: task.source,
          templateTaskId: task.templateTaskId,
          addedReason: task.addedReason,
        )
      else
        task,
  ];
  return plan.copyWith(
    features: [
      for (final feature in plan.features)
        if (feature == oldFeature) newFeature else feature,
    ],
    tasks: tasks,
    completedFeatures: [
      for (final feature in plan.completedFeatures)
        if (feature == oldFeature) newFeature else feature,
    ],
    featureProgress: {
      for (final entry in plan.featureProgress.entries)
        migrateKey(entry.key): entry.value,
    },
    taskWorkflow: {
      for (final entry in plan.taskWorkflow.entries)
        migrateKey(entry.key): Map<String, dynamic>.from(entry.value),
    },
  );
}

TaskStatus taskStatus(Plan plan, String key) {
  final raw = currentTaskCycle(plan, key)['status']?.toString();
  if (raw == TaskStatus.completed.name) return TaskStatus.completed;
  if (taskAssigneeId(plan, key) == null) return TaskStatus.notAssigned;
  return switch (raw) {
    'started' => TaskStatus.started,
    'draft' ||
    'inProgress' ||
    'awaitingConfirmation' ||
    'draftCycle' => TaskStatus.draftCycle,
    _ => TaskStatus.assigned,
  };
}

DraftCycleStage draftCycleStage(Plan plan, String key) {
  final cycle = currentTaskCycle(plan, key);
  final raw = cycle['draftStage']?.toString();
  for (final stage in DraftCycleStage.values) {
    if (stage.name == raw) return stage;
  }
  return switch (cycle['status']?.toString()) {
    'inProgress' => DraftCycleStage.working,
    'awaitingConfirmation' => DraftCycleStage.confirmation,
    _ => DraftCycleStage.instructions,
  };
}

String taskText(Plan plan, String key, String field) =>
    currentTaskCycle(plan, key)[field]?.toString() ?? '';

String taskPriority(Plan plan, String key) =>
    plan.taskWorkflow[key]?['priority']?.toString() ?? 'normal';

String? taskAssigneeId(Plan plan, String key) {
  final value = plan.taskWorkflow[key]?['assignedTo']?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

String? taskAssigneeName(Plan plan, String key) {
  final value =
      plan.taskWorkflow[key]?['assignedToName']?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

String taskInternalNotes(Plan plan, String key) =>
    plan.taskWorkflow[key]?['internalNotes']?.toString() ?? '';

bool taskIsArchived(Plan plan, String key) =>
    plan.taskWorkflow[key]?['isArchived'] == true;

Plan setTaskArchived(Plan plan, String key, bool isArchived) {
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };
  workflow[key] = {
    ...?workflow[key],
    'isArchived': isArchived,
    'updatedAt': DateTime.now().toIso8601String(),
  };
  return plan.copyWith(taskWorkflow: workflow);
}

DateTime? _taskDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final converted = value?.toDate();
    return converted is DateTime ? converted : null;
  } catch (_) {
    return null;
  }
}

DateTime? taskStartedAt(Plan plan, String key) =>
    _taskDateTime(plan.taskWorkflow[key]?['startedAt']);

DateTime? taskCompletedAt(Plan plan, String key) =>
    _taskDateTime(plan.taskWorkflow[key]?['completedAt']);

DateTime? taskDueAt(Plan plan, String key) =>
    _taskDateTime(plan.taskWorkflow[key]?['dueAt']);

Map<String, String> _trackingActor(AppUser actor) => {
  'uid': actor.uid,
  'name': actor.name.isEmpty ? actor.email : actor.name,
};

Plan recordTaskCreation(
  Plan plan,
  String key, {
  AppUser? actor,
  DateTime? now,
}) {
  if (plan.taskWorkflow[key]?['createdAt'] != null) return plan;
  return plan.copyWith(
    taskWorkflow: {
      ...plan.taskWorkflow,
      key: {
        ...?plan.taskWorkflow[key],
        'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
        if (actor != null) 'createdBy': _trackingActor(actor),
      },
    },
  );
}

typedef TaskTrackingEvent = ({String label, DateTime at, String? by});

List<TaskTrackingEvent> taskTrackingEvents(Plan plan, String key) {
  final workflow = plan.taskWorkflow[key] ?? const <String, dynamic>{};
  final baseKey = plan.features
      .where((feature) => key.startsWith('$feature#'))
      .firstOrNull;
  final creation = workflow['createdAt'] != null
      ? workflow
      : plan.taskWorkflow[baseKey] ?? workflow;
  final events = <TaskTrackingEvent>[];
  void add(
    String label,
    Map<String, dynamic> data,
    String dateField,
    String actorField,
  ) {
    final at = _taskDateTime(data[dateField]);
    if (at == null) return;
    final actor = data[actorField];
    final name = actor is Map ? actor['name']?.toString() : null;
    final uid = actor is Map ? actor['uid']?.toString() : null;
    events.add((
      label: label,
      at: at,
      by: name?.isNotEmpty == true ? name : uid,
    ));
  }

  final createdAt = _taskDateTime(creation['createdAt']);
  final assignedAt = _taskDateTime(workflow['assignedAt']);
  add(
    createdAt != null && assignedAt == createdAt
        ? 'Created / assigned'
        : 'Created',
    creation,
    'createdAt',
    'createdBy',
  );
  if (assignedAt != createdAt) {
    add('Assigned', workflow, 'assignedAt', 'assignedBy');
  }
  add('Due', workflow, 'dueAt', 'dueBy');
  add('First started', workflow, 'firstStartedAt', 'firstStartedBy');
  for (final cycle in taskCycles(plan, key)) {
    final number = cycle['cycle'];
    final prefix = number == null ? '' : 'Draft $number - ';
    if (number != null) {
      add('${prefix}Created', cycle, 'createdAt', 'createdBy');
    }
    add(
      '${prefix}Sent for admin approval',
      cycle,
      'sentToAdminAt',
      'sentToAdminBy',
    );
    add(
      '${prefix}Sent for client approval',
      cycle,
      'sentToClientAt',
      'sentToClientBy',
    );
    if (cycle['completedAt'] != workflow['completedAt']) {
      add('${prefix}Completed', cycle, 'completedAt', 'completedBy');
    }
  }
  if (taskStatus(plan, key) == TaskStatus.completed) {
    add('Completed', workflow, 'completedAt', 'completedBy');
  }
  return events;
}

bool taskTimerIsRunning(Plan plan, String key) {
  final workflow = plan.taskWorkflow[key];
  if (workflow?['timerRunning'] is bool) {
    return workflow!['timerRunning'] == true;
  }
  return taskStartedAt(plan, key) != null && taskCompletedAt(plan, key) == null;
}

Duration taskElapsedBeforeCurrentRun(Plan plan, String key) {
  final savedMilliseconds =
      (plan.taskWorkflow[key]?['elapsedMilliseconds'] as num?)?.toInt() ?? 0;
  return Duration(milliseconds: savedMilliseconds);
}

Duration? taskElapsedTime(Plan plan, String key, {DateTime? now}) {
  final workflow = plan.taskWorkflow[key];
  final savedMilliseconds = (workflow?['elapsedMilliseconds'] as num?)?.toInt();
  final startedAt = taskStartedAt(plan, key);
  if (savedMilliseconds != null) {
    final saved = Duration(milliseconds: savedMilliseconds);
    if (!taskTimerIsRunning(plan, key) || startedAt == null) return saved;
    final current = (now ?? DateTime.now()).difference(startedAt);
    return saved + (current.isNegative ? Duration.zero : current);
  }
  if (startedAt == null) return null;
  final stoppedAt = taskCompletedAt(plan, key) ?? now ?? DateTime.now();
  final elapsed = stoppedAt.difference(startedAt);
  return elapsed.isNegative ? Duration.zero : elapsed;
}

Plan setTaskTimerRunning(
  Plan plan,
  String key,
  bool isRunning, {
  DateTime? now,
  AppUser? actor,
}) {
  if (taskTimerIsRunning(plan, key) == isRunning) return plan;
  final changedAt = now ?? DateTime.now();
  final elapsed = taskElapsedTime(plan, key, now: changedAt) ?? Duration.zero;
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };
  workflow[key] = {
    ...?workflow[key],
    'timerRunning': isRunning,
    'elapsedMilliseconds': elapsed.inMilliseconds,
    'startedAt': isRunning ? changedAt.toIso8601String() : null,
    if (isRunning &&
        workflow[key]?['firstStartedAt'] == null &&
        taskStartedAt(plan, key) == null &&
        taskElapsedBeforeCurrentRun(plan, key) == Duration.zero) ...{
      'firstStartedAt': changedAt.toUtc().toIso8601String(),
      if (actor != null) 'firstStartedBy': _trackingActor(actor),
    },
    'completedAt': null,
    'updatedAt': changedAt.toIso8601String(),
  };
  final updated = plan.copyWith(taskWorkflow: workflow);
  return isRunning && taskStatus(plan, key) == TaskStatus.assigned
      ? setTaskStatus(
          updated,
          key,
          TaskStatus.started,
          now: changedAt,
          actor: actor,
        )
      : updated;
}

Plan setTaskStatus(
  Plan plan,
  String key,
  TaskStatus status, {
  DateTime? now,
  AppUser? actor,
}) {
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };
  final current = Map<String, dynamic>.from(workflow[key] ?? const {});
  final rawCycles = current['cycles'];
  if (rawCycles is List && rawCycles.isNotEmpty) {
    final cycles = rawCycles
        .whereType<Map>()
        .map((cycle) => Map<String, dynamic>.from(cycle))
        .toList();
    if (cycles.isNotEmpty) {
      cycles[cycles.length - 1] = {...cycles.last, 'status': status.name};
      current['cycles'] = cycles;
    }
  }
  final changedAt = (now ?? DateTime.now()).toUtc();
  final wasCompleted = taskStatus(plan, key) == TaskStatus.completed;
  workflow[key] = {
    ...current,
    if (status == TaskStatus.completed && !wasCompleted)
      'completionPreviousStage': _taskStageBeforeCompletion(plan, key),
    'status': status.name,
    if (status == TaskStatus.started &&
        taskStatus(plan, key) != TaskStatus.started &&
        current['firstStartedAt'] == null) ...{
      'firstStartedAt': changedAt.toIso8601String(),
      if (actor != null) 'firstStartedBy': _trackingActor(actor),
    },
    if (!wasCompleted || status != TaskStatus.completed)
      'completedBy': status == TaskStatus.completed && actor != null
          ? _trackingActor(actor)
          : null,
    'completedAt': status == TaskStatus.completed
        ? (wasCompleted ? current['completedAt'] : changedAt.toIso8601String())
        : null,
    'updatedAt': changedAt.toIso8601String(),
  };
  return plan.copyWith(taskWorkflow: workflow);
}

Map<String, dynamic> _taskStageBeforeCompletion(Plan plan, String key) {
  final cycle = currentTaskCycle(plan, key);
  return {
    'status': taskStatus(plan, key).name,
    'draftStage': draftCycleStage(plan, key).name,
    'reviewRequestedFrom': cycle['reviewRequestedFrom'],
    'clientConfirmed': cycle['clientConfirmed'] == true,
  };
}

Plan restoreCompletedTask(Plan plan, String key, {DateTime? now}) {
  if (taskStatus(plan, key) != TaskStatus.completed) {
    throw StateError('Only completed tasks can be restored.');
  }
  final current = plan.taskWorkflow[key] ?? const <String, dynamic>{};
  final savedStage = current['completionPreviousStage'];
  final cycles = taskCycles(plan, key);
  final hasDrafts = cycles.any((cycle) => cycle['cycle'] is num);
  final stage = savedStage is Map
      ? Map<String, dynamic>.from(savedStage)
      : <String, dynamic>{
          'status': hasDrafts
              ? TaskStatus.draftCycle.name
              : taskAssigneeId(plan, key) == null
              ? TaskStatus.notAssigned.name
              : current['firstStartedAt'] != null ||
                    taskStartedAt(plan, key) != null ||
                    taskElapsedBeforeCurrentRun(plan, key) > Duration.zero
              ? TaskStatus.started.name
              : TaskStatus.assigned.name,
          'draftStage': DraftCycleStage.confirmation.name,
          'reviewRequestedFrom': hasDrafts ? 'client' : null,
          'clientConfirmed': false,
        };
  if (!TaskStatus.values.any(
    (status) =>
        status != TaskStatus.completed && status.name == stage['status'],
  )) {
    throw StateError('The previous task stage is invalid. Reopen the task.');
  }
  final changedAt = (now ?? DateTime.now()).toUtc().toIso8601String();
  final elapsed = taskElapsedTime(plan, key, now: taskCompletedAt(plan, key));
  return plan.copyWith(
    taskWorkflow: {
      ...plan.taskWorkflow,
      key: {
        ...current,
        ...stage,
        'completionPreviousStage': null,
        'completedAt': null,
        'completedBy': null,
        'timerRunning': false,
        'startedAt': null,
        if (elapsed != null) 'elapsedMilliseconds': elapsed.inMilliseconds,
        if (current['cycles'] is List && cycles.isNotEmpty)
          'cycles': [
            ...cycles.take(cycles.length - 1),
            {
              ...cycles.last,
              ...stage,
              'completedAt': null,
              'completedBy': null,
              'updatedAt': changedAt,
            },
          ],
        'updatedAt': changedAt,
      },
    },
  );
}

List<Map<String, dynamic>> _normalizedCycleList(List<dynamic>? rawCycles) {
  final normalized = <int, Map<String, dynamic>>{};
  if (rawCycles == null) return const [];

  for (final rawCycle in rawCycles) {
    if (rawCycle is! Map) continue;
    final cycle = Map<String, dynamic>.from(rawCycle);
    final cycleNumber = cycle['cycle'];
    final int? number = cycleNumber is num
        ? cycleNumber.toInt()
        : int.tryParse(cycleNumber?.toString() ?? '');
    if (number == null) continue;
    normalized[number] = cycle;
  }

  final ordered = normalized.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return ordered.map((entry) => entry.value).toList();
}

List<Map<String, dynamic>> taskCycles(Plan plan, String key) {
  final workflow = plan.taskWorkflow[key];
  final cycles = workflow?['cycles'];

  if (cycles is! List) {
    if (workflow == null) return const [];
    return [Map<String, dynamic>.from(workflow)];
  }

  return _normalizedCycleList(cycles);
}

Plan replaceTaskWorkflowCycles(
  Plan plan,
  String key,
  List<Map<String, dynamic>> cycles, {
  DateTime? now,
  AppUser? actor,
}) {
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };

  final sanitized = <Map<String, dynamic>>[];
  final seen = <int>{};
  for (final item in cycles) {
    final cycleNumber = (item['cycle'] as num?)?.toInt();
    if (cycleNumber == null || seen.contains(cycleNumber)) continue;
    seen.add(cycleNumber);
    sanitized.add(Map<String, dynamic>.from(item));
  }
  sanitized.sort((a, b) {
    final aValue = (a['cycle'] as num?)?.toInt() ?? 0;
    final bValue = (b['cycle'] as num?)?.toInt() ?? 0;
    return aValue.compareTo(bValue);
  });
  final active = sanitized.isEmpty ? const <String, dynamic>{} : sanitized.last;
  final previous = workflow[key];
  final changedAt = (now ?? DateTime.now()).toUtc();
  final changedAtValue = changedAt.toIso8601String();
  final nextStatus = sanitized.isEmpty
      ? TaskStatus.notAssigned.name
      : active['status'] ?? TaskStatus.notAssigned.name;
  final wasCompleted = taskStatus(plan, key) == TaskStatus.completed;

  workflow[key] = {
    ...?workflow[key],
    if (nextStatus == TaskStatus.completed.name && !wasCompleted)
      'completionPreviousStage': _taskStageBeforeCompletion(plan, key),
    'status': nextStatus,
    'instructions': sanitized.isEmpty ? '' : active['instructions'] ?? '',
    'update': sanitized.isEmpty ? '' : active['update'] ?? '',
    'clientConfirmed': sanitized.isEmpty
        ? false
        : active['clientConfirmed'] ?? false,
    'draftStage': sanitized.isEmpty
        ? DraftCycleStage.instructions.name
        : active['draftStage'] ?? DraftCycleStage.instructions.name,
    'startedAt': previous?['startedAt'],
    if (nextStatus == TaskStatus.started.name &&
        taskStatus(plan, key) != TaskStatus.started &&
        previous?['firstStartedAt'] == null) ...{
      'firstStartedAt': changedAtValue,
      if (actor != null) 'firstStartedBy': _trackingActor(actor),
    },
    if (!wasCompleted || nextStatus != TaskStatus.completed.name)
      'completedBy': nextStatus == TaskStatus.completed.name && actor != null
          ? _trackingActor(actor)
          : null,
    'completedAt': nextStatus == TaskStatus.completed.name
        ? (wasCompleted
              ? (previous == null ? null : previous['completedAt'])
              : changedAtValue)
        : null,
    'cycles': sanitized,
    'updatedAt': changedAtValue,
  };

  return plan.copyWith(taskWorkflow: workflow);
}

Plan createNextDraftCycle(
  Plan plan,
  String key, {
  AppUser? actor,
  DateTime? now,
}) {
  final cycles = taskCycles(plan, key);
  final nextNumber = cycles.isEmpty
      ? 1
      : cycles
                .map((cycle) => (cycle['cycle'] as num?)?.toInt() ?? 0)
                .reduce((a, b) => a > b ? a : b) +
            1;
  return replaceTaskWorkflowCycles(plan, key, [
    ...cycles,
    {
      'cycle': nextNumber,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      if (actor != null) 'createdBy': _trackingActor(actor),
      'status': TaskStatus.draftCycle.name,
      'draftStage': DraftCycleStage.instructions.name,
      'instructions': '',
      'update': '',
      'clientConfirmed': false,
      'updatedAt': DateTime.now().toIso8601String(),
    },
  ]);
}

Plan submitTaskForReview(
  Plan plan,
  String key, {
  required String reviewer,
  AppUser? actor,
  DateTime? now,
}) {
  if (reviewer != 'admin' && reviewer != 'client') {
    throw ArgumentError.value(reviewer, 'reviewer');
  }
  var cycles = taskCycles(
    plan,
    key,
  ).map((cycle) => Map<String, dynamic>.from(cycle)).toList();
  if (cycles.isEmpty || cycles.last['cycle'] is! num) {
    final existing = cycles.isEmpty ? const <String, dynamic>{} : cycles.last;
    cycles = [
      {
        for (final entry in existing.entries)
          if (entry.key != 'createdAt' && entry.key != 'createdBy')
            entry.key: entry.value,
        'cycle': 1,
        'instructions': taskText(plan, key, 'instructions'),
        'update': taskText(plan, key, 'update'),
      },
    ];
  }

  final currentIndex = cycles.length - 1;
  final dateField = reviewer == 'admin' ? 'sentToAdminAt' : 'sentToClientAt';
  final actorField = reviewer == 'admin' ? 'sentToAdminBy' : 'sentToClientBy';
  final changedAt = (now ?? DateTime.now()).toUtc();
  cycles[currentIndex] = {
    ...cycles[currentIndex],
    'status': TaskStatus.draftCycle.name,
    'draftStage': DraftCycleStage.confirmation.name,
    'clientConfirmed': false,
    'reviewRequestedFrom': reviewer,
    if (cycles[currentIndex][dateField] == null) ...{
      dateField: changedAt.toIso8601String(),
      if (actor != null) actorField: _trackingActor(actor),
    },
    'updatedAt': changedAt.toIso8601String(),
  };
  return replaceTaskWorkflowCycles(
    plan,
    key,
    cycles,
    now: changedAt,
    actor: actor,
  );
}

Plan completeReviewedTask(
  Plan plan,
  String key, {
  AppUser? actor,
  DateTime? now,
}) {
  final current = currentTaskCycle(plan, key);
  final cycleNumber = (current['cycle'] as num?)?.toInt() ?? 1;
  return updateTaskWorkflow(
    plan,
    key,
    status: TaskStatus.completed,
    instructions: current['instructions']?.toString() ?? '',
    update: current['update']?.toString() ?? '',
    clientConfirmed: true,
    cycleNumber: cycleNumber,
    actor: actor,
    now: now,
  );
}

Plan updateTaskCycleInstructions(
  Plan plan,
  String key,
  int cycleNumber,
  String instructions,
) {
  final cycles = taskCycles(
    plan,
    key,
  ).map((cycle) => Map<String, dynamic>.from(cycle)).toList();
  final index = cycles.indexWhere(
    (cycle) => (cycle['cycle'] as num?)?.toInt() == cycleNumber,
  );
  if (index < 0) throw StateError('Draft $cycleNumber was not found');
  cycles[index] = {
    ...cycles[index],
    'instructions': instructions.trim(),
    'clientConfirmed': false,
    'updatedAt': DateTime.now().toIso8601String(),
  };
  return replaceTaskWorkflowCycles(plan, key, cycles);
}

Plan updateTaskCycleWorkLink(
  Plan plan,
  String key,
  int cycleNumber,
  String workLink,
) {
  final cycles = taskCycles(
    plan,
    key,
  ).map((cycle) => Map<String, dynamic>.from(cycle)).toList();
  final index = cycles.indexWhere(
    (cycle) => (cycle['cycle'] as num?)?.toInt() == cycleNumber,
  );
  if (index < 0) throw StateError('Draft $cycleNumber was not found');
  cycles[index] = {
    ...cycles[index],
    'draftLink': workLink.trim(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
  return replaceTaskWorkflowCycles(plan, key, cycles);
}

Plan updateTaskAssignment(
  Plan plan,
  String key, {
  String? assignedTo,
  String? assignedToName,
  required String priority,
  AppUser? actor,
  DateTime? now,
}) {
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };
  final current = Map<String, dynamic>.from(workflow[key] ?? const {});
  final assigneeId = assignedTo?.trim() ?? '';
  final assigneeName = assignedToName?.trim() ?? '';
  final changedAt = (now ?? DateTime.now()).toUtc().toIso8601String();
  workflow[key] = {
    ...current,
    'assignedTo': assigneeId.isEmpty ? null : assigneeId,
    'assignedToName': assigneeName.isEmpty ? null : assigneeName,
    if (assigneeId.isNotEmpty && assigneeId != taskAssigneeId(plan, key)) ...{
      'assignedAt': changedAt,
      'assignedBy': actor == null ? null : _trackingActor(actor),
    },
    if (assigneeId.isEmpty) ...{'assignedAt': null, 'assignedBy': null},
    'priority': priority,
    'updatedAt': DateTime.now().toIso8601String(),
  };
  return plan.copyWith(taskWorkflow: workflow);
}

Plan updateTaskManagementDetails(
  Plan plan,
  String key, {
  required DateTime? dueAt,
  required String internalNotes,
  AppUser? actor,
}) {
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };
  workflow[key] = {
    ...?workflow[key],
    'dueAt': dueAt?.toIso8601String(),
    if (taskDueAt(plan, key) != dueAt)
      'dueBy': dueAt == null || actor == null ? null : _trackingActor(actor),
    'internalNotes': internalNotes.trim(),
    'updatedAt': DateTime.now().toIso8601String(),
  };
  return plan.copyWith(taskWorkflow: workflow);
}

Map<String, dynamic> currentTaskCycle(Plan plan, String key) {
  final cycles = taskCycles(plan, key);
  if (cycles.isEmpty) return const {};
  return cycles.last;
}

Plan updateTaskWorkflow(
  Plan plan,
  String key, {
  required TaskStatus status,
  required String instructions,
  required String update,
  bool clientConfirmed = false,
  int? cycleNumber,
  AppUser? actor,
  DateTime? now,
}) {
  final changedAt = (now ?? DateTime.now()).toUtc();
  final cycles = taskCycles(plan, key);
  final savedNumbers = cycles
      .map((item) => (item['cycle'] as num?)?.toInt())
      .whereType<int>()
      .toList();
  final nextNumber =
      cycleNumber ??
      (savedNumbers.isEmpty
          ? 1
          : savedNumbers.reduce((a, b) => a > b ? a : b) + 1);
  final number = cycleNumber ?? nextNumber;
  final sanitizedCycles = <Map<String, dynamic>>[];
  final seen = <int>{};
  for (final item in cycles) {
    final cycleValue = (item['cycle'] as num?)?.toInt();
    if (cycleValue == null || seen.contains(cycleValue)) continue;
    seen.add(cycleValue);
    sanitizedCycles.add(Map<String, dynamic>.from(item));
  }

  final existingIndex = sanitizedCycles.indexWhere(
    (item) => (item['cycle'] as num?)?.toInt() == number,
  );
  final existingCycle = existingIndex < 0
      ? const <String, dynamic>{}
      : sanitizedCycles[existingIndex];
  final cycle = {
    ...existingCycle,
    'cycle': number,
    'status': status.name,
    'instructions': instructions.trim(),
    'update': update.trim(),
    'clientConfirmed': clientConfirmed,
    if (status == TaskStatus.completed &&
        taskStatus(plan, key) != TaskStatus.completed) ...{
      'completedAt': changedAt.toIso8601String(),
      if (actor != null) 'completedBy': _trackingActor(actor),
    },
    'updatedAt': changedAt.toIso8601String(),
  };
  if (existingIndex >= 0) {
    sanitizedCycles[existingIndex] = cycle;
  } else {
    sanitizedCycles.add(cycle);
  }
  sanitizedCycles.sort((a, b) {
    final aValue = (a['cycle'] as num?)?.toInt() ?? 0;
    final bValue = (b['cycle'] as num?)?.toInt() ?? 0;
    return aValue.compareTo(bValue);
  });

  return replaceTaskWorkflowCycles(
    plan,
    key,
    sanitizedCycles,
    now: changedAt,
    actor: actor,
  );
}
