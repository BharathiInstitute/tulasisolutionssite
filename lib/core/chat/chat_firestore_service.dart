import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';

/// Firestore service specifically for chat functionality.
class ChatFirestoreService {
  final FirebaseFirestore _firestore;
  final String clientId;
  DocumentSnapshot<Map<String, dynamic>>? _lastConversationDocument;
  int _paginationGeneration = 0;

  ChatFirestoreService({required this.clientId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  bool get isConfigured => clientId.isNotEmpty;
  String get currentClientId => clientId;

  String get _conversationsPath => 'clients/$clientId/conversations';

  String _conversationsPathFor(String? ownerClientId) {
    final resolvedClientId = ownerClientId?.trim().isNotEmpty == true
        ? ownerClientId!
        : clientId;
    if (resolvedClientId.isEmpty) {
      throw StateError('A client is required for this conversation.');
    }
    return 'clients/$resolvedClientId/conversations';
  }

  // ─── CONVERSATIONS ───────────────────────────────────────────

  void resetConversationPagination() {
    _lastConversationDocument = null;
    _paginationGeneration++;
  }

  Query<Map<String, dynamic>> _filteredConversationsQuery({
    String? stage,
    required bool isArchived,
  }) {
    Query<Map<String, dynamic>> query = isConfigured
        ? _firestore.collection(_conversationsPath)
        : _firestore.collectionGroup('conversations');
    query = query
        .where('channel', isEqualTo: ConversationChannel.whatsapp.name)
        .where('isArchived', isEqualTo: isArchived);
    if (stage != null) {
      query = query.where('stage', isEqualTo: stage);
    }
    return query;
  }

  Stream<List<Conversation>> watchAllConversations({String? stage}) {
    Query<Map<String, dynamic>> query = isConfigured
        ? _firestore.collection(_conversationsPath)
        : _firestore.collectionGroup('conversations');
    if (stage != null) {
      query = query.where('stage', isEqualTo: stage);
    }
    return query.snapshots().map((snapshot) {
      final conversations = snapshot.docs
          .map((doc) {
            final ownerClientId = isConfigured
                ? clientId
                : doc.reference.parent.parent?.id ?? '';
            return Conversation.fromMap({
              ...doc.data(),
              'clientId': ownerClientId,
            }, doc.id);
          })
          .where(
            (conversation) =>
                conversation.channel == ConversationChannel.whatsapp,
          )
          .toList();
      conversations.sort((left, right) {
        final leftTime = left.lastMessageAt ?? left.createdAt;
        final rightTime = right.lastMessageAt ?? right.createdAt;
        return rightTime.compareTo(leftTime);
      });
      return conversations;
    });
  }

  Future<int> countConversations({
    String? stage,
    required bool isArchived,
  }) async {
    final snapshot = await _filteredConversationsQuery(
      stage: stage,
      isArchived: isArchived,
    ).count().get().timeout(const Duration(seconds: 10));
    return snapshot.count ?? 0;
  }

  Future<Map<String, int>> countActiveConversationsByStage(
    Iterable<String> stages,
  ) async {
    final stageList = stages.toList();
    final counts = await Future.wait(
      stageList.map(
        (stage) => countConversations(stage: stage, isArchived: false),
      ),
    );
    return {
      for (var index = 0; index < stageList.length; index++)
        stageList[index]: counts[index],
    };
  }

  Future<ConversationPage> loadNextConversationPage({
    String? stage,
    bool isArchived = false,
    int pageSize = 25,
  }) async {
    final paginationGeneration = _paginationGeneration;
    var query = _filteredConversationsQuery(
      stage: stage,
      isArchived: isArchived,
    );
    query = query.orderBy('lastMessageAt', descending: true).limit(pageSize);
    if (_lastConversationDocument != null) {
      query = query.startAfterDocument(_lastConversationDocument!);
    }

    final snapshot = await query
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () =>
              throw TimeoutException('Conversation page request timed out.'),
        );
    if (snapshot.docs.isNotEmpty &&
        paginationGeneration == _paginationGeneration) {
      _lastConversationDocument = snapshot.docs.last;
    }
    final conversations = snapshot.docs.map((doc) {
      final ownerClientId = isConfigured
          ? clientId
          : doc.reference.parent.parent?.id ?? '';
      return Conversation.fromMap({
        ...doc.data(),
        'clientId': ownerClientId,
      }, doc.id);
    }).toList();
    return ConversationPage(
      conversations: conversations,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  Future<List<Conversation>> loadArchivedConversations({
    String? stage,
    int limit = 25,
  }) async {
    final snapshot =
        await _filteredConversationsQuery(stage: stage, isArchived: true)
            .orderBy('lastMessageAt', descending: true)
            .limit(limit)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 20));
    return snapshot.docs.map((doc) {
      final ownerClientId = isConfigured
          ? clientId
          : doc.reference.parent.parent?.id ?? '';
      return Conversation.fromMap({
        ...doc.data(),
        'clientId': ownerClientId,
      }, doc.id);
    }).toList();
  }

  Future<void> updateClientConversationFilters({
    required String ownerClientId,
    required String stage,
  }) async {
    final conversations = await _firestore
        .collection(_conversationsPathFor(ownerClientId))
        .get();
    if (conversations.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final conversation in conversations.docs) {
      batch.update(conversation.reference, {'stage': stage});
    }
    await batch.commit();
  }

  Future<void> updateClientConversationArchive({
    required String ownerClientId,
    required String conversationId,
    required bool isArchived,
  }) async {
    final conversationRef = _firestore
        .collection(_conversationsPathFor(ownerClientId))
        .doc(conversationId);
    await conversationRef
        .update({
          'isArchived': isArchived,
          'archiveUpdatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Archive update timed out. Please try again.',
          ),
        );
    final persisted = await conversationRef
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Archive verification timed out. Please try again.',
          ),
        );
    if (!persisted.exists ||
        (persisted.data()?['isArchived'] == true) != isArchived) {
      throw StateError(
        'Firestore did not save the archive change for '
        '$ownerClientId/$conversationId.',
      );
    }
  }

  Future<void> updateConversationsArchive({
    required List<Conversation> conversations,
    required bool isArchived,
  }) async {
    if (conversations.isEmpty) return;
    final references = conversations.map((conversation) {
      if (conversation.clientId.isEmpty) {
        throw StateError(
          '${conversation.contactName} is not linked to a lead.',
        );
      }
      return _firestore
          .collection(_conversationsPathFor(conversation.clientId))
          .doc(conversation.id);
    }).toList();
    final batch = _firestore.batch();
    for (final reference in references) {
      batch.update(reference, {
        'isArchived': isArchived,
        'archiveUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit().timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          throw TimeoutException('Archive batch timed out. Please try again.'),
    );
    final persisted =
        await Future.wait(
          references.map(
            (reference) =>
                reference.get(const GetOptions(source: Source.server)),
          ),
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            'Archive verification timed out. Please try again.',
          ),
        );
    if (persisted.any(
      (snapshot) =>
          !snapshot.exists ||
          (snapshot.data()?['isArchived'] == true) != isArchived,
    )) {
      throw StateError('Firestore did not save every archive change.');
    }
  }

  /// Create a new conversation
  Future<String> createConversation(
    Conversation conversation, {
    String? ownerClientId,
  }) async {
    final resolvedClientId = ownerClientId?.trim().isNotEmpty == true
        ? ownerClientId!
        : clientId;
    final conversationsPath = _conversationsPathFor(resolvedClientId);
    final client = await _firestore
        .collection('clients')
        .doc(resolvedClientId)
        .get();
    final docRef = await _firestore.collection(conversationsPath).add({
      ...conversation.toMap(),
      'stage': client.data()?['stage'] ?? 'reach',
      'isArchived': client.data()?['isArchived'] == true,
      'createdAt': FieldValue.serverTimestamp(),
      // Left null so an empty chat does not sort above real conversations.
      'lastMessageAt': null,
    });
    return docRef.id;
  }

  // ─── MESSAGES ────────────────────────────────────────────────

  /// Watch messages in a specific conversation
  Stream<List<Message>> watchMessages(
    String conversationId, {
    String? ownerClientId,
  }) {
    return _firestore
        .collection(
          '${_conversationsPathFor(ownerClientId)}/$conversationId/messages',
        )
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
          final messages = snap.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .toList();
          messages.sort((a, b) {
            final aTime = a.eventAt ?? a.createdAt;
            final bTime = b.eventAt ?? b.createdAt;
            final comparison = aTime.compareTo(bTime);
            return comparison != 0 ? comparison : a.id.compareTo(b.id);
          });
          return messages;
        });
  }

  /// Send a message (creates the message document)
  Future<String> sendMessage(
    String conversationId,
    Message message, {
    String? ownerClientId,
  }) async {
    final conversationsPath = _conversationsPathFor(ownerClientId);
    final docRef = await _firestore
        .collection('$conversationsPath/$conversationId/messages')
        .add({...message.toMap(), 'createdAt': FieldValue.serverTimestamp()});

    // Update conversation's last message
    await _firestore.collection(conversationsPath).doc(conversationId).update({
      'lastMessage': message.content,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageDirection': message.direction.name,
    });

    return docRef.id;
  }

  // ─── CONTACTS ────────────────────────────────────────────────

  /// Watch contacts for the current client
  Stream<List<Map<String, dynamic>>> watchContacts() {
    return _firestore
        .collection('clients/$clientId/contacts')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
        );
  }

  /// Get a single contact by ID
  Future<Map<String, dynamic>?> getContact(
    String contactId, {
    String? ownerClientId,
  }) async {
    final resolvedClientId = ownerClientId?.trim().isNotEmpty == true
        ? ownerClientId!
        : clientId;
    if (resolvedClientId.isEmpty) return null;
    final doc = await _firestore
        .collection('clients/$resolvedClientId/contacts')
        .doc(contactId)
        .get();
    if (!doc.exists) return null;
    return {...doc.data()!, 'id': doc.id};
  }
}

class ConversationPage {
  final List<Conversation> conversations;
  final bool hasMore;

  const ConversationPage({required this.conversations, required this.hasMore});
}
