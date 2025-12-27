/*
Node migration script: migrate_announcements_to_base64.js

Usage:
1. Place your Firebase service account JSON at ./tools/serviceAccountKey.json
2. Install dependencies: npm install firebase-admin node-fetch@2
3. Run: node tools/migrate_announcements_to_base64.js

This script will:
- Read all documents in the 'announcements' collection where `imageUrl` exists
- Fetch the image bytes from the URL
- Convert to base64 and write to `imageBase64` field
- Remove the `imageUrl` field

Be careful: run on a copy or backup first.
*/

const admin = require('firebase-admin');
const fetch = require('node-fetch');
const fs = require('fs');

const serviceAccountPath = './tools/serviceAccountKey.json';
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Missing service account JSON at', serviceAccountPath);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

const db = admin.firestore();

async function migrate() {
  console.log('Querying announcements with imageUrl...');
  const snapshot = await db.collection('announcements').where('imageUrl', '!=', null).get();
  console.log('Found', snapshot.size, 'docs');
  let count = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const imageUrl = data.imageUrl;
    if (!imageUrl) continue;
    try {
      console.log('Fetching', imageUrl);
      const res = await fetch(imageUrl);
      if (!res.ok) throw new Error('Fetch failed: ' + res.status);
      const buffer = await res.buffer();
      const base64 = buffer.toString('base64');
      await doc.ref.update({
        imageBase64: base64,
        imageUrl: admin.firestore.FieldValue.delete(),
      });
      count++;
      console.log('Updated', doc.id);
    } catch (e) {
      console.error('Failed for', doc.id, e.message || e);
    }
  }
  console.log('Migration complete. Updated', count, 'documents');
}

migrate().catch(err => { console.error(err); process.exit(1); });
