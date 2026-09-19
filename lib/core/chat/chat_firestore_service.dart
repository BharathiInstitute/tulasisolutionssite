import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';

/// Firestore service specifically for chat functionality.
class ChatFirestoreService {
  final FirebaseFirestore _firestore;
  final String clientId;

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

  /// Watch all conversations for the current client
  Stream<List<Conversation>> watchConversations() {
    return _firestore
        .collection(_conversationsPath)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Conversation.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<Conversation>> watchAllConversations() {
    return _firestore
        .collectionGroup('conversations')
        .snapshots()
        .map((snap) {
          final conversations = snap.docs.map((doc) {
            final ownerClientId = doc.reference.parent.parent?.id ?? '';
            return Conversation.fromMap(
              {...doc.data(), 'clientId': ownerClientId},
              doc.id,
            );
          }).toList();
          // Only real message activity promotes a conversation; chats with no
          // messages stay below, ordered by creation date.
          conversations.sort((first, second) {
            final firstActivity = first.lastMessageAt;
            final secondActivity = second.lastMessageAt;
            if (firstActivity == null && secondActivity == null) {
              return second.createdAt.compareTo(first.createdAt);
            }
            if (firstActivity == null) return 1;
            if (secondActivity == null) return -1;
            return secondActivity.compareTo(firstActivity);
          });
          return conversations;
        });
  }

  /// Create a new conversation
  Future<String> createConversation(
    Conversation conversation, {
    String? ownerClientId,
  }) async {
    final conversationsPath = _conversationsPathFor(ownerClientId);
    final docRef = await _firestore.collection(conversationsPath).add({
      ...conversation.toMap(),
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
