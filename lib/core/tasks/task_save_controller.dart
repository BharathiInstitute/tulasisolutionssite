import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'plan_changes.dart';

enum TaskSavePhase { saving, failed, confirmed }

class TaskSave {
  final Plan desired;
  final Plan? previous;
  final String label;
  final Future<void> Function() persist;
  final TaskSavePhase phase;
  final Object? error;
  final bool slow;
  final String? refreshClientId;
  final String? workflowKey;
  final String? lockedAssigneeId;
  final Map<String, String> recoveryText;

  const TaskSave({
    required this.desired,
    required this.previous,
    required this.label,
    required this.persist,
    this.phase = TaskSavePhase.saving,
    this.error,
    this.slow = false,
    this.refreshClientId,
    this.workflowKey,
    this.lockedAssigneeId,
    this.recoveryText = const {},
  });

  TaskSave withPhase(TaskSavePhase phase, {Object? error, bool slow = false}) =>
      TaskSave(
        desired: desired,
        previous: previous,
        label: label,
        persist: persist,
        phase: phase,
        error: error,
        slow: slow,
        refreshClientId: refreshClientId,
        workflowKey: workflowKey,
        lockedAssigneeId: lockedAssigneeId,
        recoveryText: recoveryText,
      );

  bool get hasConflict => error is PlanSaveConflict;
  bool get canRetry {
    final failure = error;
    return phase == TaskSavePhase.failed &&
        !hasConflict &&
        !(failure is FirebaseException &&
            const [
              'permission-denied',
              'unauthenticated',
              'invalid-argument',
              'not-found',
            ].contains(failure.code));
  }

  Map<String, String> get retainedText {
    final text = <String, String>{};
    if (previous?.name != desired.name) text['Plan name'] = desired.name;
    for (final task in desired.tasks) {
      final old = previous?.tasks
          .where((item) => item.id == task.id)
          .firstOrNull;
      if (old?.title != task.title) {
        text['Task title - ${task.category}'] = task.title;
      }
    }
    for (final entry in desired.taskWorkflow.entries) {
      final before =
          previous?.taskWorkflow[entry.key] ?? const <String, dynamic>{};
      void capture(
        Map<dynamic, dynamic> values,
        Map<dynamic, dynamic> old,
        String prefix, {
        bool draft = false,
      }) {
        for (final field in const {
          'internalNotes': 'Notes',
          'instructions': 'Instructions',
          'draftLink': 'Draft link',
          'update': 'Draft update',
        }.entries) {
          if (draft && field.key == 'internalNotes') continue;
          if (values.containsKey(field.key) &&
              values[field.key] != old[field.key] &&
              (old.containsKey(field.key) ||
                  (values[field.key]?.toString().isNotEmpty ?? false))) {
            text['$prefix${field.value}'] = values[field.key]?.toString() ?? '';
          }
        }
      }

      capture(entry.value, before, '${entry.key} - ');
      final oldCycles =
          (before['cycles'] as List?)?.whereType<Map>() ?? const <Map>[];
      for (final cycle
          in (entry.value['cycles'] as List?)?.whereType<Map>() ??
              const <Map>[]) {
        final old =
            oldCycles
                .where((item) => item['cycle'] == cycle['cycle'])
                .firstOrNull ??
            const {};
        capture(
          cycle,
          old,
          '${entry.key} - Draft ${cycle['cycle']} - ',
          draft: true,
        );
      }
    }
    return {...text, ...recoveryText};
  }
}

class TaskSaveController extends StateNotifier<Map<String, TaskSave>> {
  TaskSaveController({this.onConfirmed}) : super(const {});

  final _timers = <String, Timer>{};
  final void Function(TaskSave)? onConfirmed;
  final _remote = <String, Plan>{};
  final _observed = <String>{};
  final _missing = <String>{};

  bool get hasUnsavedChanges =>
      state.values.any((save) => save.phase != TaskSavePhase.confirmed);

  void submit({
    required Plan desired,
    required Plan? previous,
    required String label,
    required Future<void> Function() persist,
    String? refreshClientId,
    String? workflowKey,
    String? lockedAssigneeId,
    Map<String, String> recoveryText = const {},
    bool replaceFailed = false,
  }) {
    final existing = state[desired.id];
    if (existing != null &&
        existing.phase != TaskSavePhase.confirmed &&
        !(replaceFailed && existing.phase == TaskSavePhase.failed)) {
      throw StateError(
        'This plan has an unfinished save. Retry or discard it first.',
      );
    }
    final save = TaskSave(
      desired: desired,
      previous: previous,
      label: label,
      persist: persist,
      refreshClientId: refreshClientId,
      workflowKey: workflowKey,
      lockedAssigneeId: lockedAssigneeId,
      recoveryText: recoveryText,
    );
    _observed.remove(desired.id);
    state = {...state, desired.id: save};
    unawaited(_persist(save));
  }

