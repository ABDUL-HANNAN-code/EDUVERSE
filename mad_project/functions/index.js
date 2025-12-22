const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Callable function to set a user's role and admin scope.
 * Only callers who are present in `/super_admins/{callerUid}` may invoke this.
 *
 * Payload: { uid: string, role: 'student'|'admin'|'super_admin', scope: { uniId?: string, deptId?: string } }
 */
exports.setUserRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const callerUid = context.auth.uid;
  const callerIsSuper = await admin.firestore().doc(`super_admins/${callerUid}`).get();
  if (!callerIsSuper.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Only super-admins may call this function');
  }

  const uid = data.uid;
  const role = data.role;
  const scope = data.scope || null;

  if (!uid || !role) {
    throw new functions.https.HttpsError('invalid-argument', 'uid and role are required');
  }

  const db = admin.firestore();
  const userRef = db.doc(`users/${uid}`);

  const updateData = { role };
  if (role === 'admin' && scope) updateData.adminScope = scope;
  else updateData.adminScope = admin.firestore.FieldValue.delete();

  // Update/create user doc with role/adminScope
  await userRef.set(updateData, { merge: true });

  // Maintain universities/{uni}/admins/{uid} doc for department/uni admins
  if (role === 'admin' && scope && scope.uniId) {
    const adminDocRef = db.doc(`universities/${scope.uniId}/admins/${uid}`);
    await adminDocRef.set({ deptId: scope.deptId ?? null, assignedAt: admin.firestore.FieldValue.serverTimestamp() });
  } else {
    // Remove any existing admin entry for this uid across universities
    const unisSnap = await db.collection('universities').get();
    const deletes = [];
    for (const u of unisSnap.docs) {
      const admRef = db.doc(`universities/${u.id}/admins/${uid}`);
      const admSnap = await admRef.get();
      if (admSnap.exists) deletes.push(admRef.delete());
    }
    if (deletes.length) await Promise.all(deletes);
  }

  // Update custom claims for the target user (helpful for client-side checks)
  const claims = {};
  if (role === 'super_admin') claims.super_admin = true;
  if (role === 'admin') {
    claims.admin = true;
    if (scope?.uniId) claims.uniId = scope.uniId;
    if (scope?.deptId) claims.deptId = scope.deptId;
  }
  // If role is student, we clear claims by setting an empty object
  await admin.auth().setCustomUserClaims(uid, claims);

  return { success: true };
});
