import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyReport {
  final String id;
  final String clientId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<String> completedWork;
  final List<String> inProgressWork;
  final List<String> awaitingApprovalWork;
  final String summary;
  final bool published;
  final DateTime createdAt;
  final DateTime? publishedAt;

  const WeeklyReport({
    required this.id,
    required this.clientId,
    required this.periodStart,
    required this.periodEnd,
    this.completedWork = const [],
    this.inProgressWork = const [],
    this.awaitingApprovalWork = const [],
    this.summary = '',
    this.published = false,
    required this.createdAt,
    this.publishedAt,
  });

  factory WeeklyReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime date(String key) =>
        (data[key] as Timestamp?)?.toDate() ?? DateTime.now();
    List<String> items(String key) => (data[key] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    return WeeklyReport(
      id: doc.id,
      clientId: data['clientId']?.toString() ?? '',
      periodStart: date('periodStart'),
      periodEnd: date('periodEnd'),
      completedWork: items('completedWork'),
      inProgressWork: items('inProgressWork'),
      awaitingApprovalWork: items('awaitingApprovalWork'),
      summary: data['summary']?.toString() ?? '',
      published: data['published'] == true,
      createdAt: date('createdAt'),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'clientId': clientId,
    'periodStart': Timestamp.fromDate(periodStart),
    'periodEnd': Timestamp.fromDate(periodEnd),
    'completedWork': completedWork,
    'inProgressWork': inProgressWork,
    'awaitingApprovalWork': awaitingApprovalWork,
    'summary': summary.trim(),
    'published': published,
    'createdAt': Timestamp.fromDate(createdAt),
    'publishedAt': publishedAt == null
        ? null
        : Timestamp.fromDate(publishedAt!),
  };
}
