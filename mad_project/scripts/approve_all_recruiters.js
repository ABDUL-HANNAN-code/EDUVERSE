// approve_all_recruiters.js
// Usage:
// 1. Obtain a Firebase service account JSON and set the path in
//    the environment variable GOOGLE_APPLICATION_CREDENTIALS
//    or place the file next to this script as serviceAccountKey.json
// 2. Run: `node scripts/approve_all_recruiters.js`

const admin = require('firebase-admin');
const fs = require('fs');

// Accept path as first CLI arg, else env var, else default filename next to script
const keyPath = process.argv[2] || process.env.GOOGLE_APPLICATION_CREDENTIALS || './serviceAccountKey.json';
if (!fs.existsSync(keyPath)) {
  console.error('Service account JSON not found at', keyPath);
  console.error('Provide the path as an argument or set GOOGLE_APPLICATION_CREDENTIALS.');
  console.error('Example: node scripts/approve_all_recruiters.js "C:\\Users\\a\\secrets\\service-account.json"');
  process.exit(1);
}

const serviceAccount = require(keyPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function approveAllRecruiters() {
  console.log('Querying recruiter users...');
  const snap = await db.collection('users').where('role', '==', 'recruiter').get();
  console.log('Found', snap.size, 'recruiter(s)');
  for (const doc of snap.docs) {
    try {
      await db.collection('users').doc(doc.id).update({ isApproved: true });
      console.log('Approved:', doc.id);
    } catch (e) {
      console.error('Failed to update', doc.id, e.message || e);
    }
  }
  console.log('Done.');
  process.exit(0);
}

approveAllRecruiters().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
