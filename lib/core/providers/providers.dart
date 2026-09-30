import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../models/weekly_report.dart';
import '../chat/chat.dart';
import '../performance/performance_models.dart';

// Firebase service providers
final firebaseAuthServiceProvider = Provider((ref) => FirebaseAuthService());
final firestoreServiceProvider = Provider((ref) => FirestoreService());

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.authStateChanges();
});

// Current user admin status provider
final currentUserIsAdminProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(firebaseAuthServiceProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return await authService.isUserAdmin(user.uid);
});

final currentUserProfileProvider = FutureProvider<AppUser?>((ref) async {
  final authService = ref.watch(firebaseAuthServiceProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return authService.getUserProfile(user.uid);
});

final currentUserProfileStreamProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return authService.getUserProfileStream(user.uid);
});

// Use a server fetch because persistent Firestore streams are blocked on some
// operator networks. Chat invalidates this after imports and new conversations.
final clientsListProvider = FutureProvider<List<Client>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getClientsOnce();
});

// Single client provider
final clientProvider = StreamProvider.family<Client?, String>((
  ref,
  clientId,
) async* {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final client = await firestoreService.getClient(clientId);
  yield client;
});

final weeklyReportsProvider = StreamProvider.family<List<WeeklyReport>, String>(
  (ref, clientId) =>
      ref.watch(firestoreServiceProvider).getWeeklyReportsStream(clientId),
);

// Setup checklist items provider
final checklistItemsProvider =
    StreamProvider.family<List<SetupChecklistItem>, String>((ref, clientId) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.getChecklistItems(clientId);
    });

// Goals provider
final goalsProvider = StreamProvider.family<List<Goal>, String>((
  ref,
  clientId,
) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getGoalsStream(clientId);
});

// Consultations provider
final consultationsProvider = StreamProvider.family<List<Consultation>, String>(
  (ref, clientId) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getConsultationsStream(clientId);
  },
);

// All consultations across clients (admin overview)
final allConsultationsProvider = StreamProvider<List<Consultation>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getAllConsultationsStream();
});

// All users (admin user management)
final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(<AppUser>[]);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUsersStream();
});

// All plans across clients (admin overview)
final allPlansProvider = FutureProvider<List<Plan>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getAllPlansOnce();
});

final allPlansStreamProvider = StreamProvider<List<Plan>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(<Plan>[]);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getAllPlansStream();
});

final paymentsProvider = StreamProvider<List<PaymentRecord>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getPaymentsStream();
});

final performanceSubmissionsProvider = StreamProvider<List<VideoSubmission>>((
  ref,
) {
  return ref.watch(firestoreServiceProvider).getPerformanceSubmissionsStream();
});

final performanceHoursProvider = StreamProvider<List<DailyHours>>((ref) {
  return ref.watch(firestoreServiceProvider).getPerformanceHoursStream();
});

final performanceAttendanceProvider = StreamProvider<List<AttendanceRecord>>((
  ref,
) {
  return ref.watch(firestoreServiceProvider).getPerformanceAttendanceStream();
});

final currentStaffIdsProvider = Provider<List<String>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (user == null) return [];
  return {
    user.uid,
    if (user.email != null && user.email!.isNotEmpty) user.email!,
    if (profile != null) profile.uid,
  }.toList();
});

final myPerformanceSubmissionsProvider = StreamProvider<List<VideoSubmission>>((
  ref,
) {
  final staffIds = ref.watch(currentStaffIdsProvider);
  if (staffIds.isEmpty) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .getPerformanceSubmissionsStream(staffIds: staffIds);
});

final myPerformanceHoursProvider = StreamProvider<List<DailyHours>>((ref) {
  final staffIds = ref.watch(currentStaffIdsProvider);
  if (staffIds.isEmpty) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .getPerformanceHoursStream(staffIds: staffIds);
});

final myPerformanceAttendanceProvider = StreamProvider<List<AttendanceRecord>>((
  ref,
) {
  final staffIds = ref.watch(currentStaffIdsProvider);
  if (staffIds.isEmpty) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .getPerformanceAttendanceStream(staffIds: staffIds);
});

// Reusable pricing plan templates (admin managed)
final planTemplatesProvider = StreamProvider<List<PlanTemplate>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getPlanTemplatesStream();
});

// Plans for a single client
final plansProvider = StreamProvider.family<List<Plan>, String>((
  ref,
  clientId,
) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getPlansStream(clientId);
});

// Software Stage provider
final softwareStageProvider = StreamProvider.family<SoftwareStageData?, String>(
  (ref, clientId) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getSoftwareStageStream(clientId);
  },
);

// Content Logs provider
final contentLogsProvider = StreamProvider.family<List<ContentLog>, String>((
  ref,
  clientId,
) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getContentLogsStream(clientId);
});

// State notifier for selected client
final selectedClientProvider = StateProvider<String?>((ref) => null);

// ─── CHAT PROVIDERS ──────────────────────────────────────────

/// Provides the global ChatProvider used by the admin chat panel.
final chatProvider = ChangeNotifierProvider<ChatProvider>((ref) {
  final firestoreService = ChatFirestoreService(clientId: '');
  final cloudFunctions = CloudFunctionService();
  final msg91Service = MSG91Service(cloudFunctions: cloudFunctions);

  final provider = ChatProvider(
    firestoreService: firestoreService,
    msg91Service: msg91Service,
  );

  provider.loadConversations();

  return provider;
});

/// Admin chat provider - can be initialized with any client ID
final adminChatProvider = ChangeNotifierProvider.family<ChatProvider, String>((
  ref,
  clientId,
) {
  final firestoreService = ChatFirestoreService(clientId: clientId);
  final cloudFunctions = CloudFunctionService();
  final msg91Service = MSG91Service(cloudFunctions: cloudFunctions);

  final provider = ChatProvider(
    firestoreService: firestoreService,
    msg91Service: msg91Service,
  );

  if (clientId.isNotEmpty) {
    provider.loadConversations();
  }

  return provider;
});
