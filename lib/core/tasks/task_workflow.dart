import '../models/models.dart';

String taskKey(String rawFeature, int? unitIndex) =>
    unitIndex == null ? rawFeature : '$rawFeature#$unitIndex';

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
    'completedAt': isRunning ? null : changedAt.toIso8601String(),
    'updatedAt': changedAt.toIso8601String(),
  };
  return plan.copyWith(taskWorkflow: workflow);
}

Plan setTaskStatus(Plan plan, String key, TaskStatus status) {
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
  workflow[key] = {
    ...current,
    'status': status.name,
    'updatedAt': DateTime.now().toIso8601String(),
  };
  return plan.copyWith(taskWorkflow: workflow);
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
  List<Map<String, dynamic>> cycles,
) {
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
  final now = DateTime.now().toIso8601String();

  workflow[key] = {
    ...?workflow[key],
    'status': sanitized.isEmpty
        ? TaskStatus.notAssigned.name
        : active['status'] ?? TaskStatus.notAssigned.name,
    'instructions': sanitized.isEmpty ? '' : active['instructions'] ?? '',
    'update': sanitized.isEmpty ? '' : active['update'] ?? '',
    'clientConfirmed': sanitized.isEmpty
        ? false
        : active['clientConfirmed'] ?? false,
    'draftStage': sanitized.isEmpty
        ? DraftCycleStage.instructions.name
        : active['draftStage'] ?? DraftCycleStage.instructions.name,
    'startedAt': previous?['startedAt'],
    'completedAt': previous?['completedAt'],
    'cycles': sanitized,
    'updatedAt': now,
  };

  return plan.copyWith(taskWorkflow: workflow);
}

Plan createNextDraftCycle(Plan plan, String key) {
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
      'status': TaskStatus.draftCycle.name,
      'draftStage': DraftCycleStage.instructions.name,
      'instructions': '',
      'update': '',
      'clientConfirmed': false,
      'updatedAt': DateTime.now().toIso8601String(),
    },
  ]);
}

Plan submitTaskForReview(Plan plan, String key, {required String reviewer}) {
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
        ...existing,
        'cycle': 1,
        'instructions': taskText(plan, key, 'instructions'),
        'update': taskText(plan, key, 'update'),
      },
    ];
  }

  final currentIndex = cycles.length - 1;
  cycles[currentIndex] = {
    ...cycles[currentIndex],
    'status': TaskStatus.draftCycle.name,
    'draftStage': DraftCycleStage.confirmation.name,
    'clientConfirmed': false,
    'reviewRequestedFrom': reviewer,
    'updatedAt': DateTime.now().toIso8601String(),
  };
  return replaceTaskWorkflowCycles(plan, key, cycles);
}

Plan completeReviewedTask(Plan plan, String key) {
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
}) {
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };
  final current = Map<String, dynamic>.from(workflow[key] ?? const {});
  final assigneeId = assignedTo?.trim() ?? '';
  final assigneeName = assignedToName?.trim() ?? '';
  workflow[key] = {
    ...current,
    'assignedTo': assigneeId.isEmpty ? null : assigneeId,
    'assignedToName': assigneeName.isEmpty ? null : assigneeName,
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
}) {
  final workflow = <String, Map<String, dynamic>>{
    for (final entry in plan.taskWorkflow.entries)
      entry.key: Map<String, dynamic>.from(entry.value),
  };
  workflow[key] = {
    ...?workflow[key],
    'dueAt': dueAt?.toIso8601String(),
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
}) {
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
    'updatedAt': DateTime.now().toIso8601String(),
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

  return replaceTaskWorkflowCycles(plan, key, sanitizedCycles);
}
