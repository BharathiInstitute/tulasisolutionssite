import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';
import '../chat/cloud_function_service.dart';
import '../models/client_deduplication.dart';
import '../models/models.dart';
import '../models/weekly_report.dart';
import '../performance/performance_models.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.message}');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.message}');
      rethrow;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if user is admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.get('isAdmin') ?? false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      final staffDoc = await _getUserDocument(email);
      if (staffDoc.exists) {
        return AppUser.fromFirestore(staffDoc, isAdminOverride: false);
      }
    }

    final directDoc = await _getUserDocument(uid);
    return directDoc.exists ? AppUser.fromFirestore(directDoc) : null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDocument(
    String documentId,
  ) {
    return _firestore
        .collection('users')
        .doc(documentId)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Timed out loading your profile. Check your internet connection.',
          ),
        );
  }

  Stream<AppUser?> getUserProfileStream(String uid) {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return _firestore
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
    }

    return _firestore.collection('users').doc(email).snapshots().asyncMap((
      doc,
    ) async {
      if (doc.exists) return AppUser.fromFirestore(doc, isAdminOverride: false);
      return getUserProfile(uid);
    });
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Auth state stream
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Query<Map<String, dynamic>> _performanceQuery(
    String collection, {
    List<String>? staffIds,
  }) {
    final query = _firestore.collection(collection);
    return staffIds == null ? query : query.where('staffId', whereIn: staffIds);
  }

  Stream<List<VideoSubmission>> getPerformanceSubmissionsStream({
    List<String>? staffIds,
  }) {
    return _performanceQuery(
      'performance_submissions',
      staffIds: staffIds,
    ).snapshots().map(
      (snapshot) => snapshot.docs.map(VideoSubmission.fromFirestore).toList(),
    );
  }

  Stream<List<DailyHours>> getPerformanceHoursStream({List<String>? staffIds}) {
    return _performanceQuery(
      'performance_hours',
      staffIds: staffIds,
    ).snapshots().map(
      (snapshot) => snapshot.docs.map(DailyHours.fromFirestore).toList(),
    );
  }

  Stream<List<AttendanceRecord>> getPerformanceAttendanceStream({
    List<String>? staffIds,
  }) {
    return _performanceQuery(
      'performance_attendance',
      staffIds: staffIds,
    ).snapshots().map(
      (snapshot) => snapshot.docs.map(AttendanceRecord.fromFirestore).toList(),
    );
  }

  Future<void> createPerformanceSubmission(VideoSubmission submission) {
    return _firestore
        .collection('performance_submissions')
        .doc(submission.id)
        .set(submission.toFirestore());
  }

  Future<void> savePerformanceHours(DailyHours record) {
    return _firestore
        .collection('performance_hours')
        .doc(record.id)
        .set(record.toFirestore());
  }

  Future<void> approvePerformanceSubmission({
    required String submissionId,
    required List<bool> checklist,
    required bool uploadedToCorrectFolder,
    required String approvedBy,
    required String pointsCategory,
    required double awardedPoints,
  }) {
    return _firestore
        .collection('performance_submissions')
        .doc(submissionId)
        .update({
          'checklist': checklist,
          'uploadedToCorrectFolder': uploadedToCorrectFolder,
          'signedOffBy': approvedBy,
          'pointsCategory': pointsCategory,
          'awardedPoints': awardedPoints,
          'approvedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updatePerformanceSubmission({
    required String submissionId,
    required DateTime submittedAt,
    required String contentName,
    required String contentLink,
    required String type,
    required String pointsCategory,
    required double awardedPoints,
  }) {
    return _firestore
        .collection('performance_submissions')
        .doc(submissionId)
        .update({
          'submittedAt': Timestamp.fromDate(submittedAt),
          'contentName': contentName,
          'contentLink': contentLink,
          'type': type,
          'pointsCategory': pointsCategory,
          'awardedPoints': awardedPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deletePerformanceSubmission(String submissionId) {
    return _firestore
        .collection('performance_submissions')
        .doc(submissionId)
        .delete();
  }

  // Users (admin management)
  Stream<List<AppUser>> getUsersStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList(),
        );
  }

  Future<void> setUserAdminStatus(String uid, bool isAdmin) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isAdmin': isAdmin,
      });
    } catch (e) {
      print('Error updating user admin status: $e');
      rethrow;
    }
  }

  Future<void> addStaffMember({
    required String name,
    required String email,
    required String password,
    required String role,
    String team = '',
    List<String> panels = const [],
  }) async {
    await CloudFunctionService().call('createStaffAccount', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role.trim(),
      'team': team.trim(),
      'panels': {...defaultStaffPanels, ...panels}.toList(),
    }, 0);
  }

  Future<void> updateStaffMember({
    required String uid,
    required String name,
    required String role,
    required String team,
    required List<String> panels,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'name': name.trim(),
      'role': role.trim(),
      'team': team.trim(),
      'isAdmin': false,
      'isStaff': true,
      'panels': {...defaultStaffPanels, ...panels}.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteStaffMember(String uid, String confirmation) async {
    await CloudFunctionService().call('deleteStaffAccount', {
      'uid': uid,
      'confirmation': confirmation,
    }, 0);
  }

  // Clients
  Future<void> createClient(Client client) async {
    try {
      await _firestore
          .collection('clients')
          .doc(client.id)
          .set(client.toFirestore())
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              'Timed out reaching Firestore. Check your internet connection.',
            ),
          );
    } catch (e) {
      print('Error creating client: $e');
      rethrow;
    }
  }

  Future<bool> createClientIfAbsent(Client client) async {
    final clientRef = _firestore.collection('clients').doc(client.id);
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(clientRef);
      if (existing.exists) return false;
      transaction.set(clientRef, client.toFirestore());
      return true;
    });
  }

  Future<Client?> getClient(String clientId) async {
    try {
      final doc = await _firestore.collection('clients').doc(clientId).get();
      if (doc.exists) {
        return Client.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting client: $e');
      rethrow;
    }
  }

  Stream<List<Client>> getClientsStream() {
    return _firestore.collection('clients').snapshots().map((snapshot) {
      final clients = snapshot.docs
          .map((doc) => Client.fromFirestore(doc))
          .toList();
      clients.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      return clients;
    });
  }

  // One-time fetch, used instead of the live stream when the persistent
  // real-time connection is blocked by the network (proxy/antivirus).
  Future<List<Client>> getClientsOnce() async {
    final query = _firestore.collection('clients');
    late QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    }
    final clients = deduplicateClientsByPhone(
      snapshot.docs.map((doc) => Client.fromFirestore(doc)),
    );
    clients.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    return clients;
  }

  Future<void> updateClient(Client client) async {
    try {
      await _firestore
          .collection('clients')
          .doc(client.id)
          .update(client.copyWith(updatedDate: DateTime.now()).toFirestore());
    } catch (e) {
      print('Error updating client: $e');
      rethrow;
    }
  }

  Future<void> setClientArchived(String clientId, bool isArchived) {
    return _firestore.collection('clients').doc(clientId).update({
      'isArchived': isArchived,
      'updatedDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteClient(String clientId) {
    return _firestore.collection('clients').doc(clientId).delete();
  }

  // Setup Checklist Items
  Future<void> createChecklistItem(SetupChecklistItem item) async {
    try {
      await _firestore
          .collection('clients')
          .doc(item.clientId)
          .collection('checklist')
          .doc(item.id)
          .set(item.toFirestore());
    } catch (e) {
      print('Error creating checklist item: $e');
      rethrow;
    }
  }

  Stream<List<SetupChecklistItem>> getChecklistItems(String clientId) {
    return _firestore
        .collection('clients')
        .doc(clientId)
        .collection('checklist')
        .orderBy('displayOrder')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SetupChecklistItem.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> updateChecklistItem(SetupChecklistItem item) async {
    try {
      await _firestore
          .collection('clients')
          .doc(item.clientId)
          .collection('checklist')
          .doc(item.id)
          .update(item.toFirestore());
    } catch (e) {
      print('Error updating checklist item: $e');
      rethrow;
    }
  }

  // Goals
  Future<void> createGoal(Goal goal) async {
    try {
      await _firestore
          .collection('clients')
          .doc(goal.clientId)
          .collection('goals')
          .doc(goal.id)
          .set(goal.toFirestore());
    } catch (e) {
      print('Error creating goal: $e');
      rethrow;
    }
  }

  Stream<List<Goal>> getGoalsStream(String clientId) {
    return _firestore
        .collection('clients')
        .doc(clientId)
        .collection('goals')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList(),
        );
  }

  Future<void> updateGoal(Goal goal) async {
    try {
      await _firestore
          .collection('clients')
          .doc(goal.clientId)
          .collection('goals')
          .doc(goal.id)
          .update(goal.toFirestore());
    } catch (e) {
      print('Error updating goal: $e');
      rethrow;
    }
  }

  Future<void> deleteGoal(String clientId, String goalId) async {
    try {
      await _firestore
          .collection('clients')
          .doc(clientId)
          .collection('goals')
          .doc(goalId)
          .delete();
    } catch (e) {
      print('Error deleting goal: $e');
      rethrow;
    }
  }

  // Consultations
  Future<void> createConsultation(Consultation consultation) async {
    try {
      await _firestore
          .collection('consultations')
          .doc(consultation.id)
          .set(consultation.toFirestore());
    } catch (e) {
      print('Error creating consultation: $e');
      rethrow;
    }
  }

  Stream<List<Consultation>> getConsultationsStream(String clientId) {
    return _firestore
        .collection('consultations')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Consultation.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<Consultation>> getAllConsultationsStream() {
    return _firestore
        .collection('consultations')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Consultation.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> updateConsultation(Consultation consultation) async {
    try {
      await _firestore
          .collection('consultations')
          .doc(consultation.id)
          .update(consultation.toFirestore());
    } catch (e) {
      print('Error updating consultation: $e');
      rethrow;
    }
  }

  // Plans
  Future<void> createPlan(Plan plan) async {
    try {
      await _firestore.collection('plans').doc(plan.id).set(plan.toFirestore());
    } catch (e) {
      print('Error creating plan: $e');
      rethrow;
    }
  }

  Stream<List<Plan>> getAllPlansStream() {
    return _firestore
        .collection('plans')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Plan.fromFirestore(doc)).toList(),
        );
  }

  // One-time fetch, used instead of the live stream when the persistent
  // real-time connection is blocked by the network (proxy/antivirus).
  Future<List<Plan>> getAllPlansOnce() async {
    final query = _firestore
        .collection('plans')
        .orderBy('startDate', descending: true);
    late QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    }
    return snapshot.docs.map((doc) => Plan.fromFirestore(doc)).toList();
  }

  Stream<List<Plan>> getPlansStream(String clientId) {
    return _firestore
        .collection('plans')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Plan.fromFirestore(doc)).toList(),
        );
  }

  Future<void> updatePlan(Plan plan) async {
    try {
      await _firestore
          .collection('plans')
          .doc(plan.id)
          .update(plan.toFirestore());
    } catch (e) {
      print('Error updating plan: $e');
      rethrow;
    }
  }

  Future<void> deletePlan(String planId) async {
    try {
      await _firestore.collection('plans').doc(planId).delete();
    } catch (e) {
      print('Error deleting plan: $e');
      rethrow;
    }
  }

  Stream<List<WeeklyReport>> getWeeklyReportsStream(String clientId) {
    return _firestore
        .collection('weekly_reports')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) {
          final reports = snapshot.docs
              .map(WeeklyReport.fromFirestore)
              .toList();
          reports.sort(
            (left, right) => right.periodEnd.compareTo(left.periodEnd),
          );
          return reports;
        });
  }

  Future<void> saveWeeklyReport(WeeklyReport report) {
    return _firestore
        .collection('weekly_reports')
        .doc(report.id)
        .set(report.toFirestore());
  }

  // Payments
  Stream<List<PaymentRecord>> getPaymentsStream() {
    return _firestore
        .collection('payments')
        .orderBy('createdDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentRecord.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> createPayment(PaymentRecord payment) async {
    final document = payment.id.isEmpty
        ? _firestore.collection('payments').doc()
        : _firestore.collection('payments').doc(payment.id);
    await document.set(payment.toFirestore());
  }

  Future<void> reviewPayment({
    required String paymentId,
    required PaymentStatus status,
    String? rejectionReason,
  }) async {
    if (status == PaymentStatus.pending) {
      throw ArgumentError('A review must verify or reject the payment.');
    }

    final reviewer = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
    await _firestore.collection('payments').doc(paymentId).update({
      'status': status.name,
      'reviewedDate': FieldValue.serverTimestamp(),
      'reviewedBy': reviewer,
      'rejectionReason': status == PaymentStatus.rejected
          ? rejectionReason
          : null,
    });
  }

  // Plan templates (reusable master pricing plans)
  Future<void> createPlanTemplate(PlanTemplate template) async {
    try {
      await _firestore
          .collection('plan_templates')
          .doc(template.id)
          .set(template.toFirestore());
    } catch (e) {
      print('Error creating plan template: $e');
      rethrow;
    }
  }

  Stream<List<PlanTemplate>> getPlanTemplatesStream() {
    return _firestore
        .collection('plan_templates')
        .orderBy('createdDate')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PlanTemplate.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> updatePlanTemplate(PlanTemplate template) async {
    try {
      await _firestore
          .collection('plan_templates')
          .doc(template.id)
          .update(template.toFirestore());
    } catch (e) {
      print('Error updating plan template: $e');
      rethrow;
    }
  }

  Future<void> deletePlanTemplate(String templateId) async {
    try {
      await _firestore.collection('plan_templates').doc(templateId).delete();
    } catch (e) {
      print('Error deleting plan template: $e');
      rethrow;
    }
  }

  // Software Stage
  Future<void> createOrUpdateSoftwareStage(SoftwareStageData stageData) async {
    try {
      await _firestore
          .collection('clients')
          .doc(stageData.clientId)
          .collection('software_stage')
          .doc('current')
          .set(stageData.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print('Error updating software stage: $e');
      rethrow;
    }
  }

  Future<SoftwareStageData?> getSoftwareStage(String clientId) async {
    try {
      final doc = await _firestore
          .collection('clients')
          .doc(clientId)
          .collection('software_stage')
          .doc('current')
          .get();
      if (doc.exists) {
        return SoftwareStageData.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting software stage: $e');
      rethrow;
    }
  }

  Stream<SoftwareStageData?> getSoftwareStageStream(String clientId) {
    return _firestore
        .collection('clients')
        .doc(clientId)
        .collection('software_stage')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? SoftwareStageData.fromFirestore(doc) : null);
  }

  // Content Log
  Future<void> createContentLog(ContentLog log) async {
    try {
      await _firestore
          .collection('clients')
          .doc(log.clientId)
          .collection('content_logs')
          .doc(log.id)
          .set(log.toFirestore());
    } catch (e) {
      print('Error creating content log: $e');
      rethrow;
    }
  }

  Stream<List<ContentLog>> getContentLogsStream(String clientId) {
    return _firestore
        .collection('clients')
        .doc(clientId)
        .collection('content_logs')
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .orderBy('weekNumber', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ContentLog.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> updateContentLog(ContentLog log) async {
    try {
      await _firestore
          .collection('clients')
          .doc(log.clientId)
          .collection('content_logs')
          .doc(log.id)
          .update(log.toFirestore());
    } catch (e) {
      print('Error updating content log: $e');
      rethrow;
    }
  }

  Future<void> deleteContentLog(String clientId, String logId) async {
    try {
      await _firestore
          .collection('clients')
          .doc(clientId)
          .collection('content_logs')
          .doc(logId)
          .delete();
    } catch (e) {
      print('Error deleting content log: $e');
      rethrow;
    }
  }
}
