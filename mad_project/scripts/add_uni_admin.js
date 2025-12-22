// Usage:
//   node scripts/add_uni_admin.js <UNIID> <UID>
// Example: node scripts/add_uni_admin.js AIRU someUserUid
// Requires GOOGLE_APPLICATION_CREDENTIALS to be set to a service account JSON.

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file.');
  process.exit(1);
}

try { admin.initializeApp({ credential: admin.credential.applicationDefault() }); } catch (e) { }
const db = admin.firestore();

async function addUniAdmin(uniId, uid) {
  const docRef = db.collection('universities').doc(uniId).collection('admins').doc(uid);
  await docRef.set({ role: 'admin', createdAt: admin.firestore.FieldValue.serverTimestamp() });
  console.log(`Created universities/${uniId}/admins/${uid}`);
}

const uniId = process.argv[2];
const uid = process.argv[3];
if (!uniId || !uid) {
  console.error('Usage: node scripts/add_uni_admin.js <UNIID> <UID>');
  process.exit(1);
}
addUniAdmin(uniId, uid).catch(e => { console.error(e); process.exit(1); });
