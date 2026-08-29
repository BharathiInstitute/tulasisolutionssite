import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../chat/chat.dart';

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
  final user = authService.getCurrentUser();
  if (user == null) return false;
  return await authService.isUserAdmin(user.uid);
});

// Clients list provider
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

final currentClientProvider = FutureProvider<Client?>((ref) async {
  final user = ref.watch(firebaseAuthServiceProvider).getCurrentUser();
  if (user?.email == null) return null;
  return ref
      .watch(firestoreServiceProvider)
      .getClientByEmail(user!.email!.trim().toLowerCase());
});

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
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUsersStream();
});

// All plans across clients (admin overview)
final allPlansProvider = FutureProvider<List<Plan>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getAllPlansOnce();
});

final allPlansStreamProvider = StreamProvider<List<Plan>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getAllPlansStream();
});

final paymentsProvider = StreamProvider<List<PaymentRecord>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getPaymentsStream();
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

/// Provides the ChatProvider instance tied to the current user's client
final chatProvider = ChangeNotifierProvider<ChatProvider>((ref) {
  final client = ref.watch(currentClientProvider).valueOrNull;
  final clientId = client?.id ?? '';

  final firestoreService = ChatFirestoreService(clientId: clientId);
  final cloudFunctions = CloudFunctionService();
  final msg91Service = MSG91Service(cloudFunctions: cloudFunctions);

  final provider = ChatProvider(
    firestoreService: firestoreService,
    msg91Service: msg91Service,
  );

  // Auto-load conversations if we have a valid client
  if (clientId.isNotEmpty) {
    provider.loadConversations();
  }

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
