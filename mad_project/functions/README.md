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
