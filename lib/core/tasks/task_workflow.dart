import '../models/models.dart';

String taskKey(String rawFeature, int? unitIndex) =>
    unitIndex == null ? rawFeature : '$rawFeature#$unitIndex';

TaskStatus taskStatus(Plan plan, String key) {
  final raw = currentTaskCycle(plan, key)['status']?.toString();
  return TaskStatus.values.firstWhere(
    (status) => status.name == raw,
    orElse: () => TaskStatus.draft,
  );
}

String taskText(Plan plan, String key, String field) =>
    currentTaskCycle(plan, key)[field]?.toString() ?? '';

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
  final active = sanitized.isEmpty
      ? const <String, dynamic>{}
      : sanitized.firstWhere(
          (cycle) => cycle['status']?.toString() != TaskStatus.completed.name,
          orElse: () => sanitized.last,
        );

  workflow[key] = {
    'status': sanitized.isEmpty ? 'draft' : active['status'] ?? 'draft',
    'instructions': sanitized.isEmpty ? '' : active['instructions'] ?? '',
    'update': sanitized.isEmpty ? '' : active['update'] ?? '',
    'clientConfirmed': sanitized.isEmpty
        ? false
        : active['clientConfirmed'] ?? false,
    'cycles': sanitized,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  return plan.copyWith(taskWorkflow: workflow);
}

Map<String, dynamic> currentTaskCycle(Plan plan, String key) {
  final cycles = taskCycles(plan, key);
  if (cycles.isEmpty) return const {};
  final next = cycles.firstWhere(
    (cycle) => cycle['status']?.toString() != TaskStatus.completed.name,
    orElse: () => cycles.last,
  );
  return next;
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
  final cycle = {
    'cycle': number,
    'status': status.name,
    'instructions': instructions.trim(),
    'update': update.trim(),
    'clientConfirmed': clientConfirmed,
    'updatedAt': DateTime.now().toIso8601String(),
  };

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
