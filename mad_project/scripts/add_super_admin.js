// Usage:
//   node scripts/add_super_admin.js <UID>
// or set env SUPER_ADMIN_UID and run: node scripts/add_super_admin.js
// Requires GOOGLE_APPLICATION_CREDENTIALS to be set to a service account JSON.

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file.');
  process.exit(1);
}

try { admin.initializeApp({ credential: admin.credential.applicationDefault() }); } catch (e) { }
const db = admin.firestore();

async function addSuper(uid) {
  const docRef = db.collection('super_admins').doc(uid);
  await docRef.set({ createdAt: admin.firestore.FieldValue.serverTimestamp() });
  console.log('Created super_admins/' + uid);
}

const uid = process.argv[2] || process.env.SUPER_ADMIN_UID;
if (!uid) {
  console.error('Usage: node scripts/add_super_admin.js <UID> or set SUPER_ADMIN_UID');
  process.exit(1);
}
addSuper(uid).catch(e => { console.error(e); process.exit(1); });