// Usage: 
//   node scripts/add_university_domain.js AIRU students.au.edu.pk
// Requires GOOGLE_APPLICATION_CREDENTIALS env var pointing to service account JSON

const admin = require('firebase-admin');
const fs = require('fs');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file');
  process.exit(1);
}

try {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
} catch (e) {
  // already initialized
}

const db = admin.firestore();

async function addDomain(uniId, domain) {
  const docRef = db.collection('universities').doc(uniId);
  const doc = await docRef.get();
  if (!doc.exists) {
    console.error('University not found:', uniId);
    process.exit(2);
  }
  const data = doc.data() || {};
  const domains = Array.isArray(data.domains) ? data.domains : [];
  if (domains.includes(domain)) {
    console.log('Domain already present:', domain);
    return;
  }
  domains.push(domain);
  await docRef.update({ domains });
  console.log(`Added domain ${domain} to university ${uniId}`);
}

const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: node scripts/add_university_domain.js <UNIID> <DOMAIN>');
  process.exit(1);
}
addDomain(args[0], args[1]).catch(e => { console.error(e); process.exit(1); });
