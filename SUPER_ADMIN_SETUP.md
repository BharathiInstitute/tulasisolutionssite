# Super Admin Setup Instructions

## Quick Start: Create Super Admin User

### Email: `kehsaram001@gmail.com`

---

## Method 1: Firebase Console (Recommended for First-Time Setup)

### Step 1: Create Firebase Auth User

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project: `tulasi-solutions-cms`
3. Go to **Authentication** → **Users**
4. Click **Add User** button
5. Fill in:
   - Email: `kehsaram001@gmail.com`
   - Password: `SuperAdmin@123` (or your preferred strong password)
6. Click **Add User**

### Step 2: Set Admin Flag in Firestore

1. Go to **Firestore Database**
2. Navigate to **Collections** → **users**
3. Find the document matching the UID of the user you just created
4. Click **Edit** on the document
5. Add/Update these fields:

```
{
  "uid": "THE_USER_UID_FROM_FIREBASE_AUTH",
  "email": "kehsaram001@gmail.com",
  "name": "Super Admin",
  "isAdmin": true,  ← This is the critical field
  "createdAt": timestamp
}
```

6. Click **Save**

---

## Method 2: Programmatic Setup (Using Flutter App)

### Step 1: Run the app
```bash
flutter run
```

### Step 2: Sign Up with Super Admin Email
- Click **Sign up**
- Email: `kehsaram001@gmail.com`
- Password: `SuperAdmin@123`
- Name: `Super Admin`
- Click **Create Account**

### Step 3: Manually Mark as Admin (via Firebase Console)
Follow "Method 1: Step 2" to set `isAdmin: true` in Firestore

### Step 4: Restart the app
After setting `isAdmin: true`, restart the app:
```bash
flutter run
```

---

## Method 3: Firebase CLI (Advanced)

If you have Firebase CLI installed:

```bash
# Get the UID of the user (from Firebase Console → Authentication → Users)
# Then run:

firebase firestore:set users/USER_UID '{
  "uid": "USER_UID",
  "email": "kehsaram001@gmail.com",
  "name": "Super Admin",
  "isAdmin": true,
  "createdAt": firebase.firestore.Timestamp.now()
}'
```

---

## Verification Checklist

After setup, verify everything works:

- [ ] User `kehsaram001@gmail.com` exists in Firebase Auth
- [ ] User document exists in Firestore `users` collection
- [ ] User document has `isAdmin: true`
- [ ] Can sign in with email and password
- [ ] After signin, redirects to `/admin/clients` (not `/client/dashboard`)
- [ ] Can see and manage all clients
- [ ] Can create/edit/delete goals

---

## Testing Flow

### Test 1: Admin Login
```
1. Open app → Login screen
2. Email: kehsaram001@gmail.com
3. Password: SuperAdmin@123
4. ✓ Should see: Admin Dashboard (Client List)
```

### Test 2: Create Client
```
1. Admin Dashboard → + Add Client
2. Enter client details
3. ✓ Client appears in list
4. ✓ Can click to view profile
```

### Test 3: Create Goal for Client
```
1. Client Profile → Goals tab → + Add Goal
2. Enter goal details (type, baseline, lift %)
3. ✓ Goal created and visible in list
```

### Test 4: Admin Permissions
```
1. Try to access /admin/* routes
2. ✓ All admin routes accessible
3. ✓ Cannot access /client/* routes
```

---

## Firestore Document Structure

After successful setup, your Firestore should have:

```
firestore/
├── users/
│   └── [USER_UID]/
│       ├── uid: "USER_UID"
│       ├── email: "kehsaram001@gmail.com"
│       ├── name: "Super Admin"
│       ├── isAdmin: true          ← KEY FIELD
│       └── createdAt: Timestamp
```

---

## Troubleshooting

### "Not logged in" - User not redirecting to admin
- Check Firestore: does the user have `isAdmin: true`?
- Restart the app after updating Firestore
- Clear app cache: `flutter clean`

### "Permission denied" when accessing admin routes
- Verify Firestore security rules are correct
- Check that user email matches exactly in all places

### "Invalid password" when signing in
- Ensure password is at least 6 characters
- Check for spaces or special characters

### User can't sign up
- Verify Email/Password auth is enabled in Firebase Console
- Check internet connection

---

## Additional Test Users

After creating the super admin, you can create test users:

### Test Admin 2
- Email: `admin2@example.com`
- isAdmin: `true`

### Test Client User  
- Email: `client@example.com`
- isAdmin: `false` (or omit field)
- Expected behavior: Redirects to `/client/dashboard`

---

## Security Notes

⚠️ **Important for Production:**

1. Change default super admin password regularly
2. Enable MFA (Multi-Factor Authentication) in Firebase Console
3. Review Firestore security rules (see FIREBASE_SETUP.md)
4. Only set `isAdmin: true` for trusted users
5. Use environment variables for sensitive data
6. Enable Cloud Firestore backup

---

## Support

- Firebase issues: Check [Firebase Documentation](https://firebase.flutter.dev/)
- Flutter issues: Check [Flutter Docs](https://flutter.dev/docs)
- App routing: Check `lib/router.dart`
- Authentication logic: Check `lib/core/services/firebase_service.dart`
