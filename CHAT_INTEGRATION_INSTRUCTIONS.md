# Chat Panel Integration - Instructions

> **Files have been copied!** Follow these steps to complete the integration.

---

## ✅ What's Already Done

The chat panel files have been copied to your project:

```
lib/
├── core/
│   └── chat/
│       ├── chat.dart                    # Barrel export file
│       ├── chat_firestore_service.dart  # Firestore operations
│       ├── chat_provider.dart           # State management
│       ├── cloud_function_service.dart  # Cloud Function calls
│       ├── message_model.dart           # Data models
│       ├── msg91_service.dart           # MSG91 API wrapper
│       └── rate_limiter.dart            # Rate limiting utility
└── features/
    └── chat/
        ├── chat_screen.dart             # Individual chat view
        └── conversations_screen.dart    # Conversations list
```

---

## 📋 Step 1: Add Dependencies to pubspec.yaml

Open `pubspec.yaml` and add these dependencies:

```yaml
dependencies:
  # Existing dependencies...
  
  # Add these for chat:
  provider: ^6.1.2              # State management for chat
  http: ^1.2.0                  # For cloud function calls
  firebase_storage: ^12.1.0     # For media uploads (optional)
```

Then run:
```powershell
flutter pub get
```

---

## 📋 Step 2: Update cloud_function_service.dart

Open `lib/core/chat/cloud_function_service.dart` and update the project ID:

```dart
// Change this line (around line 9):
static const _projectId = 'tulasi-solutions'; // <-- YOUR ACTUAL PROJECT ID

// Find your project ID in Firebase Console or .firebaserc file
```

---

## 📋 Step 3: Add Chat Routes to router.dart

Open `lib/router.dart` and add these imports and routes:

```dart
// Add imports at top:
import 'features/chat/conversations_screen.dart';
import 'features/chat/chat_screen.dart';
import 'core/chat/chat.dart';

// Add these routes inside your routes list:
GoRoute(
  path: '/chat',
  builder: (context, state) => const ConversationsScreen(),
),
GoRoute(
  path: '/chat/:id',
  builder: (context, state) {
    final conversation = state.extra as Conversation;
    return ChatScreen(conversation: conversation);
  },
),
```

---

## 📋 Step 4: Setup Chat Provider

Since your project uses **Riverpod**, you have two options:

### Option A: Add Provider package (Recommended - Fastest)

Wrap your app with both Riverpod and Provider:

Open `lib/main.dart`:

```dart
import 'package:provider/provider.dart' as provider;
import 'core/chat/chat.dart';

// In main():
runApp(
  const ProviderScope(
    child: ChatProviderWrapper(
      child: MyApp(),
    ),
  ),
);

// Add this widget class:
class ChatProviderWrapper extends StatelessWidget {
  final Widget child;
  const ChatProviderWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // TODO: Get clientId from your auth system
    const clientId = 'your-client-id'; // Replace with actual client ID
    
    return provider.ChangeNotifierProvider(
      create: (_) => ChatProvider(
        firestoreService: ChatFirestoreService(clientId: clientId),
        msg91Service: MSG91Service(
          cloudFunctions: CloudFunctionService(),
        ),
      )..loadConversations(),
      child: child,
    );
  }
}
```

### Option B: Convert to Riverpod (Advanced)

If you prefer Riverpod everywhere, you'll need to convert `ChatProvider` to use Riverpod's `ChangeNotifierProvider`.

---

## 📋 Step 5: Setup Cloud Functions

### 5.1 Initialize Functions (if not already done)

```powershell
cd D:\tulasisolutionssite
firebase init functions
# Select: TypeScript
# Install dependencies: Yes
```

### 5.2 Copy Function Files from TulasiConnect

```powershell
# Copy webhook and messaging functions
Copy-Item "C:\Users\bhara\tulasiconnect\functions\src\msg91\*" "D:\tulasisolutionssite\functions\src\msg91\" -Recurse
Copy-Item "C:\Users\bhara\tulasiconnect\functions\src\message-queue.ts" "D:\tulasisolutionssite\functions\src\"
Copy-Item "C:\Users\bhara\tulasiconnect\functions\src\mark-read.ts" "D:\tulasisolutionssite\functions\src\"
Copy-Item "C:\Users\bhara\tulasiconnect\functions\src\config.ts" "D:\tulasisolutionssite\functions\src\"
Copy-Item "C:\Users\bhara\tulasiconnect\functions\src\utils.ts" "D:\tulasisolutionssite\functions\src\"
```

