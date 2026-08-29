import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';

enum TaskStatus { draft, inProgress, awaitingConfirmation, completed }

List<String> _normalizePlanFeatures(List<String> features) {
  final normalized = <String>[];
  final deliverablePattern = RegExp(
    r'(\d+)\s+(?:short\s+)?(reels?|videos?|designs?|photos?)',
    caseSensitive: false,
  );

  for (final raw in features) {
    final parsed = raw.split(': ');
    final category = parsed.length > 1 ? parsed.first : null;
    final text = parsed.length > 1 ? parsed.sublist(1).join(': ') : raw;
    final matches = deliverablePattern.allMatches(text).toList();

    if (matches.length < 2) {
      normalized.add(raw);
      continue;
    }

    for (final match in matches) {
      final item = '${match.group(1)} ${match.group(2)}';
      normalized.add(category == null ? item : '$category: $item');
    }
  }
  return normalized;
}

List<String> _standardContentFeatures(String name, PlanType type) {
  final planName = name.toLowerCase();
  if (type == PlanType.setup) {
    final quantities = planName.contains('complete')
        ? (16, 8)
        : planName.contains('standard')
        ? (8, 4)
        : planName.contains('basic')
        ? (4, 2)
        : (2, 1);
    return [
      'Content: ${quantities.$1} reels',
      'Content: ${quantities.$2} designs',
    ];
  }
  final quantities = planName.contains('scale')
      ? (20, 6, 4)
      : planName.contains('equity')
      ? (20, 8, 4)
      : (8, 4, 2);
  return [
    'Content: ${quantities.$1} reels',
    'Content: ${quantities.$2} designs',
    'Content: ${quantities.$3} videos',
  ];
}

List<String> _normalizeStandardPlanContent(
  List<String> features,
  String name,
  PlanType type,
) {
  final normalized = _normalizePlanFeatures(features);
  final isStandardTier = RegExp(
    r'starter|basic|standard|complete|growth partner|scale partner|equity partner',
    caseSensitive: false,
  ).hasMatch(name);
  if (!isStandardTier) return normalized;
  final withoutContent = normalized.where((raw) {
    final separator = raw.indexOf(': ');
    final category = separator > 0 ? raw.substring(0, separator) : '';
    return category.toLowerCase() != 'content';
  }).toList();
  return [...withoutContent, ..._standardContentFeatures(name, type)];
}

// App user account (Firebase Auth + Firestore role profile)
class AppUser {
  final String uid;
  final String email;
  final String name;
  final bool isAdmin;
  final String role;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.isAdmin,
    this.role = '',
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
      role: data['role'] ?? '',
    );
  }
}

// Client model
class Client {
  final String id;
  final String name;
  final String? ownerName;
  final String category;
  final String contactEmail;
  final String contactPhone;
  final String? assignedManager;
  final ClientStage stage;
  final DateTime createdDate;
  final DateTime? updatedDate;
  final String? notes;
  final DateTime? followUpAt;
  final String? followUpNotes;

