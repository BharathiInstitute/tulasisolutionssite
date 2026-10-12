import 'package:flutter/material.dart';
import '../models/models.dart';
import '../tasks/task_workflow.dart';

String _date(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date.toLocal());

String salesTaskDueLabel(BuildContext context, DateTime? dueAt, DateTime now) {
  if (dueAt == null) return 'Unscheduled';
  final due = dueAt.toLocal();
  final today = DateUtils.dateOnly(now.toLocal());
  final dueDay = DateUtils.dateOnly(due);
  final time = TimeOfDay.fromDateTime(due).format(context);
  if (due.isBefore(now)) {
    final days = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(dueDay.year, dueDay.month, dueDay.day)).inDays;
    return days == 0
        ? 'Overdue - today, $time'
        : 'Overdue by $days ${days == 1 ? 'day' : 'days'}';
  }
  if (dueDay == today) return 'Today, $time';
  if (dueDay == DateTime(today.year, today.month, today.day + 1)) {
    return 'Tomorrow, $time';
  }
  return '${_date(context, due)}, $time';
}

String taskCardDates(BuildContext context, Plan plan, String key) {
  final cycle = currentTaskCycle(plan, key);
  final status = taskStatus(plan, key);
  final events = taskTrackingEvents(plan, key);
  String display(String label, DateTime? at) => at == null
      ? ''
      : '$label ${_date(context, at)}, '
            '${TimeOfDay.fromDateTime(at.toLocal()).format(context)}';
  DateTime? eventDate(String label) =>
      events.where((event) => event.label == label).firstOrNull?.at;
  if (status == TaskStatus.completed) {
    return display('Completed on', taskCompletedAt(plan, key));
  }
  final pending =
      status == TaskStatus.draftCycle &&
      draftCycleStage(plan, key) == DraftCycleStage.confirmation &&
      cycle['clientConfirmed'] != true;
  final reviewer = pending ? cycle['reviewRequestedFrom'] : null;
  final field = reviewer == 'admin'
      ? 'Sent for admin approval'
      : reviewer == 'client'
      ? 'Sent for client approval'
      : null;
  final draftPrefix = cycle['cycle'] == null
      ? ''
      : 'Draft ${cycle['cycle']} - ';
  if (field != null) {
    return display('$draftPrefix$field on', eventDate('$draftPrefix$field'));
  }
  if (status == TaskStatus.draftCycle) {
    return display(
      '${draftPrefix}Created on',
      eventDate('${draftPrefix}Created'),
    );
  }
  if (status == TaskStatus.started || taskTimerIsRunning(plan, key)) {
    return display('Started on', eventDate('First started'));
  }
  final assigned = eventDate('Assigned');
  if (status == TaskStatus.assigned && assigned != null) {
    return display('Assigned on', assigned);
  }
  return display(
    'Created on',
    eventDate('Created') ?? eventDate('Created / assigned'),
  );
}

class TaskTrackingSection extends StatelessWidget {
  final Plan plan;
  final String workflowKey;

  const TaskTrackingSection({
    super.key,
    required this.plan,
    required this.workflowKey,
  });

  @override
  Widget build(BuildContext context) {
    final events = taskTrackingEvents(plan, workflowKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tracking', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (events.isEmpty)
            const Text('No tracking dates recorded yet.')
          else
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${event.label}: ${_date(context, event.at)}, '
                  '${TimeOfDay.fromDateTime(event.at.toLocal()).format(context)}'
                  '${event.by == null ? '' : ' - ${event.by}'}',
                ),
              ),
        ],
      ),
    );
  }
}
