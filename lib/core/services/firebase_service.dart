import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/enums.dart';
import '../chat/cloud_function_service.dart';
import '../models/client_deduplication.dart';
import '../models/models.dart';
import '../tasks/task_workflow.dart';
import '../tasks/sales_record_options.dart';
import '../tasks/plan_changes.dart';
import '../performance/performance_models.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final http.Client? _profileHttpClient;

  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? profileHttpClient,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _profileHttpClient = profileHttpClient;

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
      final staffProfile = await _readUserProfile(
        email,
        isAdminOverride: false,
      );
      if (staffProfile != null) return staffProfile;
    }

    return _readUserProfile(uid);
  }

  Future<AppUser?> _readUserProfile(
    String documentId, {
    bool? isAdminOverride,
  }) async {
    if (useHttpProfileReads) {
      return _readUserProfileOverHttp(
        documentId,
        isAdminOverride: isAdminOverride,
      );
    }
    try {
      final doc = await getUserDocument(documentId);
      return doc.exists
          ? AppUser.fromFirestore(doc, isAdminOverride: isAdminOverride)
          : null;
    } catch (error) {
      if (!isRetryableProfileLoadError(error)) rethrow;
      return _readUserProfileOverHttp(
        documentId,
        isAdminOverride: isAdminOverride,
      );
    }
  }

  // WebChannel can stall on operator networks even with long polling enabled.
  @protected
  bool get useHttpProfileReads => kIsWeb;

  Future<AppUser?> _readUserProfileOverHttp(
    String documentId, {
    bool? isAdminOverride,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      throw FirebaseAuthException(code: 'user-token-expired');
    }
    final uri = Uri(
      scheme: 'https',
      host: 'firestore.googleapis.com',
      pathSegments: [
        'v1',
        'projects',
        _firestore.app.options.projectId,
        'databases',
        '(default)',
        'documents',
        'users',
        documentId,
      ],
    );
    final headers = {'Authorization': 'Bearer $token'};
    late http.Response response;
    try {
      response =
          await (_profileHttpClient?.get(uri, headers: headers) ??
                  http.get(uri, headers: headers))
              .timeout(const Duration(seconds: 15));
    } on http.ClientException {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: switch (response.statusCode) {
          401 => 'unauthenticated',
          403 => 'permission-denied',
          429 => 'resource-exhausted',
          >= 500 => 'unavailable',
          _ => 'unknown',
        },
      );
    }
    final document = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = document['fields'] as Map<String, dynamic>? ?? const {};
    dynamic decodeField(dynamic field) {
      final value = field as Map<String, dynamic>;
      if (value.containsKey('stringValue')) return value['stringValue'];
      if (value.containsKey('booleanValue')) return value['booleanValue'];
      if (value.containsKey('arrayValue')) {
        final values =
            value['arrayValue']['values'] as List<dynamic>? ?? const [];
        return values.map(decodeField).toList();
      }
      if (value.containsKey('nullValue')) return null;
      throw const FormatException('Unsupported staff profile field type');
    }

    final data = <String, dynamic>{
      for (final name in [
        'email',
        'name',
        'isAdmin',
        'isStaff',
        'role',
        'team',
        'panels',
      ])
        if (fields.containsKey(name)) name: decodeField(fields[name]),
    };
    return AppUser.fromMap(documentId, data, isAdminOverride: isAdminOverride);
  }

  @protected
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(
    String documentId,
  ) {
    return _firestore
        .collection('users')
        .doc(documentId)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
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

bool isRetryableProfileLoadError(Object error) =>
    error is TimeoutException ||
    (error is FirebaseException &&
        const {
          'unavailable',
          'deadline-exceeded',
          'network-request-failed',
          'cancelled',
          'resource-exhausted',
        }.contains(error.code));

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<T> _runTransaction<T>(TransactionHandler<T> handler) async {
    ({Object error, StackTrace stack})? callbackFailure;
    try {
      return await _firestore.runTransaction<T>((transaction) async {
        callbackFailure = null;
        try {
          return await handler(transaction);
        } catch (error, stack) {
          // The web SDK boxes Dart callback errors inside a JavaScript error.
          callbackFailure = (error: error, stack: stack);
          rethrow;
        }
      });
    } catch (_) {
      final failure = callbackFailure;
      if (failure != null) {
        Error.throwWithStackTrace(failure.error, failure.stack);
      }
      rethrow;
    }
  }

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

  Future<Client?> getClient(String clientId, {bool serverOnly = false}) async {
    try {
      final doc = await _firestore
          .collection('clients')
          .doc(clientId)
          .get(
            GetOptions(
              source: serverOnly ? Source.server : Source.serverAndCache,
            ),
          );
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
    return ClientSnapshotList(clients, serverConfirmed: !snapshot.metadata.isFromCache);
  }

  Future<void> updateClient(Client client, {AppUser? actor}) async {
    if (actor != null && !actor.canAccessPanel('leads') && !actor.canAccessPanel('clients')) {
      throw StateError('Customer record edit access is required.');
    }
    try {
      final data = client.copyWith(updatedDate: DateTime.now()).toFirestore()
        ..remove('salesRecord')
        ..remove('referredByClientId');
      final reference = _firestore.collection('clients').doc(client.id);
      await _runTransaction((transaction) async {
        final current = await transaction.get(reference);
        if (!current.exists) throw StateError('This customer no longer exists.');
        final stored = Client.fromFirestore(current);
        if (actor != null && stored.salesRecord['revision'] != client.salesRecord['revision']) {
          throw PlanSaveConflict('The customer record changed. Reopen it before changing the stage.');
        }
        if (stored.stage == client.stage && stored.salesProgress != client.salesProgress) {
          data.remove('salesProgress');
        }
        if (stored.stage != client.stage) {
          data['salesProgress'] = '';
          data['stageChangedAt'] = FieldValue.serverTimestamp();
          if (actor != null) {
            final log = reference.collection('salesActivity').doc();
            transaction.set(log, {
              'id': log.id,
              'at': DateTime.now().toUtc().toIso8601String(),
              'event': 'Stage changed',
              'title': client.stage.displayName,
              'recordedBy': actor.uid,
              'recordedByName': actor.name.isEmpty ? actor.email : actor.name,
              'previousStage': stored.stage.name,
              'stage': client.stage.name,
              'previousProgress': stored.salesProgress,
              'progress': '',
            });
          }
        }
        if ((current.data()?['salesRecord'] as Map?)?.isNotEmpty == true) {
          data.remove('followUpAt');
          data.remove('followUpNotes');
        }
        if (stored.stage != client.stage && client.stage == ClientStage.lost) {
          data['followUpAt'] = null;
          if (stored.salesRecord.isNotEmpty) {
            data['salesRecord'] = {
              ...stored.salesRecord,
              'status': 'completed',
              'dueAt': null,
              'revision': reference.collection('salesActivity').doc().id,
            };
          }
        } else if (stored.stage == ClientStage.lost && client.stage != ClientStage.lost &&
            stored.salesRecord.isNotEmpty) {
          data['salesRecord'] = {
            ...stored.salesRecord,
            'status': 'assigned',
            'revision': reference.collection('salesActivity').doc().id,
          };
        }
        transaction.update(reference, data);
      });
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

  Future<void> recordSalesContact({
    required String clientId,
    required String method,
    required String outcome,
    required String notes,
    required String recordedBy,
    ClientStage? stage,
  }) async {
    final clientRef = _firestore.collection('clients').doc(clientId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(clientRef);
      if (!snapshot.exists) throw StateError('This lead no longer exists.');
      final history =
          (snapshot.data()?['salesContacts'] as List<dynamic>? ?? const [])
              .toList();
      history.add({
        'method': method,
        'outcome': outcome,
        'notes': notes,
        'recordedBy': recordedBy,
        'at': DateTime.now().toIso8601String(),
      });
      transaction.update(clientRef, {
        'salesContacts': history.length > 50
            ? history.sublist(history.length - 50)
            : history,
        'updatedDate': FieldValue.serverTimestamp(),
        if (stage != null) 'stage': ClientStage.fromStoredName(stage.name).name,
        if (stage != null) 'stageChangedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteClient(String clientId) {
    return _firestore.collection('clients').doc(clientId).delete();
  }

  Stream<List<Map<String, dynamic>>> salesActivity(String clientId) =>
      _firestore.collection('clients').doc(clientId).collection('salesActivity')
          .orderBy('at', descending: true).snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());

  Future<Client> saveCustomerSalesUpdate({
    required Client client,
    required AppUser actor,
    required ClientStage stage,
    required String? progress,
    required DateTime? dueAt,
    required bool doNotContact,
    SalesTask? legacyTask,
    String? notes,
  }) async {
    if (progress != null && progress.isNotEmpty &&
        !salesStageUpdates[ClientStage.fromStoredName(stage.name)]!.contains(progress)) {
      throw ArgumentError('Select an update for the chosen stage.');
    }
    return saveCustomerSalesRecord(
      client: client, actor: actor, stage: stage, progress: progress,
      dueAt: dueAt, doNotContact: doNotContact, legacyTask: legacyTask,
      title: 'Sales update', action: 'Update',
      notes: notes ?? client.salesRecord['notes']?.toString() ?? '', outcome: '',
      completeAction: false, nextTitle: '', nextAction: '', updateOnly: true,
    );
  }

  Future<Client> saveCustomerSalesRecord({
    required Client client,
    required AppUser actor,
    required String title,
    required String action,
    required String notes,
    required String outcome,
    required bool completeAction,
    required DateTime? dueAt,
    required String nextTitle,
    required String nextAction,
    required ClientStage stage,
    SalesTask? legacyTask,
    String? customerResponse,
    String? nextStep,
    int? reminderDays,
    int? reminderTimeMinutes,
    bool? doNotContact,
    String? progress,
    bool updateOnly = false,
  }) async {
    if (!actor.canAccessPanel('leads') && !actor.canAccessPanel('clients')) {
      throw StateError('Customer record edit access is required.');
    }
    if (title.trim().isEmpty || (completeAction && outcome.trim().isEmpty) ||
        (completeAction && dueAt != null && nextTitle.trim().isEmpty)) {
      throw ArgumentError('An action title, completion outcome, and scheduled next-action title are required.');
    }
    if (completeAction && legacyTask != null && !actor.canAccessPanel('tasks')) {
      throw StateError('Assign Tasks access is required to complete an existing Sales task.');
    }
    final structured = customerResponse != null;
    if (updateOnly && (structured || completeAction)) {
      throw ArgumentError('A simple sales update cannot complete a legacy action.');
    }
    if (updateOnly && (doNotContact ?? client.doNotContact) && dueAt != null) {
      throw ArgumentError('Clear the reminder for a Do not contact customer.');
    }
    if (stage == ClientStage.lost && (dueAt != null || (nextStep != null && nextStep != 'No next step'))) {
      throw ArgumentError('Closed customers cannot have an active next action or reminder. Reopen the customer first.');
    }
    final selectedProgress = progress ?? (stage == client.stage ? client.salesProgress : '');
    if (selectedProgress.isNotEmpty &&
        salesProgressLabel(stage, selectedProgress) == 'Not recorded') {
      throw ArgumentError('Select a progress option for the chosen stage.');
    }
    if (structured) {
      if (!salesActionOutcomes.containsKey(action) ||
          (outcome.isNotEmpty && !salesActionOutcomes[action]!.contains(outcome)) ||
          !salesCustomerResponses.contains(customerResponse) ||
          !salesNextSteps.containsKey(nextStep)) {
        throw ArgumentError('Select a supported action, outcome, customer response and next step.');
      }
      final hasNext = nextStep != 'No next step';
      if ((!completeAction && hasNext) ||
          (completeAction && hasNext && (dueAt == null || salesNextSteps[nextStep] != nextAction)) ||
          (completeAction && !hasNext && dueAt != null) ||
          ((doNotContact ?? client.doNotContact) && (dueAt != null || hasNext)) ||
          (customerResponse == 'Do not contact' && doNotContact != true)) {
        throw ArgumentError('Confirm the next step and reminder, or clear both for Do not contact.');
      }
      if ((reminderDays == null) != (reminderTimeMinutes == null) ||
          (reminderDays != null && (!salesReminderDays.containsKey(reminderDays) ||
              reminderTimeMinutes! < 0 || reminderTimeMinutes >= 1440 || dueAt == null ||
              dueAt.toLocal().hour * 60 + dueAt.toLocal().minute != reminderTimeMinutes ||
              !dueAt.isAfter(DateTime.now())))) {
        throw ArgumentError('Select a valid future reminder interval and time.');
      }
    }
    if (structured || updateOnly) {
      final previousDue = client.salesRecord.isEmpty
          ? (legacyTask == null
              ? client.followUpAt
              : taskDueAt(legacyTask.plan, legacyTask.feature))
          : DateTime.tryParse(client.salesRecord['dueAt']?.toString() ?? '');
      if (dueAt != null && dueAt != previousDue && !dueAt.isAfter(DateTime.now())) {
        throw ArgumentError('Select a future reminder date and time.');
      }
    }
    final clientRef = _firestore.collection('clients').doc(client.id);
    final logRef = clientRef.collection('salesActivity').doc();
    final planRef = completeAction && legacyTask != null
        ? _firestore.collection('plans').doc(legacyTask.plan.id)
        : null;
    return _runTransaction<Client>((transaction) async {
      final customer = await transaction.get(clientRef);
      final storedPlan = planRef == null ? null : await transaction.get(planRef);
      if (!customer.exists) throw PlanSaveConflict('This customer no longer exists.');
      final current = Client.fromFirestore(customer);
      if (current.salesRecord['revision'] != client.salesRecord['revision'] ||
          (updateOnly && current.salesRecord['notes'] != client.salesRecord['notes']) ||
          (client.salesRecord.isEmpty &&
              (current.notes != client.notes || current.followUpAt != client.followUpAt ||
                  current.followUpNotes != client.followUpNotes)) ||
          current.stage != client.stage ||
          current.salesProgress != client.salesProgress ||
          current.doNotContact != client.doNotContact) {
        throw PlanSaveConflict('The Sales record changed. Reopen it before saving.');
      }
      if (planRef != null && legacyTask != null) {
        if (storedPlan?.exists != true) throw PlanSaveConflict('The original Sales task no longer exists.');
        final stored = Plan.fromFirestore(storedPlan!);
        final feature = legacyTask.feature;
        if (!stored.features.contains(feature) ||
            taskStatus(stored, feature) != taskStatus(legacyTask.plan, feature) ||
            taskDueAt(stored, feature) != taskDueAt(legacyTask.plan, feature) ||
            taskInternalNotes(stored, feature) != taskInternalNotes(legacyTask.plan, feature)) {
          throw PlanSaveConflict('The Sales task changed. Reopen the record before completing it.');
        }
        final completed = setTaskStatus(stored, feature, TaskStatus.completed, actor: actor);
        transaction.update(planRef, {'taskWorkflow': completed.taskWorkflow});
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final next = completeAction && dueAt != null;
      final summary = structured ? salesActivitySummary(
        action: action, outcome: outcome, response: customerResponse,
        nextStep: nextStep!,
        stage: stage, progress: selectedProgress,
      ) : null;
      final blocked = doNotContact ?? current.doNotContact;
      final record = {
        if (updateOnly) ...current.salesRecord,
        'title': updateOnly
            ? (selectedProgress.isEmpty ? 'Sales follow-up' : selectedProgress)
            : structured ? (next ? nextStep : action) : next ? nextTitle.trim() : title.trim(),
        'action': updateOnly ? current.salesRecord['action'] ?? action : next ? nextAction : action,
        'notes': structured ? current.salesRecord['notes'] ?? '' : notes.trim(),
        if (updateOnly) ...{
          'reminderDays': null,
          'reminderTimeMinutes': null,
          'legacyNotes': {
            ...?((current.salesRecord['legacyNotes'] as List?)?.whereType<String>().toSet()),
            if (current.followUpNotes?.isNotEmpty == true) current.followUpNotes!,
            if (current.salesRecord['notes']?.toString().isNotEmpty == true) current.salesRecord['notes'].toString(),
          }.toList(),
        },
        if (structured) ...{
          'customerResponse': customerResponse,
          'outcome': outcome,
          'nextStep': nextStep,
          'summary': summary,
          'reminderDays': reminderDays,
          'reminderTimeMinutes': reminderTimeMinutes,
          'legacyNotes': {
            ...?((current.salesRecord['legacyNotes'] as List?)?.whereType<String>().toSet()),
            if (current.followUpNotes?.isNotEmpty == true) current.followUpNotes!,
            if (current.salesRecord['notes']?.toString().isNotEmpty == true) current.salesRecord['notes'].toString(),
          }.toList(),
        },
        'status': stage == ClientStage.lost ? 'completed' :
            current.stage == ClientStage.lost && stage != ClientStage.lost && !completeAction
                ? 'assigned' : completeAction
            ? (next ? 'assigned' : 'completed')
            : dueAt != null && current.salesRecord['status'] == 'completed'
                ? 'assigned'
                : current.salesRecord['status'] ?? 'assigned',
        'dueAt': dueAt?.toIso8601String(),
        'assignedTo': current.salesRecord['assignedTo'] ??
            (legacyTask == null ? actor.uid : taskAssigneeId(legacyTask.plan, legacyTask.feature)) ?? actor.uid,
        'assignedToName': current.salesRecord['assignedToName'] ??
            (legacyTask == null ? actor.name : taskAssigneeName(legacyTask.plan, legacyTask.feature)) ?? actor.name,
        'revision': logRef.id,
        'updatedAt': now,
      };
      transaction.set(logRef, {
        'id': logRef.id,
        'at': now,
        'recordedBy': actor.uid,
        'recordedByName': actor.name.isEmpty ? actor.email : actor.name,
        'event': updateOnly ? 'Progress updated' : completeAction ? 'Action completed' : 'Record updated',
        'title': updateOnly ? record['title'] : structured ? action : title.trim(),
        'method': action,
        if (!updateOnly) 'outcome': outcome.trim(),
        if (!structured && !updateOnly) 'notes': notes.trim(),
        if (updateOnly) ...{
          'doNotContact': blocked,
          'previousDoNotContact': current.doNotContact,
          if (notes.trim() != (current.salesRecord['notes']?.toString() ?? '')) ...{
            'notes': notes.trim(),
            'previousNotes': current.salesRecord['notes'] ?? '',
          },
        },
        if (structured) ...{
          'customerResponse': customerResponse,
          'nextStep': nextStep,
          'summary': summary,
          'reminderDays': reminderDays,
          'reminderTimeMinutes': reminderTimeMinutes,
          'doNotContact': blocked,
          'previousDoNotContact': current.doNotContact,
        },
        'previousReminder': current.salesRecord.isEmpty
            ? (legacyTask == null ? client.followUpAt?.toIso8601String() : taskDueAt(legacyTask.plan, legacyTask.feature)?.toIso8601String())
            : current.salesRecord['dueAt'],
        'nextReminder': dueAt?.toIso8601String(),
        'nextTitle': next ? structured ? nextStep : nextTitle.trim() : null,
        'nextAction': next ? nextAction : null,
        'previousStage': current.stage.name,
        'stage': stage.name,
        'previousProgress': current.salesProgress,
        'progress': selectedProgress,
        if (legacyTask != null) 'legacyTask': {'planId': legacyTask.plan.id, 'feature': legacyTask.feature},
      });
      transaction.update(clientRef, {
        'salesRecord': record,
        'salesProgress': selectedProgress,
        'followUpAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
        if (!structured && !updateOnly) 'followUpNotes': notes.trim(),
        if (structured || updateOnly) 'doNotContact': blocked,
        'updatedDate': FieldValue.serverTimestamp(),
        if (stage != current.stage) 'stage': ClientStage.fromStoredName(stage.name).name,
        if (stage != current.stage) 'stageChangedAt': FieldValue.serverTimestamp(),
      });
      return current.copyWith(
        salesRecord: record,
        salesProgress: selectedProgress,
        stage: ClientStage.fromStoredName(stage.name),
        followUpAt: dueAt,
        followUpNotes: structured || updateOnly ? current.followUpNotes : notes.trim(),
        clearFollowUp: true,
        doNotContact: structured || updateOnly ? blocked : current.doNotContact,
        updatedDate: DateTime.parse(now),
        stageChangedAt: stage != current.stage ? DateTime.parse(now) : current.stageChangedAt,
      );
    });
  }

  Future<Client> createReferredLead({
    required Client source,
    required AppUser actor,
    required String name,
    required String phone,
  }) async {
    if (!actor.canAccessPanel('leads') && !actor.canAccessPanel('clients')) {
      throw StateError('Customer record edit access is required.');
    }
    if (name.trim().isEmpty || phone.replaceAll(RegExp(r'\D'), '').length < 7) {
      throw ArgumentError('Enter the new lead name and a usable phone number.');
    }
    final sourceRef = _firestore.collection('clients').doc(source.id);
    final leadRef = _firestore.collection('clients').doc();
    final sourceLog = sourceRef.collection('salesActivity').doc();
    final leadLog = leadRef.collection('salesActivity').doc();
    final now = DateTime.now();
    final lead = Client(
      id: leadRef.id, name: name.trim(), category: source.category,
      contactEmail: '', contactPhone: phone.trim(), stage: ClientStage.click,
      createdDate: now, referredByClientId: source.id, salesProgress: 'Not contacted',
      salesRecord: {
        'title': 'Call referred lead', 'action': 'Call', 'status': 'assigned',
        'assignedTo': actor.uid, 'assignedToName': actor.name,
        'revision': leadLog.id, 'updatedAt': now.toUtc().toIso8601String(),
        'dueAt': null,
      },
    );
    await _runTransaction((transaction) async {
      final snapshot = await transaction.get(sourceRef);
      if (!snapshot.exists) throw PlanSaveConflict('The referring customer no longer exists.');
      final current = Client.fromFirestore(snapshot);
      if (current.isArchived || !{ClientStage.retain, ClientStage.refer}.contains(current.stage)) {
        throw StateError('Referrals can be created from an active Retain or Refer customer.');
      }
      transaction.set(leadRef, lead.toFirestore());
      final authorship = {
        'at': now.toUtc().toIso8601String(),
        'recordedBy': actor.uid,
        'recordedByName': actor.name.isEmpty ? actor.email : actor.name,
      };
      transaction.set(sourceLog, {
        ...authorship, 'id': sourceLog.id, 'event': 'Referral received',
        'title': lead.name, 'referredLeadId': lead.id, 'stage': current.stage.name,
      });
      transaction.set(leadLog, {
        ...authorship, 'id': leadLog.id, 'event': 'Referred lead created',
        'title': 'Call referred lead', 'referredByClientId': source.id,
        'stage': ClientStage.click.name, 'progress': 'Not contacted',
      });
    });
    return lead;
  }

  Future<void> saveSalesRecord({
    required Client client,
    required Plan? plan,
    required String? feature,
    required bool addTask,
    required String notes,
    required DateTime? dueAt,
    required ClientStage stage,
    required List<Map<String, dynamic>> contacts,
    required bool editCustomer,
    required bool editTask,
    AppUser? actor,
    String? nextFeature,
  }) async {
    if (plan != null &&
        (plan.clientId != client.id ||
            feature == null ||
            !isSalesTaskFeature(feature))) {
      throw ArgumentError(
        'Sales records must reference this customer and a Sales task.',
      );
    }
    if (nextFeature != null &&
        (!editTask ||
            actor?.canAccessPanel('tasks') != true ||
            plan == null ||
            nextFeature == feature ||
            !isSalesTaskFeature(nextFeature) ||
            !plan.features.contains(nextFeature) ||
            taskDueAt(plan, nextFeature) == null)) {
      throw ArgumentError('A next follow-up requires task management access and a scheduled Sales task.');
    }
    final clientRef = _firestore.collection('clients').doc(client.id);
    final planRef = plan == null
        ? null
        : _firestore.collection('plans').doc(plan.id);
    await _firestore.runTransaction((transaction) async {
      final customer = await transaction.get(clientRef);
      final storedPlan = planRef == null
          ? null
          : await transaction.get(planRef);
      if (!customer.exists) {
        throw PlanSaveConflict('This customer no longer exists.');
      }
      final data = customer.data()!;
      if (editCustomer &&
          (plan == null || editTask) &&
          (data['notes'] != client.notes ||
              data['followUpNotes'] != client.followUpNotes ||
              (data['followUpAt'] as Timestamp?)?.toDate() !=
                  client.followUpAt)) {
        throw PlanSaveConflict(
          'Customer notes or reminder changed. Reopen the sales record.',
        );
      }
      if (editTask && plan != null && feature != null && planRef != null) {
        Plan target;
        if (storedPlan!.exists) {
          target = Plan.fromFirestore(storedPlan);
          if (addTask) {
            if (target.features.contains(feature)) {
              throw PlanSaveConflict(
                'A sales task with this title already exists.',
              );
            }
            target = target.copyWith(
              features: [...target.features, feature],
              tasks: [
                ...target.tasks,
                plan.tasks.firstWhere((task) => task.feature == feature),
              ],
              taskWorkflow: {
                ...target.taskWorkflow,
                feature: {...?plan.taskWorkflow[feature]},
              },
            );
          } else {
            if (!target.features.contains(feature) ||
                taskInternalNotes(target, feature) !=
                    taskInternalNotes(plan, feature) ||
                taskDueAt(target, feature) != taskDueAt(plan, feature)) {
              throw PlanSaveConflict(
                'Sales task notes or reminder changed. Reopen the sales record.',
              );
            }
          }
        } else {
          if (!addTask) {
            throw PlanSaveConflict('This sales task no longer exists.');
          }
          target = plan;
        }
        if (nextFeature != null && storedPlan.exists) {
          if (target.features.contains(nextFeature)) {
            throw PlanSaveConflict('A sales task with this title already exists.');
          }
          target = target.copyWith(
            features: [...target.features, nextFeature],
            tasks: [
              ...target.tasks,
              plan.tasks.firstWhere((task) => task.feature == nextFeature),
            ],
            taskWorkflow: {
              ...target.taskWorkflow,
              nextFeature: {...?plan.taskWorkflow[nextFeature]},
            },
          );
        }
        final updated = updateSalesRecordTask(
          target,
          feature,
          notes,
          dueAt,
          actor: actor,
        );
        if (!storedPlan.exists) {
          transaction.set(planRef, updated.toFirestore());
        } else if (addTask || nextFeature != null) {
          transaction.update(planRef, {
            'features': updated.features,
            'tasks': updated.tasks.map((task) => task.toFirestore()).toList(),
            'taskWorkflow': updated.taskWorkflow,
          });
        } else {
          transaction.update(planRef, {'taskWorkflow': updated.taskWorkflow});
        }
      }
      if (editCustomer) {
        final currentContacts =
            (data['salesContacts'] as List<dynamic>? ?? const [])
                .map((contact) => Map<String, dynamic>.from(contact as Map))
                .toList();
        transaction.update(clientRef, {
          'salesContacts': mergeSalesRecordContacts(
            currentContacts,
            client.salesContacts,
            contacts,
          ),
          if (plan == null) 'notes': notes.trim(),
          if (plan == null || editTask)
            'followUpAt': plan == null && dueAt != null
                ? Timestamp.fromDate(dueAt)
                : null,
          if (plan == null || editTask) 'followUpNotes': null,
          'updatedDate': FieldValue.serverTimestamp(),
          if (stage != client.stage)
            'stage': ClientStage.fromStoredName(stage.name).name,
          if (stage != client.stage)
            'stageChangedAt': FieldValue.serverTimestamp(),
        });
      }
    });
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

  // Plans
  Future<void> createPlan(Plan plan, {bool ifAbsent = false}) async {
    try {
      final document = _firestore.collection('plans').doc(plan.id);
      if (!ifAbsent) {
        await document.set(plan.toFirestore());
      } else {
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(document);
          if (snapshot.exists) {
            if (!samePlanData(
              Plan.fromFirestore(snapshot).toFirestore(),
              plan.toFirestore(),
            )) {
              throw PlanSaveConflict(
                'This plan already exists or changed. Reopen it before saving.',
              );
            }
          } else {
            transaction.set(document, plan.toFirestore());
          }
        });
      }
    } catch (e) {
      print('Error creating plan: $e');
      rethrow;
    }
  }

  Stream<List<Plan>> getAllPlansStream() {
    return _firestore
        .collection('plans')
        .orderBy('startDate', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PlanSnapshotList(
            snapshot.docs.map(Plan.fromFirestore),
            serverConfirmed:
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites,
          ),
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
    return PlanSnapshotList(
      snapshot.docs.map(Plan.fromFirestore),
      serverConfirmed:
          !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites,
    );
  }

  Stream<List<Plan>> getPlansStream(String clientId) {
    return _firestore
        .collection('plans')
        .where('clientId', isEqualTo: clientId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PlanSnapshotList(
            snapshot.docs.map(Plan.fromFirestore),
            serverConfirmed:
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites,
          ),
        );
  }

  Future<Plan?> getPlanOnce(String planId) async {
    final snapshot = await _firestore
        .collection('plans')
        .doc(planId)
        .get(const GetOptions(source: Source.server));
    return snapshot.exists ? Plan.fromFirestore(snapshot) : null;
  }

  Future<void> updatePlan(Plan plan, {Plan? previous}) async {
    try {
      final document = _firestore.collection('plans').doc(plan.id);
      if (previous == null) {
        await document.update(plan.toFirestore());
      } else {
        if (previous.id != plan.id) {
          throw ArgumentError('The previous plan must have the same ID.');
        }
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(document);
          if (!snapshot.exists) {
            throw PlanSaveConflict(
              'This plan no longer exists. Refresh the task list.',
            );
          }
          final current = Plan.fromFirestore(snapshot).toFirestore();
          final desired = plan.toFirestore();
          final before = previous.toFirestore();
          final merged = mergePlanChanges(current, before, desired);
          final changes = <String, dynamic>{
            for (final key in desired.keys)
              if (!samePlanData(before[key], desired[key])) key: merged[key],
          };
          if (changes.isNotEmpty) transaction.update(document, changes);
        });
      }
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

  Future<void> relinkUnlinkedPlan(
    String planId, {
    required String previousClientId,
    required String clientId,
    required int expectedTaskCount,
  }) async {
    if (clientId.isEmpty || clientId == previousClientId) {
      throw ArgumentError('Select a different client or Practice (Internal).');
    }
    final document = _firestore.collection('plans').doc(planId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      if (!snapshot.exists) {
        throw PlanSaveConflict('This plan no longer exists.');
      }
      final plan = Plan.fromFirestore(snapshot);
      if (plan.clientId != previousClientId ||
          plan.features.toSet().length != expectedTaskCount) {
        throw PlanSaveConflict(
          'The plan changed. Refresh and review before linking.',
        );
      }
      if (previousClientId == '__internal_practice__') {
        throw PlanSaveConflict('This plan is already linked to internal work.');
      }
      if (previousClientId.isNotEmpty) {
        final original = await transaction.get(
          _firestore.collection('clients').doc(previousClientId),
        );
        if (original.exists) {
          throw PlanSaveConflict(
            'The original client exists. Refresh the task list.',
          );
        }
      }
      if (clientId != '__internal_practice__') {
        final target = await transaction.get(
          _firestore.collection('clients').doc(clientId),
        );
        if (!target.exists) {
          throw PlanSaveConflict('The selected client no longer exists.');
        }
      }
      transaction.update(document, {'clientId': clientId});
    });
  }

  Future<void> deletePlanTask(
    String planId,
    String feature,
    String confirmation,
  ) async {
    if (confirmation != 'DELETE') {
      throw ArgumentError('Type DELETE to confirm task deletion.');
    }
    final document = _firestore.collection('plans').doc(planId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      if (!snapshot.exists) {
        throw StateError('Plan no longer exists. Refresh the task list.');
      }
      final updated = removePlanTask(Plan.fromFirestore(snapshot), feature);
      transaction.update(document, {
        'features': updated.features,
        'tasks': updated.tasks.map((task) => task.toFirestore()).toList(),
        'completedFeatures': updated.completedFeatures,
        'featureProgress': updated.featureProgress,
        'taskWorkflow': updated.taskWorkflow,
      });
    });
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