### 5.3 Update functions/src/index.ts

```typescript
// Export chat functions
export { msg91Webhook } from "./msg91/msg91-webhook";
export { processMessageQueue, enqueueMessage, onMessageQueued } from "./message-queue";
export { markConversationRead } from "./mark-read";
```

### 5.4 Set MSG91 Secrets

```powershell
cd D:\tulasisolutionssite\functions

# Set your MSG91 auth key
firebase functions:secrets:set MSG91_AUTH_KEY
# Enter your key when prompted

# Set your WhatsApp number
firebase functions:secrets:set MSG91_WHATSAPP_NUMBER
# Enter: +91XXXXXXXXXX
```

### 5.5 Deploy Functions

```powershell
cd D:\tulasisolutionssite
firebase deploy --only functions
```

---

## 📋 Step 6: Setup Firestore Rules

Add these rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing rules ...
    
    // Chat conversations
    match /clients/{clientId}/conversations/{convId} {
      allow read, write: if request.auth != null;
      
      match /messages/{msgId} {
        allow read, write: if request.auth != null;
      }
    }
    
    // Contacts
    match /clients/{clientId}/contacts/{contactId} {
      allow read, write: if request.auth != null;
    }
    
    // Message queue
    match /clients/{clientId}/messageQueue/{queueId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Deploy rules:
```powershell
firebase deploy --only firestore:rules
```

---

## 📋 Step 7: Configure MSG91 Webhook

After deploying functions, configure MSG91:

1. **Get your webhook URL:**
   ```
  https://asia-south1-newproject1234561.cloudfunctions.net/msg91Webhook
   ```

2. **Login to MSG91:** https://control.msg91.com

3. **Go to:** WhatsApp → Settings → Webhooks

4. **Add webhook URL** and enable:
   - Message received
   - Message status updates
   - Read receipts

---

## 📋 Step 8: Create Initial Data

In Firebase Console (Firestore), create:

1. **Collection:** `clients`
2. **Document ID:** `your-client-id`
3. **Fields:**
   ```json
   {
     "name": "Tulasi Solutions",
     "createdAt": (timestamp)
   }
   ```

---

## 📋 Step 9: Test the Integration

1. **Run the app:**
   ```powershell
   flutter run -d chrome
   ```

2. **Navigate to:** `/chat`

3. **Check:** 
   - [ ] Conversations screen loads
   - [ ] No errors in console
   - [ ] Can create new conversation

---

## 🔧 Troubleshooting

### "Permission Denied" Error
- Check Firestore rules are deployed
- Verify clientId is correct
- Check user is authenticated

### "Cloud Function Not Found"
- Deploy functions: `firebase deploy --only functions`
- Check function logs in Firebase Console

### Messages Not Sending
- Check MSG91 secrets are set correctly
- Verify webhook URL in MSG91 dashboard
- Check function logs for errors

### Outbound Status Works but Inbound Messages Are Missing
- In MSG91, go to **WhatsApp → Settings → Webhooks**.
- Use `https://asia-south1-newproject1234561.cloudfunctions.net/msg91Webhook`.
- Ensure **Message received** is enabled; delivery and read callbacks alone do not include customer replies.
- Send a new reply, then confirm the logs contain `msg91Webhook received` with no `direction: "1"` value. `direction: "1"` is an outbound status callback, not an inbound message.

---

## 📁 Files Reference

| Source (TulasiConnect) | Destination (TulasiSolutions) |
|----------------------|------------------------------|
| `lib/core/models/message_model.dart` | `lib/core/chat/message_model.dart` |
| `lib/core/providers/chat_provider.dart` | `lib/core/chat/chat_provider.dart` |
| `lib/core/services/msg91_service.dart` | `lib/core/chat/msg91_service.dart` |
| `lib/features/chat/chat_screen.dart` | `lib/features/chat/chat_screen.dart` |
| `lib/features/chat/unified_conversations_screen.dart` | `lib/features/chat/conversations_screen.dart` |

---

## ⏱️ Estimated Time

| Task | Time |
|------|------|
| Add dependencies | 5 min |
| Update router | 10 min |
| Setup provider | 15 min |
| Deploy functions | 20 min |
| Configure MSG91 | 10 min |
| Testing | 15 min |
| **Total** | **~1-1.5 hours** |

---

*Created: 2026-08-28*