  Client({
    required this.id,
    required this.name,
    this.ownerName,
    required this.category,
    required this.contactEmail,
    required this.contactPhone,
    this.assignedManager,
    required this.stage,
    required this.createdDate,
    this.updatedDate,
    this.notes,
    this.followUpAt,
    this.followUpNotes,
  });

  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      name: data['name'] ?? '',
      ownerName: data['ownerName'] ?? data['owner'] ?? data['contactName'],
      category: data['category'] ?? '',
      contactEmail: data['contactEmail'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      assignedManager: data['assignedManager'],
      stage: ClientStage.values.firstWhere(
        (s) => s.name == data['stage'],
        orElse: () => ClientStage.reach,
      ),
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      updatedDate: data['updatedDate'] != null
          ? (data['updatedDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      followUpAt: data['followUpAt'] != null
          ? (data['followUpAt'] as Timestamp).toDate()
          : null,
      followUpNotes: data['followUpNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerName': ownerName,
      'category': category,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'assignedManager': assignedManager,
      'stage': stage.name,
      'createdDate': Timestamp.fromDate(createdDate),
      'updatedDate': updatedDate != null
          ? Timestamp.fromDate(updatedDate!)
          : null,
      'notes': notes,
      'followUpAt': followUpAt != null ? Timestamp.fromDate(followUpAt!) : null,
      'followUpNotes': followUpNotes,
    };
  }

  Client copyWith({
    String? id,
    String? name,
    String? ownerName,
    bool clearOwnerName = false,
    String? category,
    String? contactEmail,
    String? contactPhone,
    String? assignedManager,
    ClientStage? stage,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? notes,
    DateTime? followUpAt,
    String? followUpNotes,
    bool clearFollowUp = false,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: clearOwnerName ? ownerName : ownerName ?? this.ownerName,
      category: category ?? this.category,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      assignedManager: assignedManager ?? this.assignedManager,
      stage: stage ?? this.stage,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      notes: notes ?? this.notes,
      followUpAt: clearFollowUp ? followUpAt : followUpAt ?? this.followUpAt,
      followUpNotes: clearFollowUp
          ? followUpNotes
          : followUpNotes ?? this.followUpNotes,
    );
  }
}

// Baseline model
class Baseline {
  final String id;
  final String clientId;
  final int leadsPerMonth;
  final double conversionRate;
  final double avgOrderValue;
  final DateTime capturedDate;

  Baseline({
    required this.id,
    required this.clientId,
    required this.leadsPerMonth,
    required this.conversionRate,
    required this.avgOrderValue,
    required this.capturedDate,
  });

  factory Baseline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Baseline(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      leadsPerMonth: data['leadsPerMonth'] ?? 0,
      conversionRate: (data['conversionRate'] ?? 0.0).toDouble(),
      avgOrderValue: (data['avgOrderValue'] ?? 0.0).toDouble(),
      capturedDate: (data['capturedDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'leadsPerMonth': leadsPerMonth,
      'conversionRate': conversionRate,
      'avgOrderValue': avgOrderValue,
      'capturedDate': Timestamp.fromDate(capturedDate),
    };
  }
}

// Reusable pricing plan template (managed centrally, applied to any client)
class PlanTemplate {
  final String id;
  final PlanType type;
  final String name;
  final double price;
  final List<String> features;
  final DateTime createdDate;

  PlanTemplate({
    required this.id,
    required this.type,
    required this.name,
    required this.price,
    required this.features,
    required this.createdDate,
  });

  factory PlanTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = PlanType.values.firstWhere(
      (p) => p.name == data['type'],
      orElse: () => PlanType.setup,
    );
    return PlanTemplate(
      id: doc.id,
      type: type,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      features: _normalizeStandardPlanContent(
        List<String>.from(data['features'] ?? []),
        data['name'] ?? '',
        type,
      ),
      createdDate: data['createdDate'] != null
          ? (data['createdDate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'name': name,
      'price': price,
      'features': features,
      'createdDate': Timestamp.fromDate(createdDate),
    };
  }

  PlanTemplate copyWith({
    String? id,
    PlanType? type,
    String? name,
    double? price,
    List<String>? features,
    DateTime? createdDate,
  }) {
    return PlanTemplate(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      price: price ?? this.price,
      features: features ?? this.features,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}

class PaymentRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String? planId;
  final String? planName;
  final double amount;
  final String transactionId;
  final String paymentMethod;
  final DateTime paymentDate;
  final String? notes;
  final PaymentStatus status;
  final DateTime createdDate;
  final DateTime? reviewedDate;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? paymentLink;
  final DateTime? requestSentDate;
  final String? requestSentBy;

  PaymentRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.planId,
    this.planName,
    required this.amount,
    required this.transactionId,
    required this.paymentMethod,
    required this.paymentDate,
    this.notes,
    this.status = PaymentStatus.pending,
    required this.createdDate,
    this.reviewedDate,
    this.reviewedBy,
    this.rejectionReason,
    this.paymentLink,
    this.requestSentDate,
    this.requestSentBy,
  });

  factory PaymentRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentRecord(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      planId: data['planId'],
      planName: data['planName'],
      amount: (data['amount'] ?? 0).toDouble(),
      transactionId: data['transactionId'] ?? '',
      paymentMethod: data['paymentMethod'] ?? '',
      paymentDate: (data['paymentDate'] as Timestamp).toDate(),
      notes: data['notes'],
      status: PaymentStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      reviewedDate: data['reviewedDate'] != null
          ? (data['reviewedDate'] as Timestamp).toDate()
          : null,
      reviewedBy: data['reviewedBy'],
      rejectionReason: data['rejectionReason'],
      paymentLink: data['paymentLink'],
      requestSentDate: data['requestSentDate'] != null
          ? (data['requestSentDate'] as Timestamp).toDate()
          : null,
      requestSentBy: data['requestSentBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'planId': planId,
      'planName': planName,
      'amount': amount,
      'transactionId': transactionId,
      'paymentMethod': paymentMethod,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'notes': notes,
      'status': status.name,
      'createdDate': Timestamp.fromDate(createdDate),
      'reviewedDate': reviewedDate != null
          ? Timestamp.fromDate(reviewedDate!)
          : null,
      'reviewedBy': reviewedBy,
      'rejectionReason': rejectionReason,
      'paymentLink': paymentLink,
      'requestSentDate': requestSentDate != null
          ? Timestamp.fromDate(requestSentDate!)
          : null,
      'requestSentBy': requestSentBy,
    };
  }
}

// Plan assigned to a client — a customizable snapshot, optionally linked
// back to the [PlanTemplate] it was created from.
class Plan {
  final String id;
  final String clientId;
  final String? templateId;
  final PlanType type;
  final String name;
  final double price;
  final List<String> features;
  final List<String> completedFeatures;
  final Map<String, int> featureProgress;
  final Map<String, Map<String, dynamic>> taskWorkflow;
  final DateTime startDate;
  final DateTime? endDate;

  Plan({
    required this.id,
    required this.clientId,
    this.templateId,
    required this.type,
    required this.name,
    required this.price,
    required this.features,
    this.completedFeatures = const [],
    this.featureProgress = const {},
    this.taskWorkflow = const {},
    required this.startDate,
    this.endDate,
  });

  /// Progress as a 0.0–1.0 fraction of features marked complete.
  double get progress {
    if (features.isEmpty) return 0;
    return completedFeatures.length / features.length;
  }

  bool get isCompleted =>
      features.isNotEmpty && completedFeatures.length >= features.length;

  factory Plan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = PlanType.values.firstWhere(
      (p) => p.name == data['type'],
      orElse: () => PlanType.setup,
    );
    return Plan(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      templateId: data['templateId'],
      type: type,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      features: _normalizeStandardPlanContent(
        List<String>.from(data['features'] ?? []),
        data['name'] ?? '',
        type,
      ),
      completedFeatures: List<String>.from(data['completedFeatures'] ?? []),
      featureProgress: (data['featureProgress'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value as int)),
      taskWorkflow: (data['taskWorkflow'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'templateId': templateId,
      'type': type.name,
      'name': name,
      'price': price,
      'features': features,
      'completedFeatures': completedFeatures,
      'featureProgress': featureProgress,
      'taskWorkflow': taskWorkflow,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    };
  }

  Plan copyWith({
    String? id,
    String? clientId,
    String? templateId,
    PlanType? type,
    String? name,
    double? price,
    List<String>? features,
    List<String>? completedFeatures,
    Map<String, int>? featureProgress,
    Map<String, Map<String, dynamic>>? taskWorkflow,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return Plan(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      templateId: templateId ?? this.templateId,
      type: type ?? this.type,
      name: name ?? this.name,
      price: price ?? this.price,
      features: features ?? this.features,
      completedFeatures: completedFeatures ?? this.completedFeatures,
      featureProgress: featureProgress ?? this.featureProgress,
      taskWorkflow: taskWorkflow ?? this.taskWorkflow,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

// Setup Checklist Item model
class SetupChecklistItem {
  final String id;
  final String clientId;
  final String itemName;
  final bool isDone;
  final DateTime? dueDate;
  final int? displayOrder;

  SetupChecklistItem({
    required this.id,
    required this.clientId,
    required this.itemName,
    required this.isDone,
    this.dueDate,
    this.displayOrder,
  });

  factory SetupChecklistItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SetupChecklistItem(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      itemName: data['itemName'] ?? '',
      isDone: data['isDone'] ?? false,
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      displayOrder: data['displayOrder'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'itemName': itemName,
      'isDone': isDone,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'displayOrder': displayOrder,
    };
  }

  SetupChecklistItem copyWith({
    String? id,
    String? clientId,
    String? itemName,
    bool? isDone,
    DateTime? dueDate,
    int? displayOrder,
  }) {
    return SetupChecklistItem(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      itemName: itemName ?? this.itemName,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate ?? this.dueDate,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}

// Software Stage model
class SoftwareStageData {
  final String id;
  final String clientId;
  final String appType;
  final SoftwareStage stage;
  final List<String> panelsEnabled;
  final DateTime? freePeriodStart;
  final DateTime? freePeriodEnd;
  final String customizationLevel;

  SoftwareStageData({
    required this.id,
    required this.clientId,
    required this.appType,
    required this.stage,
    required this.panelsEnabled,
    this.freePeriodStart,
    this.freePeriodEnd,
    required this.customizationLevel,
  });

  DateTime? get freePeriodEndDate => freePeriodEnd;

  int get freePeriodDaysRemaining {
    if (freePeriodEnd == null) return 0;
    return freePeriodEnd!.difference(DateTime.now()).inDays;
  }

  factory SoftwareStageData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SoftwareStageData(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      appType: data['appType'] ?? '',
      stage: SoftwareStage.values.firstWhere(
        (s) => s.name == data['stage'],
        orElse: () => SoftwareStage.notStarted,
      ),
      panelsEnabled: List<String>.from(data['panelsEnabled'] ?? []),
      freePeriodStart: data['freePeriodStart'] != null
          ? (data['freePeriodStart'] as Timestamp).toDate()
          : null,
      freePeriodEnd: data['freePeriodEnd'] != null
          ? (data['freePeriodEnd'] as Timestamp).toDate()
          : null,
      customizationLevel: data['customizationLevel'] ?? 'None',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'appType': appType,
      'stage': stage.name,
      'panelsEnabled': panelsEnabled,
      'freePeriodStart': freePeriodStart != null
          ? Timestamp.fromDate(freePeriodStart!)
          : null,
      'freePeriodEnd': freePeriodEnd != null
          ? Timestamp.fromDate(freePeriodEnd!)
          : null,
      'customizationLevel': customizationLevel,
    };
  }
}

// Content Log model
class ContentLog {
  final String id;
  final String clientId;
  final int month;
  final int year;
  final int weekNumber;
  final int imagesDelivered;
  final int reelsDelivered;
  final int revisionRounds;
  final String? notes;
  final DateTime createdDate;

  ContentLog({
    required this.id,
    required this.clientId,
    required this.month,
    required this.year,
    required this.weekNumber,
    required this.imagesDelivered,
    required this.reelsDelivered,
    required this.revisionRounds,
    this.notes,
    required this.createdDate,
  });

  factory ContentLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentLog(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      month: data['month'] ?? 1,
      year: data['year'] ?? DateTime.now().year,
      weekNumber: data['weekNumber'] ?? 1,
      imagesDelivered: data['imagesDelivered'] ?? 0,
      reelsDelivered: data['reelsDelivered'] ?? 0,
      revisionRounds: data['revisionRounds'] ?? 0,
      notes: data['notes'],
      createdDate: data['createdDate'] != null
          ? (data['createdDate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'month': month,
      'year': year,
      'weekNumber': weekNumber,
      'imagesDelivered': imagesDelivered,
      'reelsDelivered': reelsDelivered,
      'revisionRounds': revisionRounds,
      'notes': notes,
      'createdDate': Timestamp.fromDate(createdDate),
    };
  }
}

// Goal model
class Goal {
  final String id;
  final String clientId;
  final GoalType type;
  final double baselineValue;
  final double liftPercentage;
  final double targetValue;
  final String period;
  final GoalStage stage;
  final double? progressValue;
  final bool guaranteeLinked;
  final DateTime? createdDate;
  final DateTime? targetDate;

  Goal({
    required this.id,
    required this.clientId,
    required this.type,
    required this.baselineValue,
    required this.liftPercentage,
    required this.targetValue,
    required this.period,
    required this.stage,
    this.progressValue,
    required this.guaranteeLinked,
    this.createdDate,
    this.targetDate,
  });

  double get progressPercentage {
    if (targetValue == 0) return 0;
    return ((progressValue ?? 0) / targetValue * 100).clamp(0, 100);
  }

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Goal(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      type: GoalType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => GoalType.leads,
      ),
      baselineValue: (data['baselineValue'] ?? 0.0).toDouble(),
      liftPercentage: (data['liftPercentage'] ?? 0.0).toDouble(),
      targetValue: (data['targetValue'] ?? 0.0).toDouble(),
      period: data['period'] ?? 'Monthly',
      stage: GoalStage.values.firstWhere(
        (s) => s.name == data['stage'],
        orElse: () => GoalStage.draft,
      ),
      progressValue: data['progressValue'] != null
          ? (data['progressValue']).toDouble()
          : null,
      guaranteeLinked: data['guaranteeLinked'] ?? false,
      createdDate: data['createdDate'] != null
          ? (data['createdDate'] as Timestamp).toDate()
          : null,
      targetDate: data['targetDate'] != null
          ? (data['targetDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'type': type.name,
      'baselineValue': baselineValue,
      'liftPercentage': liftPercentage,
      'targetValue': targetValue,
      'period': period,
      'stage': stage.name,
      'progressValue': progressValue,
      'guaranteeLinked': guaranteeLinked,
      'createdDate': createdDate != null
          ? Timestamp.fromDate(createdDate!)
          : null,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
    };
  }

  Goal copyWith({
    String? id,
    String? clientId,
    GoalType? type,
    double? baselineValue,
    double? liftPercentage,
    double? targetValue,
    String? period,
    GoalStage? stage,
    double? progressValue,
    bool? guaranteeLinked,
    DateTime? createdDate,
    DateTime? targetDate,
  }) {
    return Goal(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      baselineValue: baselineValue ?? this.baselineValue,
      liftPercentage: liftPercentage ?? this.liftPercentage,
      targetValue: targetValue ?? this.targetValue,
      period: period ?? this.period,
      stage: stage ?? this.stage,
      progressValue: progressValue ?? this.progressValue,
      guaranteeLinked: guaranteeLinked ?? this.guaranteeLinked,
      createdDate: createdDate ?? this.createdDate,
      targetDate: targetDate ?? this.targetDate,
    );
  }
}

// Consultation model
class Consultation {
  final String id;
  final String clientId;
  final DateTime dateTime;
  final ConsultationStatus status;
  final String? notes;
  final String? managerId;

  Consultation({
    required this.id,
    required this.clientId,
    required this.dateTime,
    required this.status,
    this.notes,
    this.managerId,
  });

  factory Consultation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Consultation(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      status: ConsultationStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ConsultationStatus.scheduled,
      ),
      notes: data['notes'],
      managerId: data['managerId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status.name,
      'notes': notes,
      'managerId': managerId,
    };
  }
}

// Guarantee Event model
class GuaranteeEvent {
  final String id;
  final String clientId;
  final String goalId;
  final bool feeWaived;
  final DateTime resolutionDate;

  GuaranteeEvent({
    required this.id,
    required this.clientId,
    required this.goalId,
    required this.feeWaived,
    required this.resolutionDate,
  });

  factory GuaranteeEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GuaranteeEvent(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      goalId: data['goalId'] ?? '',
      feeWaived: data['feeWaived'] ?? false,
      resolutionDate: (data['resolutionDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'goalId': goalId,
      'feeWaived': feeWaived,
      'resolutionDate': Timestamp.fromDate(resolutionDate),
    };
  }
}
