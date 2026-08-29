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

  /// Create a new conversation
  Future<String> createConversation(Conversation conversation) async {
    final docRef = await _firestore.collection(_conversationsPath).add({
      ...conversation.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ─── MESSAGES ────────────────────────────────────────────────

  /// Watch messages in a specific conversation
  Stream<List<Message>> watchMessages(String conversationId) {
    return _firestore
        .collection('$_conversationsPath/$conversationId/messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Send a message (creates the message document)
  Future<String> sendMessage(String conversationId, Message message) async {
    final docRef = await _firestore
        .collection('$_conversationsPath/$conversationId/messages')
        .add({...message.toMap(), 'createdAt': FieldValue.serverTimestamp()});

    // Update conversation's last message
    await _firestore.collection(_conversationsPath).doc(conversationId).update({
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
  Future<Map<String, dynamic>?> getContact(String contactId) async {
    final doc = await _firestore
        .collection('clients/$clientId/contacts')
        .doc(contactId)
        .get();
    if (!doc.exists) return null;
    return {...doc.data()!, 'id': doc.id};
  }
}
