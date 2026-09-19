import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/models/models.dart';

void main() {
  test('sales task is client-linked without plan or assignee data', () {
    final task = SalesTask(
      id: 'sales-task-1',
      clientId: 'client-1',
      title: 'Call about proposal',
      category: 'Call',
      priority: 'high',
      status: SalesTaskStatus.inProgress,
      notes: 'Discuss the revised scope.',
      dueAt: DateTime(2026, 9, 10),
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9, 10),
    );

    final data = task.toFirestore();

    expect(data['clientId'], 'client-1');
    expect(data.containsKey('planId'), isFalse);
    expect(data.containsKey('assignedTo'), isFalse);
    expect(data['status'], SalesTaskStatus.inProgress.name);
    expect(data['priority'], 'high');
  });

  test('completing a sales task retains its outcome and completion time', () {
    final completedAt = DateTime(2026, 9, 9, 11);
    final task = SalesTask(
      id: 'sales-task-1',
      clientId: 'client-1',
      title: 'Send quotation',
      category: 'Email',
      status: SalesTaskStatus.completed,
      outcome: 'Quotation sent by email.',
      completedAt: completedAt,
      createdAt: DateTime(2026, 9, 9),
      updatedAt: completedAt,
    );

    expect(task.status, SalesTaskStatus.completed);
    expect(task.outcome, 'Quotation sent by email.');
    expect(task.completedAt, completedAt);
  });

  test('sales tasks can be archived without changing their status', () {
    final task = SalesTask(
      id: 'sales-task-1',
      clientId: 'client-1',
      title: 'Call about proposal',
      category: 'Call',
      status: SalesTaskStatus.notStarted,
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    );

    final archived = task.copyWith(isArchived: true);

    expect(archived.isArchived, isTrue);
    expect(archived.status, SalesTaskStatus.notStarted);
    expect(archived.toFirestore()['isArchived'], isTrue);
  });
}
