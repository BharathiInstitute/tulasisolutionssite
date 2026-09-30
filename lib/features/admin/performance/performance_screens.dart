import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/performance/performance_models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

DateTime _weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _isThisWeek(DateTime date) => !date.isBefore(_weekStart(DateTime.now()));

double? _parseWorkedHours(String value) {
  final input = value.trim();
  if (!input.contains(':')) return double.tryParse(input);

  final parts = input.split(':');
  if (parts.length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null ||
      minutes == null ||
      hours < 0 ||
      minutes < 0 ||
      minutes > 59) {
    return null;
  }
  return hours + minutes / 60;
}

enum _RecordRange { day, week, month, custom }

enum _PointRecordView { details, summary }

enum _AdminPerformanceRange { today, week, month, custom }

class StaffPerformanceScreen extends ConsumerStatefulWidget {
  const StaffPerformanceScreen({super.key});

  @override
  ConsumerState<StaffPerformanceScreen> createState() =>
      _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState
    extends ConsumerState<StaffPerformanceScreen> {
  var _range = _AdminPerformanceRange.today;
  DateTimeRange? _customRange;

  DateTimeRange _dateRangeFor(DateTime today) {
    final day = DateUtils.dateOnly(today);
    return switch (_range) {
      _AdminPerformanceRange.today => DateTimeRange(start: day, end: day),
      _AdminPerformanceRange.week => DateTimeRange(
        start: _weekStart(day),
        end: _weekStart(day).add(const Duration(days: 6)),
      ),
      _AdminPerformanceRange.month => DateTimeRange(
        start: day.day >= 10
            ? DateTime(day.year, day.month, 10)
            : DateTime(day.year, day.month - 1, 10),
        end: day.day >= 10
            ? DateTime(day.year, day.month + 1, 9)
            : DateTime(day.year, day.month, 9),
      ),
      _AdminPerformanceRange.custom =>
        _customRange ?? DateTimeRange(start: day, end: day),
    };
  }

  Future<void> _selectCustomRange() async {
    final range = await _showCompactDateRangePicker(
      context: context,
      initialDateRange: _customRange,
    );
    if (range != null && mounted) {
      setState(() {
        _customRange = range;
        _range = _AdminPerformanceRange.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final staffIds = ref.watch(currentStaffIdsProvider);
    final staffId = profile?.uid;
    final canManagePerformance =
        profile?.isAdmin == true ||
        profile?.canAccessPanel('performance') == true;
    final submissions =
        ref
            .watch(
              canManagePerformance
                  ? performanceSubmissionsProvider
                  : myPerformanceSubmissionsProvider,
            )
            .valueOrNull ??
        [];
    final hours =
        ref
            .watch(
              canManagePerformance
                  ? performanceHoursProvider
                  : myPerformanceHoursProvider,
            )
            .valueOrNull ??
        [];
    final attendance =
        ref
            .watch(
              canManagePerformance
                  ? performanceAttendanceProvider
                  : myPerformanceAttendanceProvider,
            )
            .valueOrNull ??
        [];
    final contentStaff = canManagePerformance
        ? (ref.watch(allUsersProvider).valueOrNull ?? [])
              .where((user) => user.team.trim().toLowerCase() == 'content')
              .toList()
        : [if (profile != null) profile];
    final today = DateUtils.dateOnly(DateTime.now());
    final range = _dateRangeFor(today);
    bool isInPeriod(DateTime value) {
      final day = DateUtils.dateOnly(value);
      return !day.isBefore(range.start) && !day.isAfter(range.end);
    }

    final contentStaffIds = contentStaff.map((user) => user.uid).toSet();
    final rangeSubmissions = submissions
        .where(
          (item) =>
              contentStaffIds.contains(item.staffId) &&
              isInPeriod(item.submittedAt),
        )
        .toList();
    final teamResults = PerformanceCalculator.rank(
      staffIds: contentStaff.map((user) => user.uid),
      submissions: rangeSubmissions,
      hoursByStaff: {
        for (final user in contentStaff)
          user.uid: hours
              .where(
                (item) => item.staffId == user.uid && isInPeriod(item.date),
              )
              .fold<double>(0, (total, item) => total + item.hours),
      },
      presentDaysByStaff: {
        for (final user in contentStaff)
          user.uid: attendance
              .where(
                (item) =>
                    item.staffId == user.uid &&
                    isInPeriod(item.date) &&
                    item.present,
              )
              .length,
      },
    );

    final weeklySubmissions = submissions
        .where(
          (item) =>
              staffIds.contains(item.staffId) && _isThisWeek(item.submittedAt),
        )
        .toList();
    final todayUnits = weeklySubmissions
        .where(
          (item) =>
              DateUtils.isSameDay(item.submittedAt, DateTime.now()) &&
              item.isApproved,
        )
        .length;
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/my-performance',
      title: 'My Performance',
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'My performance',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ProgressCard(
              title: "Today's baseline",
              progress: todayUnits / 2,
              progressText: '$todayUnits of 2 daily units completed',
            ),
            const SizedBox(height: 16),
            _AdminPerformanceCard(
              range: _range,
              rangeLabel: _range == _AdminPerformanceRange.custom
                  ? '${DateFormat.yMMMd().format(range.start)} - ${DateFormat.yMMMd().format(range.end)}'
                  : _range == _AdminPerformanceRange.week
                  ? 'This week (Mon-Sun)'
                  : _range == _AdminPerformanceRange.month
                  ? 'This month (10th-9th)'
                  : 'Today',
              results: teamResults,
              submissions: rangeSubmissions
                  .where((item) => item.isApproved)
                  .toList(),
              names: {
                for (final user in contentStaff)
                  user.uid: user.name.isEmpty ? user.email : user.name,
              },
              onRangeChanged: (selected) =>
                  selected == _AdminPerformanceRange.custom
                  ? _selectCustomRange()
                  : setState(() => _range = selected),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'My records - This week',
              icon: Icons.fact_check_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (weeklySubmissions.isEmpty)
                    const Text('No video submissions this week.')
                  else
                    ...weeklySubmissions.map(
                      (submission) => _submissionTile(
                        submission,
                        onTap: () =>
                            _showSubmissionDetailsDialog(context, submission),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: staffId == null
                        ? null
                        : () => _showMemberPointsDialog(
                            context,
                            ref,
                            memberName: 'My',
                            staffId: staffId,
                            staff: contentStaff,
                            submissions: submissions,
                            names: {
                              for (final user in contentStaff)
                                user.uid: user.name.isEmpty
                                    ? user.email
                                    : user.name,
                            },
                            canEdit: false,
                          ),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('View all records'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPerformanceScreen extends ConsumerStatefulWidget {
  const AdminPerformanceScreen({super.key});

  @override
  ConsumerState<AdminPerformanceScreen> createState() =>
      _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState
    extends ConsumerState<AdminPerformanceScreen> {
  var _range = _AdminPerformanceRange.today;
  DateTimeRange? _customRange;

  DateTimeRange _dateRangeFor(DateTime today) {
    final day = DateUtils.dateOnly(today);
    return switch (_range) {
      _AdminPerformanceRange.today => DateTimeRange(start: day, end: day),
      _AdminPerformanceRange.week => DateTimeRange(
        start: _weekStart(day),
        end: _weekStart(day).add(const Duration(days: 6)),
      ),
      _AdminPerformanceRange.month => DateTimeRange(
        start: day.day >= 10
            ? DateTime(day.year, day.month, 10)
            : DateTime(day.year, day.month - 1, 10),
        end: day.day >= 10
            ? DateTime(day.year, day.month + 1, 9)
            : DateTime(day.year, day.month, 9),
      ),
      _AdminPerformanceRange.custom =>
        _customRange ?? DateTimeRange(start: day, end: day),
    };
  }

  String _rangeLabel(DateTimeRange range) => switch (_range) {
    _AdminPerformanceRange.today => 'Today',
    _AdminPerformanceRange.week => 'This week (Mon-Sun)',
    _AdminPerformanceRange.month => 'This month (10th-9th)',
    _AdminPerformanceRange.custom =>
      '${DateFormat.yMMMd().format(range.start)} - ${DateFormat.yMMMd().format(range.end)}',
  };

  Future<void> _selectCustomRange() async {
    final range = await _showCompactDateRangePicker(
      context: context,
      initialDateRange: _customRange,
    );
    if (range != null && mounted) {
      setState(() {
        _customRange = range;
        _range = _AdminPerformanceRange.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final range = _dateRangeFor(today);
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final submissions =
        ref.watch(performanceSubmissionsProvider).valueOrNull ?? [];
    final hours = ref.watch(performanceHoursProvider).valueOrNull ?? [];
    final attendance =
        ref.watch(performanceAttendanceProvider).valueOrNull ?? [];
    final staff = users
        .where((user) => user.team.trim().toLowerCase() == 'content')
        .toList();
    final names = {
      for (final user in staff)
        user.uid: user.name.isEmpty ? user.email : user.name,
    };
    bool isInPeriod(DateTime value) {
      final day = DateUtils.dateOnly(value);
      return !day.isBefore(range.start) && !day.isAfter(range.end);
    }

    final staffIds = staff.map((user) => user.uid).toSet();
    final approvedSubmissions = submissions
        .where(
          (item) =>
              staffIds.contains(item.staffId) &&
              item.isApproved &&
              isInPeriod(item.submittedAt),
        )
        .toList();
    List<WeeklyPerformance> resultsForRange() {
      return PerformanceCalculator.rank(
        staffIds: staff.map((user) => user.uid),
        submissions: submissions.where((item) => isInPeriod(item.submittedAt)),
        hoursByStaff: {
          for (final user in staff)
            user.uid: hours
                .where(
                  (item) => item.staffId == user.uid && isInPeriod(item.date),
                )
                .fold<double>(0, (total, item) => total + item.hours),
        },
        presentDaysByStaff: {
          for (final user in staff)
            user.uid: attendance
                .where(
                  (item) =>
                      item.staffId == user.uid &&
                      isInPeriod(item.date) &&
                      item.present,
                )
                .length,
        },
      );
    }

    void showMember(String staffId) => _showMemberPointsDialog(
      context,
      ref,
      memberName: names[staffId] ?? staffId,
      staffId: staffId,
      staff: staff,
      submissions: submissions
          .where((item) => item.staffId == staffId)
          .toList(),
      names: names,
    );
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/performance',
      title: 'Performance Tracking',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add points',
        onPressed: staff.isEmpty
            ? null
            : () => _showPointEntryDialog(context, ref, staff),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            _AdminPerformanceCard(
              range: _range,
              rangeLabel: _rangeLabel(range),
              results: resultsForRange(),
              submissions: approvedSubmissions,
              names: names,
              onMemberTap: showMember,
              onRangeChanged: (selected) {
                if (selected == _AdminPerformanceRange.custom) {
                  _selectCustomRange();
                } else {
                  setState(() => _range = selected);
                }
              },
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Staff records',
              icon: Icons.people_outline,
              child: Column(
                children: staff
                    .map(
                      (user) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(names[user.uid] ?? user.uid),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showMember(user.uid),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPerformanceCard extends StatelessWidget {
  final _AdminPerformanceRange range;
  final String rangeLabel;
  final List<WeeklyPerformance> results;
  final List<VideoSubmission> submissions;
  final Map<String, String> names;
  final ValueChanged<String>? onMemberTap;
  final ValueChanged<_AdminPerformanceRange> onRangeChanged;

  const _AdminPerformanceCard({
    required this.range,
    required this.rangeLabel,
    required this.results,
    required this.submissions,
    required this.names,
    this.onMemberTap,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Performance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SegmentedButton<_AdminPerformanceRange>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _AdminPerformanceRange.today,
                      label: Text('Today'),
                    ),
                    ButtonSegment(
                      value: _AdminPerformanceRange.week,
                      label: Text('Week'),
                    ),
                    ButtonSegment(
                      value: _AdminPerformanceRange.month,
                      label: Text('Month'),
                    ),
                    ButtonSegment(
                      value: _AdminPerformanceRange.custom,
                      label: Text('Custom'),
                    ),
                  ],
                  selected: {range},
                  onSelectionChanged: (selection) =>
                      onRangeChanged(selection.first),
                ),
                Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            if (results.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No staff records'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: results.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final result = results[index];
                  return _leaderboardTile(
                    result,
                    names[result.staffId] ?? result.staffId,
                    submissions: submissions
                        .where((item) => item.staffId == result.staffId)
                        .toList(),
                    onTap: onMemberTap == null
                        ? null
                        : () => onMemberTap!(result.staffId),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceBreakdown extends StatelessWidget {
  final String label;
  final double value;

  const _PerformanceBreakdown({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: Theme.of(context).textTheme.bodySmall,
      children: [
        TextSpan(text: '$label: '),
        TextSpan(
          text: value.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

Widget _submissionTile(
  VideoSubmission submission, {
  VoidCallback? onTap,
}) => ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Icon(
    submission.isApproved ? Icons.verified_outlined : Icons.error_outline,
  ),
  title: Text(
    submission.contentName.isEmpty
        ? submission.type.label
        : submission.contentName,
  ),
  subtitle: Text(
    '${DateFormat('EEE').format(submission.submittedAt)} - ${submission.checklistPassedCount}/5 checklist items',
  ),
  trailing: onTap == null
      ? Text(submission.isApproved ? 'Approved' : 'Review needed')
      : const Icon(Icons.chevron_right),
  onTap: onTap,
);

Future<void> _showSubmissionDetailsDialog(
  BuildContext context,
  VideoSubmission submission,
) {
  final checklistItems = <String>[
    'Checklist item 1',
    'Checklist item 2',
    'Checklist item 3',
    'Checklist item 4',
    'Checklist item 5',
  ];
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Record details'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecordDetail(
                label: 'Content',
                value: submission.contentName.isEmpty
                    ? submission.type.label
                    : submission.contentName,
              ),
              _RecordDetail(label: 'Type', value: submission.type.label),
              _RecordDetail(
                label: 'Date',
                value: DateFormat.yMMMMd().format(submission.submittedAt),
              ),
              _RecordDetail(
                label: 'Category',
                value: submission.pointCategory.label,
              ),
              _RecordDetail(
                label: 'Points',
                value: submission.scorePoints.toStringAsFixed(1),
              ),
              _RecordDetail(
                label: 'Status',
                value: submission.isApproved ? 'Approved' : 'Review needed',
              ),
              const SizedBox(height: 12),
              Text(
                'Checklist',
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ...List.generate(
                checklistItems.length,
                (index) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    submission.checklist.length > index &&
                            submission.checklist[index]
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                  ),
                  title: Text(checklistItems[index]),
                ),
              ),
              if (submission.contentLink.isNotEmpty)
                TextButton.icon(
                  onPressed: () =>
                      _openContentLink(dialogContext, submission.contentLink),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open content link'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _RecordDetail extends StatelessWidget {
  final String label;
  final String value;

  const _RecordDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('$label: $value'),
  );
}

Widget _leaderboardTile(
  WeeklyPerformance result,
  String name, {
  required List<VideoSubmission> submissions,
  VoidCallback? onTap,
}) {
  double pointsFor(bool Function(VideoSubmission submission) matches) =>
      submissions
          .where(matches)
          .fold<double>(
            0,
            (total, submission) => total + submission.scorePoints,
          );
  int piecesFor(bool Function(VideoSubmission submission) matches) =>
      submissions.where(matches).length;
  final totalPoints = pointsFor((_) => true);
  final content = Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(child: Text('${result.rank}')),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              const SizedBox(height: 2),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _PerformanceBreakdown(
                    label: 'Total points',
                    value: totalPoints,
                  ),
                  _PerformancePieceCount(
                    label: 'Total pieces',
                    count: submissions.length,
                  ),
                  for (final type in VideoType.values)
                    _PerformancePieceCount(
                      label: type.label,
                      count: piecesFor((item) => item.type == type),
                    ),
                  for (final category in PerformancePointCategory.values)
                    _PerformanceBreakdown(
                      label: category.label,
                      value: pointsFor(
                        (item) => item.pointCategory == category,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text('${result.formulaScore.toStringAsFixed(2)} performance pts'),
      ],
    ),
  );
  return onTap == null ? content : InkWell(onTap: onTap, child: content);
}

class _PerformancePieceCount extends StatelessWidget {
  final String label;
  final int count;

  const _PerformancePieceCount({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: Theme.of(context).textTheme.bodySmall,
      children: [
        TextSpan(text: '$label: '),
        TextSpan(
          text: '$count',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

Future<void> _showMemberPointsDialog(
  BuildContext context,
  WidgetRef ref, {
  required String memberName,
  required String staffId,
  required List<AppUser> staff,
  required List<VideoSubmission> submissions,
  required Map<String, String> names,
  bool canEdit = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$memberName point records'),
      content: SizedBox(
        width: 640,
        height: 460,
        child: Consumer(
          builder: (context, dialogRef, child) {
            final profile = dialogRef
                .watch(currentUserProfileProvider)
                .valueOrNull;
            final canManage =
                profile?.isAdmin == true ||
                profile?.canAccessPanel('performance') == true;
            final viewedStaffIds = canManage
                ? [staffId]
                : dialogRef.watch(currentStaffIdsProvider);
            final liveSubmissions = dialogRef.watch(
              canManage
                  ? performanceSubmissionsProvider
                  : myPerformanceSubmissionsProvider,
            );
            return liveSubmissions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load point records: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (items) => _MemberPointRecordList(
                dialogContext: dialogContext,
                ref: dialogRef,
                staff: staff,
                staffId: staffId,
                submissions: items
                    .where(
                      (submission) =>
                          viewedStaffIds.contains(submission.staffId),
                    )
                    .toList(),
                hours:
                    (dialogRef
                                .watch(
                                  canManage
                                      ? performanceHoursProvider
                                      : myPerformanceHoursProvider,
                                )
                                .valueOrNull ??
                            [])
                        .where(
                          (record) => viewedStaffIds.contains(record.staffId),
                        )
                        .toList(),
                names: names,
                canEdit: canEdit,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _MemberPointRecordList extends StatefulWidget {
  final BuildContext dialogContext;
  final WidgetRef ref;
  final List<AppUser> staff;
  final String staffId;
  final List<VideoSubmission> submissions;
  final List<DailyHours> hours;
  final Map<String, String> names;
  final bool canEdit;

  const _MemberPointRecordList({
    required this.dialogContext,
    required this.ref,
    required this.staff,
    required this.staffId,
    required this.submissions,
    required this.hours,
    required this.names,
    required this.canEdit,
  });

  @override
  State<_MemberPointRecordList> createState() => _MemberPointRecordListState();
}

class _MemberPointRecordListState extends State<_MemberPointRecordList> {
  var _range = _RecordRange.month;
  var _view = _PointRecordView.details;
  DateTime _activeDate = DateTime.now();
  DateTimeRange? _customRange;

  DateTime get _rangeStart {
    final day = DateUtils.dateOnly(_activeDate);
    return switch (_range) {
      _RecordRange.day => day,
      _RecordRange.week => _weekStart(day),
      _RecordRange.month => DateTime(day.year, day.month),
      _RecordRange.custom => _customRange?.start ?? day,
    };
  }

  DateTime get _rangeEnd {
    final start = _rangeStart;
    return switch (_range) {
      _RecordRange.day => start,
      _RecordRange.week => start.add(const Duration(days: 6)),
      _RecordRange.month => DateTime(start.year, start.month + 1, 0),
      _RecordRange.custom => _customRange?.end ?? start,
    };
  }

  String get _rangeLabel {
    if (_range == _RecordRange.day) {
      return DateFormat.yMMMMd().format(_rangeStart);
    }
    if (_range == _RecordRange.month) {
      return DateFormat.yMMMM().format(_rangeStart);
    }
    return '${DateFormat.yMMMd().format(_rangeStart)} - ${DateFormat.yMMMd().format(_rangeEnd)}';
  }

  List<VideoSubmission> get _filteredSubmissions =>
      widget.submissions.where((submission) {
          final day = DateUtils.dateOnly(submission.submittedAt);
          return !day.isBefore(_rangeStart) && !day.isAfter(_rangeEnd);
        }).toList()
        ..sort((left, right) => right.submittedAt.compareTo(left.submittedAt));

  List<DailyHours> get _filteredHours => widget.hours.where((record) {
    final day = DateUtils.dateOnly(record.date);
    return !day.isBefore(_rangeStart) && !day.isAfter(_rangeEnd);
  }).toList();

  void _shiftRange(int direction) {
    final days = _range == _RecordRange.day
        ? 1
        : _range == _RecordRange.week
        ? 7
        : 0;
    setState(() {
      _activeDate = days == 0
          ? DateTime(_activeDate.year, _activeDate.month + direction, 1)
          : _activeDate.add(Duration(days: days * direction));
    });
  }

  Future<void> _selectCustomRange() async {
    final range = await _showCompactDateRangePicker(
      context: widget.dialogContext,
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() => _customRange = range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSubmissions = _filteredSubmissions;
    final filteredHours = _filteredHours;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_RecordRange>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _RecordRange.day, label: Text('Day')),
                  ButtonSegment(value: _RecordRange.week, label: Text('Week')),
                  ButtonSegment(
                    value: _RecordRange.month,
                    label: Text('Month'),
                  ),
                  ButtonSegment(
                    value: _RecordRange.custom,
                    label: Text('Custom'),
                  ),
                ],
                selected: {_range},
                onSelectionChanged: (selection) async {
                  setState(() => _range = selection.first);
                  if (selection.first == _RecordRange.custom) {
                    await _selectCustomRange();
                  }
                },
              ),
            ),
            IconButton(
              tooltip: 'Choose custom date range',
              onPressed: _selectCustomRange,
              icon: const Icon(Icons.date_range_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous period',
              onPressed: _range == _RecordRange.custom
                  ? null
                  : () => _shiftRange(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _rangeLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Next period',
              onPressed: _range == _RecordRange.custom
                  ? null
                  : () => _shiftRange(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (widget.canEdit) ...[
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _showPointEntryDialog(
                  widget.dialogContext,
                  widget.ref,
                  widget.staff,
                  initialStaffId: widget.staffId,
                  lockStaff: true,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add points'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showHoursEntryDialog(
                  widget.dialogContext,
                  widget.ref,
                  staffId: widget.staffId,
                  initialDate: _activeDate,
                ),
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('Add hours'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _FilteredPointsSummary(
          submissions: filteredSubmissions,
          hours: filteredHours,
        ),
        const SizedBox(height: 12),
        SegmentedButton<_PointRecordView>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: _PointRecordView.details,
              icon: Icon(Icons.list_alt_outlined),
              label: Text('Details'),
            ),
            ButtonSegment(
              value: _PointRecordView.summary,
              icon: Icon(Icons.view_agenda_outlined),
              label: Text('Summary'),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (selection) {
            setState(() => _view = selection.first);
          },
        ),
        const Divider(height: 20),
        Expanded(
          child: _view == _PointRecordView.details
              ? _PointRecordDetails(
                  submissions: filteredSubmissions,
                  names: widget.names,
                  dialogContext: widget.dialogContext,
                  ref: widget.ref,
                  canEdit: widget.canEdit,
                )
              : _PointRecordSummary(submissions: filteredSubmissions),
        ),
      ],
    );
  }
}

class _PointRecordDetails extends StatelessWidget {
  final List<VideoSubmission> submissions;
  final Map<String, String> names;
  final BuildContext dialogContext;
  final WidgetRef ref;
  final bool canEdit;

  const _PointRecordDetails({
    required this.submissions,
    required this.names,
    required this.dialogContext,
    required this.ref,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return const Center(child: Text('No point records for this period.'));
    }
    return ListView.separated(
      itemCount: submissions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final submission = submissions[index];
        final label = submission.contentName.isEmpty
            ? submission.type.label
            : submission.contentName;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat.yMMMd().format(submission.submittedAt)} | ${submission.type.label} | ${submission.pointCategory.label}',
                    ),
                    Text('${submission.scorePoints.toStringAsFixed(1)} points'),
                    Text(
                      submission.isApproved
                          ? 'Signed off by ${names[submission.signedOffBy] ?? submission.signedOffBy}'
                          : 'Awaiting PM review',
                    ),
                    if (submission.contentLink.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _openContentLink(
                          dialogContext,
                          submission.contentLink,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open content link'),
                      ),
                    if (canEdit)
                      TextButton.icon(
                        onPressed: () => _confirmDeletePointRecord(
                          dialogContext,
                          ref,
                          submission,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete record'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Edit points',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      _showEditPointsDialog(dialogContext, ref, submission),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _confirmDeletePointRecord(
  BuildContext context,
  WidgetRef ref,
  VideoSubmission submission,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete point record?'),
      content: const Text('This permanently removes this point record.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref
        .read(firestoreServiceProvider)
        .deletePerformanceSubmission(submission.id);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not delete point record: $error')),
    );
  }
}

class _PointRecordSummary extends StatelessWidget {
  final List<VideoSubmission> submissions;

  const _PointRecordSummary({required this.submissions});

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<VideoSubmission>>{};
    for (final submission in submissions) {
      final day = DateUtils.dateOnly(submission.submittedAt);
      byDay.putIfAbsent(day, () => []).add(submission);
    }
    final days = byDay.keys.toList()
      ..sort((left, right) => right.compareTo(left));
    if (days.isEmpty) {
      return const Center(child: Text('No point records for this period.'));
    }
    return ListView.separated(
      itemCount: days.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final daySubmissions = byDay[days[index]]!;
        final total = daySubmissions.fold<double>(
          0,
          (sum, submission) => sum + submission.scorePoints,
        );
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(DateFormat.yMMMMd().format(days[index])),
          subtitle: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: VideoType.values.map((type) {
              final points = daySubmissions
                  .where((submission) => submission.type == type)
                  .fold<double>(
                    0,
                    (sum, submission) => sum + submission.scorePoints,
                  );
              return Text('${type.label}: ${points.toStringAsFixed(1)}');
            }).toList(),
          ),
          trailing: Text('${total.toStringAsFixed(1)} pts'),
        );
      },
    );
  }
}

class _FilteredPointsSummary extends StatelessWidget {
  final List<VideoSubmission> submissions;
  final List<DailyHours> hours;

  const _FilteredPointsSummary({
    required this.submissions,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    final totalPoints = submissions.fold<double>(
      0,
      (total, submission) => total + submission.scorePoints,
    );
    final totalHours = hours.fold<double>(
      0,
      (total, record) => total + record.hours,
    );
    final pointsByType = {
      for (final type in VideoType.values)
        type: submissions
            .where((submission) => submission.type == type)
            .fold<double>(
              0,
              (total, submission) => total + submission.scorePoints,
            ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${totalPoints.toStringAsFixed(1)} total points',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          totalHours == 0
              ? 'No hours saved for this period'
              : '${totalHours.toStringAsFixed(1)} hours logged | ${(totalPoints / totalHours).toStringAsFixed(2)} points/hr',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: VideoType.values
              .map(
                (type) => Text(
                  '${type.label}: ${pointsByType[type]!.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

Future<DateTimeRange?> _showCompactDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
}) {
  var start = initialDateRange?.start ?? DateTime.now();
  var end = initialDateRange?.end ?? start;
  var selectingEnd = initialDateRange != null;
  return showDialog<DateTimeRange>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Select date range'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Start date')),
                  ButtonSegment(value: true, label: Text('End date')),
                ],
                selected: {selectingEnd},
                onSelectionChanged: (selection) {
                  setState(() => selectingEnd = selection.first);
                },
              ),
              const SizedBox(height: 8),
              CalendarDatePicker(
                initialDate: selectingEnd ? end : start,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                onDateChanged: (date) {
                  setState(() {
                    if (selectingEnd) {
                      end = date.isBefore(start) ? start : date;
                    } else {
                      start = date;
                      if (end.isBefore(start)) end = start;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              DateTimeRange(start: start, end: end),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showPointEntryDialog(
  BuildContext context,
  WidgetRef ref,
  List<AppUser> staff, {
  String? initialStaffId,
  bool lockStaff = false,
}) async {
  var selectedStaff = staff.firstWhere(
    (user) => user.uid == initialStaffId,
    orElse: () => staff.first,
  );
  var type = VideoType.graphics;
  var pointsCategory = PerformancePointCategory.client;
  var submittedAt = DateTime.now();
  final contentNameController = TextEditingController();
  final contentLinkController = TextEditingController();
  final pointsController = TextEditingController();
  final reviewer = ref.read(firebaseAuthServiceProvider).getCurrentUser()?.uid;
  final submission = await showDialog<VideoSubmission>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add points'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AppUser>(
                initialValue: selectedStaff,
                items: staff
                    .map(
                      (user) => DropdownMenuItem(
                        value: user,
                        child: Text(user.name.isEmpty ? user.email : user.name),
                      ),
                    )
                    .toList(),
                onChanged: lockStaff
                    ? null
                    : (value) => setState(() => selectedStaff = value!),
                decoration: const InputDecoration(labelText: 'Staff member'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VideoType>(
                initialValue: type,
                items: VideoType.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => type = value!),
                decoration: const InputDecoration(labelText: 'Content type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentNameController,
                decoration: const InputDecoration(labelText: 'Content name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentLinkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Content link (optional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PerformancePointCategory>(
                initialValue: pointsCategory,
                items: PerformancePointCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => pointsCategory = value!),
                decoration: const InputDecoration(labelText: 'Points category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pointsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Awarded points'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Point date'),
                subtitle: Text(DateFormat.yMMMd().format(submittedAt)),
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: dialogContext,
                    initialDate: submittedAt,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (selectedDate != null) {
                    setState(() => submittedAt = selectedDate);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: reviewer == null
                ? null
                : () {
                    final awardedPoints = double.tryParse(
                      pointsController.text,
                    );
                    if (awardedPoints == null || awardedPoints < 0) {
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      VideoSubmission(
                        id: const Uuid().v4(),
                        staffId: selectedStaff.uid,
                        type: type,
                        submittedAt: submittedAt,
                        contentName: contentNameController.text.trim(),
                        contentLink: contentLinkController.text.trim(),
                        checklist: const [true, true, true, true, true],
                        uploadedToCorrectFolder: true,
                        signedOffBy: reviewer,
                        pointsCategory: pointsCategory,
                        awardedPoints: awardedPoints,
                      ),
                    );
                  },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
  pointsController.dispose();
  contentNameController.dispose();
  contentLinkController.dispose();
  if (submission != null) {
    try {
      await ref
          .read(firestoreServiceProvider)
          .createPerformanceSubmission(submission);
      ref.invalidate(performanceSubmissionsProvider);
      if (context.mounted) {
        await _showPointSaveResult(
          context,
          title: 'Points saved',
          message:
              '${submission.scorePoints.toStringAsFixed(1)} points were added for ${DateFormat.yMMMd().format(submission.submittedAt)}.',
          icon: Icons.check_circle_outline,
        );
      }
    } catch (error) {
      if (context.mounted) {
        await _showPointSaveResult(
          context,
          title: 'Points not saved',
          message: 'Could not save points: $error',
          icon: Icons.error_outline,
        );
      }
    }
  }
}

Future<void> _showHoursEntryDialog(
  BuildContext context,
  WidgetRef ref, {
  required String staffId,
  required DateTime initialDate,
}) async {
  var date = DateUtils.dateOnly(initialDate);
  String? hoursError;
  final hoursController = TextEditingController();
  final record = await showDialog<DailyHours>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add daily hours'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  if (hoursError != null) {
                    setState(() => hoursError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Hours worked (hours:minutes)',
                  hintText: 'Example: 8:30',
                  errorText: hoursError,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: date.isAfter(DateTime(2020))
                        ? () => setState(
                            () => date = date.subtract(const Duration(days: 1)),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Work date'),
                      subtitle: Text(DateFormat.yMMMd().format(date)),
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          setState(
                            () => date = DateUtils.dateOnly(selectedDate),
                          );
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: date.isBefore(DateTime(2100, 12, 31))
                        ? () => setState(
                            () => date = date.add(const Duration(days: 1)),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final hours = _parseWorkedHours(hoursController.text);
              if (hours == null || hours < 0 || hours > 24) {
                setState(
                  () => hoursError = 'Enter up to 24 hours, for example 8:30.',
                );
                return;
              }
              final dateKey = DateFormat('yyyyMMdd').format(date);
              Navigator.pop(
                dialogContext,
                DailyHours(
                  id: '${staffId}_$dateKey',
                  staffId: staffId,
                  date: date,
                  hours: hours,
                ),
              );
            },
            child: const Text('Save hours'),
          ),
        ],
      ),
    ),
  );
  hoursController.dispose();

  if (record == null) return;
  try {
    await ref.read(firestoreServiceProvider).savePerformanceHours(record);
    ref.invalidate(performanceHoursProvider);
    if (context.mounted) {
      await _showPointSaveResult(
        context,
        title: 'Hours saved',
        message:
            '${record.hours.toStringAsFixed(1)} hours were saved for ${DateFormat.yMMMd().format(record.date)}.',
        icon: Icons.check_circle_outline,
      );
    }
  } catch (error) {
    if (context.mounted) {
      await _showPointSaveResult(
        context,
        title: 'Hours not saved',
        message: 'Could not save hours: $error',
        icon: Icons.error_outline,
      );
    }
  }
}

Future<void> _showPointSaveResult(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [Icon(icon), const SizedBox(width: 12), Text(title)],
      ),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _openContentLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a valid content link.')),
    );
  }
}

Future<void> _showEditPointsDialog(
  BuildContext context,
  WidgetRef ref,
  VideoSubmission submission,
) async {
  var type = submission.type;
  var pointsCategory = submission.pointCategory;
  var submittedAt = submission.submittedAt;
  final contentNameController = TextEditingController(
    text: submission.contentName,
  );
  final contentLinkController = TextEditingController(
    text: submission.contentLink,
  );
  final pointsController = TextEditingController(
    text: submission.awardedPoints?.toString() ?? '',
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Edit points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<VideoType>(
              initialValue: type,
              items: VideoType.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => type = value!),
              decoration: const InputDecoration(labelText: 'Content type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentNameController,
              decoration: const InputDecoration(labelText: 'Content name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentLinkController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Content link (optional)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PerformancePointCategory>(
              initialValue: pointsCategory,
              items: PerformancePointCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => pointsCategory = value!),
              decoration: const InputDecoration(labelText: 'Points category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Awarded points'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Point date'),
              subtitle: Text(DateFormat.yMMMd().format(submittedAt)),
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: dialogContext,
                  initialDate: submittedAt,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selectedDate != null) {
                  setState(() => submittedAt = selectedDate);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final awardedPoints = double.tryParse(pointsController.text);
              if (awardedPoints == null || awardedPoints < 0) {
                return;
              }
              await ref
                  .read(firestoreServiceProvider)
                  .updatePerformanceSubmission(
                    submissionId: submission.id,
                    submittedAt: submittedAt,
                    contentName: contentNameController.text.trim(),
                    contentLink: contentLinkController.text.trim(),
                    type: type.name,
                    pointsCategory: pointsCategory.name,
                    awardedPoints: awardedPoints,
                  );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    ),
  );
  pointsController.dispose();
  contentNameController.dispose();
  contentLinkController.dispose();
}
