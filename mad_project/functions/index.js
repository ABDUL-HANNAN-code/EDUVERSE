const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Optional: SendGrid for outgoing emails. Configure with `firebase functions:config:set sendgrid.key="KEY" sendgrid.sender="no-reply@yourdomain.com"`
let sgMail;
try {
  sgMail = require('@sendgrid/mail');
} catch (e) {
  sgMail = null;
}

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

/**
 * Callable function to generate a faculty invite, persist it, and email it to the recipient.
 * Only callers who are `admin` or present in `/super_admins/{callerUid}` can create invites.
 * Payload: { email: string }
 */
exports.createFacultyInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const callerUid = context.auth.uid;
  const db = admin.firestore();

  // Check caller role (admin) or super_admins collection
  const callerDoc = await db.doc(`users/${callerUid}`).get();
  const callerRole = callerDoc.exists ? (callerDoc.data().role || '') : '';
  const isSuper = (await db.doc(`super_admins/${callerUid}`).get()).exists;
  if (!(callerRole === 'admin' || isSuper)) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins or super-admins may create invites');
  }

  const email = (data && data.email) ? String(data.email).trim() : '';
  if (!email || !email.includes('@')) {
    throw new functions.https.HttpsError('invalid-argument', 'A valid email is required');
  }

  // Generate a random 6-character alphanumeric code
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const rnd = () => Math.floor(Math.random() * chars.length);
  const suffix = Array.from({ length: 6 }).map(() => chars[rnd()]).join('');
  const code = `FAC-${suffix}`;

  // Persist invite
  const inviteDoc = {
    code: code,
    email: email,
    role: 'faculty',
    isUsed: false,
    createdBy: callerUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('invites').add(inviteDoc);

  // Send email using SendGrid if configured
  const sendgridKey = functions.config().sendgrid && functions.config().sendgrid.key;
  const sender = functions.config().sendgrid && functions.config().sendgrid.sender;
  if (!sgMail || !sendgridKey || !sender) {
    // If email sending is not configured, return success but note emails not sent
    return { success: true, emailed: false, code };
  }

  try {
    sgMail.setApiKey(sendgridKey);
    const msg = {
      to: email,
      from: sender,
      subject: 'Your Faculty Invite Code',
      text: `Your faculty invite code is: ${code}`,
      html: `<p>Your faculty invite code is: <strong>${code}</strong></p><p>Use this code to register as faculty.</p>`,
    };
    await sgMail.send(msg);
    return { success: true, emailed: true, code };
  } catch (e) {
    // Log and return success with emailed=false
    console.error('Failed to send invite email', e);
    return { success: true, emailed: false, code };
  }
});

/**
 * Callable function to verify an invite code.
 * This avoids exposing the `invites` collection to unauthenticated clients
 * and prevents client-side permission-denied errors when verifying codes.
 * Payload: { code: string }
 */
exports.verifyFacultyInvite = functions.https.onCall(async (data, context) => {
  const code = data && data.code ? String(data.code).trim() : '';
  if (!code) {
    throw new functions.https.HttpsError('invalid-argument', 'Invite code is required');
  }

  const db = admin.firestore();
  const snap = await db.collection('invites').where('code', '==', code).limit(1).get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Invite code not found');
  }

  const doc = snap.docs[0];
  const dataObj = doc.data();
  if (dataObj.isUsed === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Invite code already used');
  }

  // Return only the safe fields needed by the client
  const safe = {
    id: doc.id,
    code: dataObj.code,
    email: dataObj.email || null,
    role: dataObj.role || null,
    uniId: dataObj.uniId || null,
    facultyName: dataObj.facultyName || null,
    department: dataObj.department || null,
    createdAt: dataObj.createdAt || null,
  };

  return { success: true, invite: safe };
});