  Future<void> _persist(TaskSave save) async {
    final id = save.desired.id;
    _timers[id]?.cancel();
    _timers[id] = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        final current = state[id];
        if (current?.phase == TaskSavePhase.saving) {
          state = {
            ...state,
            id: current!.withPhase(TaskSavePhase.saving, slow: true),
          };
        }
      }
    });
    Object? failure;
    try {
      await save.persist();
    } catch (error) {
      failure = error;
    } finally {
      _timers.remove(id)?.cancel();
    }
    if (!mounted) return;
    if (failure != null) {
      state = {
        ...state,
        id: save.withPhase(TaskSavePhase.failed, error: failure),
      };
      return;
    }
    state = {...state, id: save.withPhase(TaskSavePhase.confirmed)};
    if (_observed.remove(id)) {
      state = {...state}..remove(id);
    }
    onConfirmed?.call(save);
  }

  void retry(String planId) {
    final save = state[planId];
    if (save == null || !save.canRetry) return;
    final retry = save.withPhase(TaskSavePhase.saving);
    state = {...state, planId: retry};
    unawaited(_persist(retry));
  }

  void discard(String planId) {
    if (state[planId]?.phase != TaskSavePhase.failed) return;
    _observed.remove(planId);
    state = {...state}..remove(planId);
  }

  void clearConfirmed(String planId) {
    if (state[planId]?.phase == TaskSavePhase.confirmed) {
      state = {...state}..remove(planId);
    }
  }

  void recordFreshPlan(String planId, Plan? plan) {
    if (plan == null) {
      _remote.remove(planId);
      _missing.add(planId);
    } else {
      _remote[planId] = plan;
      _missing.remove(planId);
    }
    state = {...state};
  }

  void reconcile(List<Plan> plans, {String? clientId}) {
    if (plans is PlanSnapshotList && !plans.serverConfirmed) return;
    final next = {...state};
    final ids = plans.map((plan) => plan.id).toSet();
    for (final save in state.values) {
      if (clientId != null &&
          save.desired.clientId != clientId &&
          save.previous?.clientId != clientId) {
        continue;
      }
      if (!ids.contains(save.desired.id)) {
        if (save.previous != null) _missing.add(save.desired.id);
        if (save.phase == TaskSavePhase.confirmed) {
          next.remove(save.desired.id);
          _missing.add(save.desired.id);
        }
      }
    }
    for (final plan in plans) {
      _missing.remove(plan.id);
      final save = next[plan.id];
      final matches =
          save != null &&
          _matchesChanges(
            plan.toFirestore(),
            save.previous?.toFirestore(),
            save.desired.toFirestore(),
          );
      if (save?.phase == TaskSavePhase.saving && matches) {
        _observed.add(plan.id);
      }
      if (save?.phase == TaskSavePhase.confirmed) {
        next.remove(plan.id);
      }
    }
    _remote.removeWhere(
      (id, plan) =>
          (clientId == null || plan.clientId == clientId) && !ids.contains(id),
    );
    _remote.addAll({for (final plan in plans) plan.id: plan});
    if (next.length != state.length) state = next;
  }

  List<Plan> visiblePlans(List<Plan> plans) {
    final visible = {
      for (final plan in plans)
        if (!_missing.contains(plan.id)) plan.id: plan,
    };
    for (final entry in state.entries) {
      final save = entry.value;
      if (_missing.contains(entry.key)) {
        visible.remove(entry.key);
        continue;
      }
      final live = visible[entry.key];
      if (save.phase == TaskSavePhase.failed) {
        if (save.previous == null) {
          if (!_remote.containsKey(entry.key)) visible.remove(entry.key);
        } else if (live != null) {
          final server = _remote[entry.key];
          visible[entry.key] =
              server != null &&
                  samePlanData(server.toFirestore(), live.toFirestore())
              ? live
              : overlayPlanChanges(
                  live,
                  save.desired,
                  save.previous!,
                  rollback: true,
                );
        }
      } else {
        visible[entry.key] = live != null && save.previous != null
            ? overlayPlanChanges(live, save.previous!, save.desired)
            : save.desired;
      }
    }
    return visible.values.toList()
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

bool _matchesChanges(Object? remote, Object? previous, Object? desired) {
  if (samePlanData(previous, desired)) return true;
  if (desired is Map && remote is Map) {
    final before = previous is Map ? previous : const {};
    return {...before.keys, ...desired.keys}.every((key) {
      if (key == 'updatedAt') return true;
      if (!desired.containsKey(key)) return !remote.containsKey(key);
      return _matchesChanges(remote[key], before[key], desired[key]);
    });
  }
  if (desired is List && remote is List) {
    final before = previous is List ? previous : const [];
    return desired.every(
          (value) => remote.any((item) => samePlanData(item, value)),
        ) &&
        before
            .where((value) => !desired.any((item) => samePlanData(item, value)))
            .every((value) => !remote.any((item) => samePlanData(item, value)));
  }
  return samePlanData(remote, desired);
}
