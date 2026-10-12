import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../chat/chat.dart';
import '../performance/performance_models.dart';
import '../tasks/task_save_controller.dart';
import '../tasks/plan_changes.dart';
import '../tasks/pending_save_warning_stub.dart'
    if (dart.library.js_interop) '../tasks/pending_save_warning_web.dart';

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
  final cancelled = Completer<void>();
  Timer? retryTimer;
  ref.onDispose(() {
    retryTimer?.cancel();
    if (!cancelled.isCompleted) cancelled.complete();
  });
  Future<AppUser?> loadProfile() async {
    var retryDelay = const Duration(milliseconds: 500);
    for (var attempt = 0; attempt < 3 && !cancelled.isCompleted; attempt++) {
      try {
        return await authService.getUserProfile(user.uid);
      } catch (error) {
        if (cancelled.isCompleted) return null;
        if (!isRetryableProfileLoadError(error) || attempt == 2) rethrow;
        final retryReady = Completer<void>();
        retryTimer = Timer(retryDelay, retryReady.complete);
        await Future.any([retryReady.future, cancelled.future]);
        retryTimer = null;
        retryDelay *= 2;
      }
    }
    return null;
  }

  return loadProfile().timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      retryTimer?.cancel();
      if (!cancelled.isCompleted) cancelled.complete();
      throw TimeoutException(
        'Timed out checking staff access. Check your connection and retry.',
      );
    },
  );
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

final StateProvider<Map<String, Client>> confirmedSalesClientsProvider =
    StateProvider<Map<String, Client>>((ref) {
      ref.watch(authStateProvider.select((state) => state.valueOrNull?.uid));
      ref.listen(clientsListProvider, (_, next) {
        if (next.isLoading || next.hasError) return;
        final clients = next.valueOrNull;
        if (clients == null) return;
        final controller = ref.read(confirmedSalesClientsProvider.notifier);
        if (controller.state.isEmpty) return;
        if (clients is ClientSnapshotList && clients.serverConfirmed) {
          controller.state = {};
        } else {
          final revisions = {
            for (final client in clients)
              client.id: client.salesRecord['revision'],
          };
          final remaining = {
            for (final entry in controller.state.entries)
              if (revisions[entry.key] != entry.value.salesRecord['revision'])
                entry.key: entry.value,
          };
          if (remaining.length != controller.state.length) {
            controller.state = remaining;
          }
        }
      });
      return {};
    });

AsyncValue<List<Client>> _withConfirmedSalesClients(
  AsyncValue<List<Client>> source,
  Map<String, Client> confirmed,
) {
  if (source.hasError || !source.hasValue) return source;
  final clients = source.requireValue;
  final ids = clients.map((client) => client.id).toSet();
  final visible = AsyncData<List<Client>>([
    for (final client in clients) confirmed[client.id] ?? client,
    for (final client in confirmed.values)
      if (!ids.contains(client.id)) client,
  ]);
  return source.isLoading
      ? const AsyncLoading<List<Client>>().copyWithPrevious(
          visible,
          isRefresh: source.isRefreshing,
        )
      : visible;
}

final visibleClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final source = ref.watch(clientsListProvider);
  final confirmed = ref.watch(confirmedSalesClientsProvider);
  return _withConfirmedSalesClients(source, confirmed);
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

final pendingSaveWarningProvider = Provider<void Function() Function()>(
  (ref) => registerPendingSaveWarning,
);

final taskSavesProvider =
    StateNotifierProvider<TaskSaveController, Map<String, TaskSave>>((ref) {
      ref.watch(authStateProvider.select((state) => state.valueOrNull?.uid));
      final controller = TaskSaveController(
        onConfirmed: (save) {
          ref.invalidate(allPlansProvider);
          if (save.refreshClientId != null) {
            ref.invalidate(clientsListProvider);
            ref.invalidate(clientProvider(save.refreshClientId!));
          }
        },
      );
      void Function()? removeWarning;
      controller.addListener((saves) {
        final unsaved = saves.values.any(
          (save) => save.phase != TaskSavePhase.confirmed,
        );
        if (unsaved && removeWarning == null) {
          removeWarning = ref.read(pendingSaveWarningProvider)();
        } else if (!unsaved && removeWarning != null) {
          removeWarning!();
          removeWarning = null;
        }
      }, fireImmediately: false);
      ref.onDispose(() => removeWarning?.call());
      return controller;
    });

final visiblePlansProvider = Provider<AsyncValue<List<Plan>>>((ref) {
  final source = ref.watch(allPlansStreamProvider);
  ref.watch(taskSavesProvider);
  ref.listen(allPlansStreamProvider, (previous, next) {
    final plans = next.valueOrNull;
    if (!next.isLoading && !next.hasError && plans != null) {
      ref.read(taskSavesProvider.notifier).reconcile(plans);
    }
  });
  final controller = ref.read(taskSavesProvider.notifier);
  return source.whenData(controller.visiblePlans);
});

final taskClientsProvider = FutureProvider<List<Client>>((ref) async {
  ref.watch(
    visiblePlansProvider.select((state) {
      final ids =
          state.valueOrNull?.map((plan) => plan.clientId).toSet().toList() ??
          <String>[];
      ids.sort();
      return jsonEncode(ids);
    }),
  );
  final clientIds = {
    for (final plan in ref.read(visiblePlansProvider).valueOrNull ?? <Plan>[])
      if (plan.clientId.isNotEmpty && plan.clientId != '__internal_practice__')
        plan.clientId,
  };
  final clients = await ref.watch(clientsListProvider.future);
  final byId = {for (final client in clients) client.id: client};
  final missingIds = clientIds.where((id) => !byId.containsKey(id)).toList();
  if (missingIds.isEmpty) return clients;
  final service = ref.read(firestoreServiceProvider);
  final resolved = await Future.wait(
    missingIds.map(
      (id) => service
          .getClient(id, serverOnly: true)
          .timeout(const Duration(seconds: 20)),
    ),
  );
  return [
    ...clients,
    for (final client in resolved)
      if (client != null) client,
  ];
});

final visibleTaskClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final source = ref.watch(taskClientsProvider);
  final latest =
      ref.watch(visibleClientsProvider).valueOrNull ?? const <Client>[];
  final confirmed = ref.watch(confirmedSalesClientsProvider);
  return _withConfirmedSalesClients(source, {
    for (final client in latest) client.id: client,
    ...confirmed,
  });
});

final visiblePlansOnceProvider = Provider<AsyncValue<List<Plan>>>((ref) {
  final source = ref.watch(allPlansProvider);
  ref.watch(taskSavesProvider);
  ref.listen(allPlansProvider, (previous, next) {
    final plans = next.valueOrNull;
    if (!next.isLoading && !next.hasError && plans != null) {
      ref.read(taskSavesProvider.notifier).reconcile(plans);
    }
  });
  return source.whenData(ref.read(taskSavesProvider.notifier).visiblePlans);
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

final visibleClientPlansProvider =
    Provider.family<AsyncValue<List<Plan>>, String>((ref, clientId) {
      final source = ref.watch(plansProvider(clientId));
      ref.watch(taskSavesProvider);
      ref.listen(plansProvider(clientId), (previous, next) {
        final plans = next.valueOrNull;
        if (!next.isLoading && !next.hasError && plans != null) {
          ref
              .read(taskSavesProvider.notifier)
              .reconcile(plans, clientId: clientId);
        }
      });
      return source.whenData(
        (plans) => ref
            .read(taskSavesProvider.notifier)
            .visiblePlans(plans)
            .where((plan) => plan.clientId == clientId)
            .toList(),
      );
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
