/**
 * Seed script for Air University sample data
 *
 * Usage:
 * 1. Install dependencies: `npm install firebase-admin`
 * 2. Set service account key path:
 *    Windows (PowerShell): $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\serviceAccount.json"
 *    Linux/macOS: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 * 3. (Optional) provide a SUPER_ADMIN_UID env var to create a super_admins doc for that UID.
 *    e.g. $env:SUPER_ADMIN_UID="your-firebase-uid"; node scripts/seed_air_university.js
 *
 * The script creates:
 * - universities/AIRU
 * - universities/AIRU/departments/cs and /ee
 * - sections under departments (A/B)
 * - universities/AIRU/allowed_ids/{sampleStudentId}
 * - (optional) super_admins/{SUPER_ADMIN_UID}
 */

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Please set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.');
  process.exit(1);
}

try {
  admin.initializeApp();
} catch (e) {
  // ignore if already initialized in some environments
}
const db = admin.firestore();

async function seed() {
  const uniId = 'AIRU';
  const uniRef = db.collection('universities').doc(uniId);

  console.log(`Creating university ${uniId}...`);
  await uniRef.set({ name: 'Air University', city: 'Islamabad', createdAt: admin.firestore.FieldValue.serverTimestamp() });

  console.log('Creating departments and sections...');
  const depts = [
    { id: 'cs', name: 'Computer Science' },
    { id: 'ee', name: 'Electrical Engineering' },
  ];

  for (const d of depts) {
    const deptRef = uniRef.collection('departments').doc(d.id);
    await deptRef.set({ name: d.name, code: d.id });
    // add two sections A and B
    await deptRef.collection('sections').doc('A').set({ name: 'A', shift: 'morning' });
    await deptRef.collection('sections').doc('B').set({ name: 'B', shift: 'evening' });
  }

  console.log('Adding sample allowed student ID...');
  const sampleId = '2025AIRCS001';
  await uniRef.collection('allowed_ids').doc(sampleId).set({ createdAt: admin.firestore.FieldValue.serverTimestamp() });

  if (process.env.SUPER_ADMIN_UID) {
    const uid = process.env.SUPER_ADMIN_UID;
    console.log(`Creating super_admins/${uid} ...`);
    await db.collection('super_admins').doc(uid).set({ email: 'super@airu.test', createdAt: admin.firestore.FieldValue.serverTimestamp() });
  } else {
    console.log('No SUPER_ADMIN_UID provided — skipping super admin creation.');
  }

  console.log('Seed complete. University:', uniId, 'sample student id:', sampleId);
}

seed().catch(err => {
  console.error('Error seeding data:', err);
  process.exit(1);
});
