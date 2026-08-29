import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';
import '../models/models.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with email and password
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required bool isAdmin,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user != null) {
        // Store user data in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'isAdmin': isAdmin,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.message}');
      rethrow;
    }
  }

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

  Future<void> updateAccountDetails({
    required String name,
    String? email,
    String? newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    try {
      final normalizedEmail = email?.trim();
      if (normalizedEmail != null &&
          normalizedEmail.isNotEmpty &&
          normalizedEmail != user.email) {
        await user.updateEmail(normalizedEmail);
      }
      if (newPassword != null && newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
      }
      await user.updateDisplayName(name.trim());
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      print('Account update error: ${e.message}');
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
    required String role,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedName = name.trim();
    final normalizedRole = role.trim();

    if (normalizedEmail.isEmpty || normalizedName.isEmpty) {
      throw StateError('Name and email are required');
    }

    final docId = normalizedEmail.toLowerCase();

    await _firestore.collection('users').doc(docId).set({
      'uid': docId,
      'email': normalizedEmail,
      'name': normalizedName,
      'isAdmin': false,
      'role': normalizedRole,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<Client?> getClientByEmail(String email) async {
    final snapshot = await _firestore
        .collection('clients')
        .where('contactEmail', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Client.fromFirestore(snapshot.docs.first);
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
    final snapshot = await _firestore
        .collection('clients')
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Timed out reaching Firestore. Check your internet connection.',
          ),
        );
    final clients = snapshot.docs
        .map((doc) => Client.fromFirestore(doc))
        .toList();
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
    final snapshot = await _firestore
        .collection('plans')
        .orderBy('startDate', descending: true)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Timed out reaching Firestore. Check your internet connection.',
          ),
        );
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
