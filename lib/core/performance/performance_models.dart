import 'package:cloud_firestore/cloud_firestore.dart';

enum VideoType {
  graphics('Graphics'),
  reels('Reels'),
  videos('Videos');

  final String label;
  const VideoType(this.label);
}

enum PerformancePointCategory {
  client('Client'),
  tutorial('Tutorial'),
  practice('Practice');

  final String label;
  const PerformancePointCategory(this.label);
}

class VideoSubmission {
  final String id;
  final String staffId;
  final VideoType type;
  final DateTime submittedAt;
  final String contentName;
  final String contentLink;
  final List<bool> checklist;
  final bool uploadedToCorrectFolder;
  final String? signedOffBy;
  final PerformancePointCategory? pointsCategory;
  final double? awardedPoints;

  const VideoSubmission({
    required this.id,
    required this.staffId,
    required this.type,
    required this.submittedAt,
    this.contentName = '',
    this.contentLink = '',
    this.checklist = const [],
    this.uploadedToCorrectFolder = false,
    this.signedOffBy,
    this.pointsCategory,
    this.awardedPoints,
  });

  int get checklistPassedCount => checklist.where((item) => item).length;
  double get checklistPercent =>
      checklist.isEmpty ? 0 : checklistPassedCount / 5;
  bool get needsResubmission => checklistPercent < .8;
  bool get isApproved =>
      checklist.length == 5 &&
      !needsResubmission &&
      uploadedToCorrectFolder &&
      signedOffBy != null;
  PerformancePointCategory get pointCategory =>
      pointsCategory ?? PerformancePointCategory.values[type.index];
  double get scorePoints => awardedPoints ?? 0;

  factory VideoSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoSubmission(
      id: doc.id,
      staffId: data['staffId'] as String? ?? '',
      type: VideoType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => VideoType.graphics,
      ),
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contentName: data['contentName'] as String? ?? '',
      contentLink: data['contentLink'] as String? ?? '',
      checklist: (data['checklist'] as List<dynamic>? ?? const [])
          .map((item) => item == true)
          .toList(),
      uploadedToCorrectFolder: data['uploadedToCorrectFolder'] == true,
      signedOffBy: data['signedOffBy'] as String?,
      pointsCategory: PerformancePointCategory.values.firstWhere(
        (category) => category.name == data['pointsCategory'],
        orElse: () =>
            PerformancePointCategory.values[VideoType.values
                .firstWhere(
                  (type) => type.name == data['type'],
                  orElse: () => VideoType.graphics,
                )
                .index],
      ),
      awardedPoints: (data['awardedPoints'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'staffId': staffId,
    'type': type.name,
    'submittedAt': Timestamp.fromDate(submittedAt),
    'contentName': contentName,
    'contentLink': contentLink,
    'checklist': checklist,
    'uploadedToCorrectFolder': uploadedToCorrectFolder,
    'signedOffBy': signedOffBy,
    'pointsCategory': pointCategory.name,
    if (awardedPoints != null) 'awardedPoints': awardedPoints,
  };
}

class DailyHours {
  final String id;
  final String staffId;
  final DateTime date;
  final double hours;

  const DailyHours({
    required this.id,
    required this.staffId,
    required this.date,
    required this.hours,
  });

  factory DailyHours.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyHours(
      id: doc.id,
      staffId: data['staffId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hours: (data['hours'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'staffId': staffId,
    'date': Timestamp.fromDate(date),
    'hours': hours,
  };
}

class AttendanceRecord {
  final String id;
  final String staffId;
  final DateTime date;
  final bool present;

  const AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.date,
    required this.present,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      id: doc.id,
      staffId: data['staffId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      present: data['present'] == true,
    );
  }
}

class WeeklyPerformance {
  static const int attendancePayout = 2500;
  static const int performancePoolPoints = 130;
  static const List<double> rankPoints = [12.5, 10, 7.5, 2.5];

  final String staffId;
  final int graphicsCount;
  final int reelsCount;
  final int videosCount;
  final double contentPoints;
  final double hoursWorked;
  final int presentDays;
  final int rank;
  final Map<DateTime, double> pointsByDay;

  const WeeklyPerformance({
    required this.staffId,
    required this.graphicsCount,
    required this.reelsCount,
    required this.videosCount,
    required this.contentPoints,
    required this.hoursWorked,
    required this.presentDays,
    required this.rank,
    this.pointsByDay = const {},
  });

  int get dailyBaselineUnits => graphicsCount + reelsCount + videosCount;
  double get formulaScore => hoursWorked == 0 ? 0 : contentPoints / hoursWorked;
  double get allocatedPerformancePoints =>
      rank > 0 && rank <= rankPoints.length ? rankPoints[rank - 1] : 0;
  int get projectedPayout =>
      attendancePayout + allocatedPerformancePoints.round();
}

class PerformanceCalculator {
  const PerformanceCalculator._();

  static List<WeeklyPerformance> rank({
    required Iterable<String> staffIds,
    required Iterable<VideoSubmission> submissions,
    required Map<String, double> hoursByStaff,
    required Map<String, int> presentDaysByStaff,
  }) {
    final performance =
        staffIds.map((staffId) {
          final approved = submissions.where(
            (submission) =>
                submission.staffId == staffId && submission.isApproved,
          );
          final pointsByDay = <DateTime, double>{};
          for (final submission in approved) {
            final submittedAt = submission.submittedAt;
            final day = DateTime(
              submittedAt.year,
              submittedAt.month,
              submittedAt.day,
            );
            pointsByDay.update(
              day,
              (total) => total + submission.scorePoints,
              ifAbsent: () => submission.scorePoints,
            );
          }
          return WeeklyPerformance(
            staffId: staffId,
            graphicsCount: approved
                .where((item) => item.type == VideoType.graphics)
                .length,
            reelsCount: approved
                .where((item) => item.type == VideoType.reels)
                .length,
            videosCount: approved
                .where((item) => item.type == VideoType.videos)
                .length,
            contentPoints: approved.fold<double>(
              0,
              (total, item) => total + item.scorePoints,
            ),
            hoursWorked: hoursByStaff[staffId] ?? 0,
            presentDays: presentDaysByStaff[staffId] ?? 0,
            rank: 0,
            pointsByDay: pointsByDay,
          );
        }).toList()..sort(
          (left, right) => right.formulaScore.compareTo(left.formulaScore),
        );

    return [
      for (var index = 0; index < performance.length; index++)
        WeeklyPerformance(
          staffId: performance[index].staffId,
          graphicsCount: performance[index].graphicsCount,
          reelsCount: performance[index].reelsCount,
          videosCount: performance[index].videosCount,
          contentPoints: performance[index].contentPoints,
          hoursWorked: performance[index].hoursWorked,
          presentDays: performance[index].presentDays,
          rank: index + 1,
          pointsByDay: performance[index].pointsByDay,
        ),
    ];
  }
}
