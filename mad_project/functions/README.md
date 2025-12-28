Functions helper notes

This functions folder includes two callable functions:
- `setUserRole` (existing): used by super-admins to set roles
- `createFacultyInvite` (added): callable by admins/super-admins to generate an invite, persist it to `invites` collection, and send an email via SendGrid
 - `createFacultyInvite` (added): callable by admins/super-admins to generate an invite, persist it to `invites` collection, and send an email via SendGrid
 - `sendNotification` (added): callable to send an FCM push for a `notifications/{id}` doc. Payload: `{ notificationId }`.
 - `subscribeToken` (added): callable to subscribe a device token to `university_{uniId}` topic. Payload: `{ token, universityId }`.

Environment setup
1. Install dependencies:

```bash
cd functions
npm install
```

2. Configure SendGrid (optional, for real email delivery):

```bash
firebase functions:config:set sendgrid.key="<SENDGRID_API_KEY>" sendgrid.sender="no-reply@yourdomain.com"
```

3. Deploy functions:

```bash
cd ..
firebase deploy --only functions
```

Testing locally (emulator)
1. Start emulators:

```bash
firebase emulators:start --only auth,firestore,functions
```

2. Call the function from client code using `FirebaseFunctions.instance.httpsCallable('createFacultyInvite')` (Flutter) or via `firebase.functions().httpsCallable('createFacultyInvite')` (web/Node).

Notes
- If SendGrid is not configured, the function will store the invite in Firestore and return `{emailed:false}`.
- The function returns the generated code to the caller when invoked by an admin. If you prefer not to return the code to the client, modify the function to return only `{success:true}`.
 - `sendNotification` expects a notification document in `notifications/` with fields like `title`, `body`, `universityId`. It will send to `users/{userId}/fcmTokens` if `userId` is set, otherwise to topic `university_{universityId}`.
 - `subscribeToken` helps subscribe tokens to a topic; the client calls this after saving tokens if desired.
Firebase Cloud Function: setUserRole

What it does
- Sets a user's `role` and `adminScope` in `/users/{uid}`.
- Maintains a `/universities/{uni}/admins/{uid}` document for dept/uni admins.
- Updates custom auth claims for the user (`super_admin`, `admin`, plus `uniId`/`deptId`).

Security
- Only callers who have an entry in `/super_admins/{callerUid}` can call this function.

Deploy
1. Install deps:

```bash
cd functions
npm install
```

2. Deploy the function:

```bash
firebase deploy --only functions:setUserRole
```

Call from client (example using Firebase JS SDK):

```js
const setUserRole = firebase.functions().httpsCallable('setUserRole');
await setUserRole({ uid: 'userUid', role: 'admin', scope: { uniId: 'air_uni', deptId: 'cse' } });
```

After deploying, the function will run with admin privileges and update Firestore and auth claims.
