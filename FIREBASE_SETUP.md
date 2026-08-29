# Firebase Setup Guide for Tulasi Solutions Client Management Panel

## Prerequisites
- Firebase Project created at [Firebase Console](https://console.firebase.google.com)
- Flutter CLI installed
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project"
3. Enter project name: `tulasi-solutions-cms`
4. Enable Google Analytics (optional)
5. Create project

## Step 2: Configure FlutterFire

Run the FlutterFire configuration command:

```bash
flutterfire configure
```

Select:
- ✅ Web
- ✅ Android  
- ✅ iOS
- ✅ macOS
- ✅ Windows

This will update `lib/firebase_options.dart` with your project credentials.

## Step 3: Enable Authentication Methods

### In Firebase Console:

1. Navigate to **Authentication** → **Sign-in method**
2. Enable **Email/Password** provider
3. Enable **Anonymous** (optional, for testing)

## Step 4: Create Admin User

### Option A: Via Firebase Console

1. Go to **Authentication** → **Users**
2. Click **Add User**
3. Enter:
   - Email: `kehsaram001@gmail.com`
   - Password: (strong password)
4. Click **Add User**

### Option B: Via App (First Time Setup)

Run app and sign up with:
- Email: `kehsaram001@gmail.com`
- Password: (set strong password)
- Name: `Super Admin`

Then manually update Firestore:

## Step 5: Set Super Admin Permission

### In Firebase Console:

1. Go to **Firestore** → **Collections** → **users**
2. Find document with email `kehsaram001@gmail.com`
3. Edit the document and set: `isAdmin: true`

### Via Terminal (Using Firebase CLI):

```bash
firebase firestore:set --data '{"isAdmin":true,"email":"kehsaram001@gmail.com","uid":"USER_UID","name":"Super Admin"}' users/USER_UID
```

Replace `USER_UID` with actual Firebase UID.

## Step 6: Firestore Security Rules

Create these security rules in Firestore:

1. Go to **Firestore** → **Rules**
2. Replace with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - only admins can read all, users can read own
    match /users/{uid} {
      allow read: if request.auth.uid == uid || 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
      allow write: if request.auth.uid == uid && !request.resource.data.isAdmin ||
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

    // Clients - only admins can read/write
    match /clients/{clientId} {
      allow read, write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
      
      // Subcollections
      match /{allSubcollections=**} {
        allow read, write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
      }
    }

    // Consultations - admins can access
    match /consultations/{doc=**} {
      allow read, write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
  }
}
```

## Step 7: Environment Setup

### Update `lib/firebase_options.dart`

The `flutterfire configure` command will populate:
- `apiKey`
- `appId`
- `messagingSenderId`
- `projectId`
- `authDomain`
- `storageBucket`
- `measurementId` (Web only)

## Step 8: Test Firebase Connection

Run the app:

```bash
flutter run
```

### Test Sequence:

1. **Sign In Screen**: Appears with login/signup forms
2. **Create Test Account**: 
   - Email: `kehsaram001@gmail.com`
   - Password: `TestPassword123!`
   - Name: `Super Admin`
3. **Verify Admin Access**: 
   - After signin, should see Admin Dashboard
   - Go to Firestore, set `isAdmin: true` for this user
   - Restart app - should redirect to `/admin/clients`

## Admin User Verification Flow

```
1. User logs in with email/password
   ↓
2. Firebase Auth validates credentials
   ↓
3. App fetches user data from Firestore
   ↓
4. Check isAdmin flag
   ↓
5. If isAdmin=true → Route to /admin/*
   If isAdmin=false → Route to /client/*
```

## Test Users to Create

### Super Admin User
- Email: `kehsaram001@gmail.com`
- Role: `isAdmin: true`
- Access: Full admin panel

### Test Client User
- Email: `testclient@example.com`
- Role: `isAdmin: false`
- Access: Client dashboard only

## Firebase Database Structure

```
Firestore:
├── users/
│   ├── {uid}
│   │   ├── uid: string
│   │   ├── email: string
│   │   ├── name: string
│   │   ├── isAdmin: boolean ← Key field for routing
│   │   └── createdAt: timestamp
│   
├── clients/
│   ├── {clientId}
│   │   ├── id: string
│   │   ├── name: string
│   │   ├── stage: string
│   │   ├── managerId: string
│   │   ├── goals/
│   │   │   └── {goalId}
│   │   ├── setup_checklist/
│   │   │   └── {itemId}
│   │   └── software_stage/
│   │       └── current
│   
└── consultations/
    └── {consultationId}
```

## Troubleshooting

### "Firebase app not initialized"
- Run `flutterfire configure` again
- Check `firebase_options.dart` has real credentials

### "Permission denied" errors
- Verify Firestore security rules are updated
- Check user has `isAdmin: true` in Firestore

### "Connection timeout"
- Ensure internet connection
- Check Firebase project is active
- Verify project ID matches in `firebase_options.dart`

### Email login not working
- Verify Email/Password auth is enabled in Firebase Console
- Check user email is in Firebase Auth Users list
- Ensure password meets requirements

## Quick Commands

```bash
# Check Flutter Doctor
flutter doctor

# Run app
flutter run

# View Firebase logs (requires Firebase CLI)
firebase functions:log

# Update dependencies
flutter pub get

# Clean build
flutter clean && flutter pub get
```

## Next Steps

1. ✅ Set up Firebase Project
2. ✅ Configure FlutterFire credentials
3. ✅ Enable Email/Password authentication
4. ✅ Create super admin user: `kehsaram001@gmail.com`
5. ✅ Set admin flag in Firestore
6. ⏭️ Update router with admin verification
7. ⏭️ Test complete flow

## Support

For Firebase issues: [Firebase Documentation](https://firebase.flutter.dev/)
For Flutter issues: [Flutter Docs](https://flutter.dev/docs)
