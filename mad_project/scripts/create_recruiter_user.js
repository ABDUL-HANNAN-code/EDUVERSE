// Usage:
//   node scripts/create_recruiter_user.js [email] [password]
// Requires GOOGLE_APPLICATION_CREDENTIALS to be set to a service account JSON.

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file.');
  process.exit(1);
}

try { admin.initializeApp({ credential: admin.credential.applicationDefault() }); } catch (e) { }
const auth = admin.auth();
const db = admin.firestore();

const args = process.argv.slice(2);
const email = args[0] || 'recruiter@gmail.com';
const password = args[1] || 'YOURSRECRUITER';

async function createOrUpdateRecruiter() {
  try {
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
      console.log('User already exists:', userRecord.uid, '- updating password');
      userRecord = await auth.updateUser(userRecord.uid, { password });
    } catch (err) {
      // If user not found, create
      if (err.code === 'auth/user-not-found' || /not-found/.test(err.message)) {
        userRecord = await auth.createUser({ email, password, emailVerified: true });
        console.log('Created user:', userRecord.uid);
      } else {
        throw err;
      }
    }

    const uid = userRecord.uid;

    // Ensure Firestore document exists with recruiter role
    const userDocRef = db.collection('users').doc(uid);
    await userDocRef.set({
      uid,
      email,
      fullName: 'Recruiter Admin',
      role: 'recruiter',
      isActive: true,
      isApproved: true,
      emailVerified: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log('Firestore user document created/updated at users/' + uid);
    console.log('Credentials:');
    console.log('  email:', email);
    console.log('  password:', password);
    process.exit(0);
  } catch (e) {
    console.error('Error creating/updating recruiter:', e);
    process.exit(1);
  }
}

createOrUpdateRecruiter();
