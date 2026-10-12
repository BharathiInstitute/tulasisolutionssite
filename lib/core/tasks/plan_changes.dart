import 'dart:collection';
import '../models/models.dart';

bool samePlanData(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) && samePlanData(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        Iterable.generate(
          left.length,
        ).every((index) => samePlanData(left[index], right[index]));
  }
  return left == right;
}

Map<String, dynamic> mergePlanChanges(
  Map<String, dynamic> current,
  Map<String, dynamic> previous,
  Map<String, dynamic> desired,
) {
  final result = Map<String, dynamic>.from(current);
  for (final key in {...previous.keys, ...desired.keys}) {
    final hadKey = previous.containsKey(key);
    final hasKey = desired.containsKey(key);
    if (hadKey == hasKey && samePlanData(previous[key], desired[key])) continue;
    final before = previous[key];
    final after = desired[key];
    final live = current[key];
    if (hasKey && before is Map && after is Map && live is Map) {
      result[key] = mergePlanChanges(
        Map<String, dynamic>.from(live),
        Map<String, dynamic>.from(before),
        Map<String, dynamic>.from(after),
      );
    } else if ((current.containsKey(key) == hadKey &&
            samePlanData(live, before)) ||
        (current.containsKey(key) == hasKey && samePlanData(live, after))) {
      if (hasKey) {
        result[key] = after;
      } else {
        result.remove(key);
      }
    } else {
      throw PlanSaveConflict(
        'This plan or task changed while editing ($key). '
        'Reopen the latest task and review your retained edits before saving again.',
      );
    }
  }
  return result;
}

Plan overlayPlanChanges(
  Plan live,
  Plan before,
  Plan after, {
  bool rollback = false,
}) {
  if (samePlanData(live.toFirestore(), before.toFirestore())) return after;
  final beforeData = before.toFirestore();
  final afterData = after.toFirestore();
  if (rollback) {
    final features = [...after.features];
    for (final task in before.tasks) {
      final original = after.tasks
          .where((item) => item.id == task.id)
          .firstOrNull;
      if (original == null || original.feature == task.feature) continue;
      final current = live.tasks
          .where((item) => item.id == task.id)
          .firstOrNull;
      if (current == null ||
          (current.feature != task.feature &&
              current.feature != original.feature)) {
        features.remove(original.feature);
        if (!features.contains(task.feature)) features.add(task.feature);
      }
    }
    afterData['features'] = features;
  }
  return Plan.fromData(
    live.id,
    _overlayMap(live.toFirestore(), beforeData, afterData, rollback),
  );
}

Map<String, dynamic> _overlayMap(
  Map<String, dynamic> live,
  Map<String, dynamic> before,
  Map<String, dynamic> after,
  bool rollback,
) {
  final result = {...live};
  for (final key in {...before.keys, ...after.keys}) {
    final hadKey = before.containsKey(key);
    final hasKey = after.containsKey(key);
    if (hadKey == hasKey && samePlanData(before[key], after[key])) continue;
    final oldValue = before[key];
    final newValue = after[key];
    final current = live[key];
    if (oldValue is Map && newValue is Map && current is Map) {
      result[key] = _overlayMap(
        Map<String, dynamic>.from(current),
        Map<String, dynamic>.from(oldValue),
        Map<String, dynamic>.from(newValue),
        rollback,
      );
    } else if (oldValue is List && newValue is List && current is List) {
      result[key] = _overlayList(current, oldValue, newValue, rollback);
    } else if (!rollback ||
        (live.containsKey(key) == hadKey && samePlanData(current, oldValue))) {
      if (hasKey) {
        result[key] = newValue;
      } else {
        result.remove(key);
      }
    }
  }
  return result;
}

List<dynamic> _overlayList(
  List<dynamic> live,
  List<dynamic> before,
  List<dynamic> after,
  bool rollback,
) {
  final result = [...live];
  for (final old in before) {
    if (after.any((value) => _sameItem(value, old))) continue;
    result.removeWhere(
      (value) =>
          _sameItem(value, old) && (!rollback || samePlanData(value, old)),
    );
  }
  for (var index = 0; index < after.length; index++) {
    final value = after[index];
    final oldIndex = before.indexWhere((old) => _sameItem(old, value));
    if (oldIndex >= 0 && samePlanData(before[oldIndex], value)) continue;
    final liveIndex = result.indexWhere((item) => _sameItem(item, value));
    if (liveIndex >= 0) {
      final current = result[liveIndex];
      final old = oldIndex < 0 ? null : before[oldIndex];
      if (value is Map && old is Map && current is Map) {
        result[liveIndex] = _overlayMap(
          Map<String, dynamic>.from(current),
          Map<String, dynamic>.from(old),
          Map<String, dynamic>.from(value),
          rollback,
        );
      } else if (!rollback ||
          (oldIndex >= 0 &&
              samePlanData(result[liveIndex], before[oldIndex]))) {
        result[liveIndex] = value;
      }
    } else if (oldIndex < 0) {
      result.insert(index < result.length ? index : result.length, value);
    }
  }
  return result;
}

bool _sameItem(Object? left, Object? right) {
  if (left is Map && right is Map) {
    for (final key in ['id', 'cycle']) {
      if (left[key] != null && right[key] != null) {
        return left[key] == right[key];
      }
    }
  }
  return samePlanData(left, right);
}

class ClientSnapshotList extends UnmodifiableListView<Client> {
  final bool serverConfirmed;

  ClientSnapshotList(super.source, {required this.serverConfirmed});
}

class PlanSnapshotList extends UnmodifiableListView<Plan> {
  final bool serverConfirmed;

  PlanSnapshotList(super.source, {required this.serverConfirmed});
}

class PlanSaveConflict extends StateError {
  PlanSaveConflict(super.message);
}
