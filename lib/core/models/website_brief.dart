import 'package:cloud_firestore/cloud_firestore.dart';

enum WebsiteBriefStatus {
  clientDraft,
  submitted,
  changesRequested,
  awaitingApproval,
  approved,
}

class WebsiteBrief {
  final String id;
  final String clientId;
  final String planId;
  final String planName;
  final WebsiteBriefStatus status;
  final Map<String, dynamic> sections;
  final String reviewNote;
  final List<String> requestedSections;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  const WebsiteBrief({
    required this.id,
    required this.clientId,
    required this.planId,
    required this.planName,
    this.status = WebsiteBriefStatus.clientDraft,
    this.sections = const {},
    this.reviewNote = '',
    this.requestedSections = const [],
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    this.approvedAt,
    this.approvedBy,
  });

  factory WebsiteBrief.fromFirestore(DocumentSnapshot doc) {
    return WebsiteBrief.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  factory WebsiteBrief.fromMap(String id, Map<String, dynamic> data) {
    DateTime readDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    DateTime? readNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final now = DateTime.now();
    return WebsiteBrief(
      id: id,
      clientId: data['clientId']?.toString() ?? '',
      planId: data['planId']?.toString() ?? id,
      planName: data['planName']?.toString() ?? '',
      status: WebsiteBriefStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => WebsiteBriefStatus.clientDraft,
      ),
      sections: Map<String, dynamic>.from(data['sections'] as Map? ?? const {}),
      reviewNote: data['reviewNote']?.toString() ?? '',
      requestedSections: (data['requestedSections'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      createdAt: readDate(data['createdAt'], now),
      updatedAt: readDate(data['updatedAt'], now),
      submittedAt: readNullableDate(data['submittedAt']),
      approvedAt: readNullableDate(data['approvedAt']),
      approvedBy: data['approvedBy']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'planId': planId,
      'planName': planName,
      'status': status.name,
      'sections': sections,
      'reviewNote': reviewNote,
      'requestedSections': requestedSections,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'approvedBy': approvedBy,
    };
  }

  WebsiteBrief copyWith({
    WebsiteBriefStatus? status,
    Map<String, dynamic>? sections,
    String? reviewNote,
    List<String>? requestedSections,
    DateTime? updatedAt,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? approvedBy,
    bool clearReviewNote = false,
  }) {
    return WebsiteBrief(
      id: id,
      clientId: clientId,
      planId: planId,
      planName: planName,
      status: status ?? this.status,
      sections: sections ?? this.sections,
      reviewNote: clearReviewNote ? '' : (reviewNote ?? this.reviewNote),
      requestedSections: requestedSections ?? this.requestedSections,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }

  int get completionPercent {
    const requiredSections = [
      'basics',
      'goals',
      'pages',
      'features',
      'design',
      'references',
      'content',
      'domain',
      'timeline',
    ];
    final completed = requiredSections.where((key) {
      final value = sections[key];
      return value is Map &&
          value.values.any((item) {
            if (item is String) return item.trim().isNotEmpty;
            if (item is List) return item.isNotEmpty;
            if (item is bool) return item;
            return item != null;
          });
    }).length;
    return ((completed / requiredSections.length) * 100).round();
  }

  bool get clientCanEdit =>
      status == WebsiteBriefStatus.clientDraft ||
      status == WebsiteBriefStatus.changesRequested;
}
