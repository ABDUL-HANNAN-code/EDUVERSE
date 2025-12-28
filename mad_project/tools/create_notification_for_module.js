#!/usr/bin/env node
/*
 * Create a notifications doc for testing module flows and optionally send push.
 * Usage examples:
 *  node tools/create_notification_for_module.js --serviceAccount=./serviceAccount.json --projectId=my-project-859f5 --module=announcement --uniId=AIRU --title="New Announcement" --body="Hello students" --send
 *  node tools/create_notification_for_module.js --serviceAccount=./serviceAccount.json --projectId=my-project-859f5 --module=marketplace --uniId=AIRU --item="Phone" --price="5000"
 *  node tools/create_notification_for_module.js --serviceAccount=./serviceAccount.json --projectId=my-project-859f5 --module=lostfound --uniId=AIRU --item="Keys" --isLost=true --send
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = {};
  for (let i = 2; i < process.argv.length; i++) {
    const a = process.argv[i];
    if (!a.startsWith('--')) continue;
    const eq = a.indexOf('=');
    if (eq === -1) {
      args[a.slice(2)] = true;
    } else {
      const k = a.slice(2, eq);
      const v = a.slice(eq + 1);
      args[k] = v;
    }
  }
  return args;
}

async function main() {
  const argv = parseArgs();
  const saPath = argv.serviceAccount;
  let projectId = argv.projectId || process.env.GCLOUD_PROJECT;
  const module = argv.module || 'announcement';
  const uniId = argv.uniId || argv.uni || null;
  const send = !!argv.send;

  if (!saPath) {
    console.error('Missing --serviceAccount=./path.json');
    process.exit(1);
  }

  // Resolve candidate paths: cwd-relative first, then script-dir relative
  const candidatePaths = [
    path.resolve(process.cwd(), saPath),
    path.resolve(__dirname, saPath),
  ];

  let foundPath = candidatePaths.find(p => fs.existsSync(p));
  if (!foundPath) {
    console.error('Service account file not found. Checked the following locations:');
    candidatePaths.forEach(p => console.error(' -', p));
    process.exit(1);
  }

  let serviceAccountRaw;
  try {
    serviceAccountRaw = fs.readFileSync(foundPath, 'utf8');
  } catch (err) {
    console.error('Failed to read service account file:', foundPath, err.message);
    process.exit(1);
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountRaw);
  } catch (err) {
    console.error('Failed to parse service account JSON:', err.message);
    process.exit(1);
  }

  projectId = projectId || serviceAccount.project_id;

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId,
  });

  const db = admin.firestore();

  // Build notification payload per module
  let title = argv.title || '';
  let body = argv.body || '';
  const data = {};
  const typeMapping = {
    announcement: 'announcement',
    timetable: 'timetable',
    lostfound: 'lostAndFound',
    marketplace: 'marketplace',
    job: 'jobPosting',
    complaint: 'complaintInProgress'
  };

  switch (module) {
    case 'announcement':
      title = title || (argv.title || 'New Announcement');
      body = body || (argv.body || 'Please check the announcement');
      data.announcement_id = argv.announcementId || 'test-ann-' + Date.now();
      break;
    case 'timetable':
      title = title || 'Timetable Updated';
      body = body || `Class ${argv.className || 'X'} schedule changed`;
      data.timetable_id = argv.timetableId || 'tt-' + Date.now();
      break;
    case 'lostfound':
      const item = argv.item || 'an item';
      const isLost = argv.isLost === 'true' || argv.isLost === true || argv.isLost === '1';
      title = title || (isLost ? 'Lost Item Posted' : 'Item Found');
      body = body || `Someone posted about: ${item}`;
      data.post_id = argv.postId || 'lf-' + Date.now();
      data.is_lost = !!isLost;
      break;
    case 'marketplace':
      const itemName = argv.item || argv.itemName || 'Item';
      const price = argv.price || argv.amount || '0';
      title = title || 'New Item Listed';
      body = body || `${itemName} listed for ${price}`;
      data.post_id = argv.postId || 'mp-' + Date.now();
      break;
    case 'job':
      title = title || (argv.title || 'New Job Posting');
      body = body || (argv.body || (argv.company ? `${argv.company} posted a job` : 'A new job was posted'));
      data.job_id = argv.jobId || 'job-' + Date.now();
      break;
    case 'complaint':
      title = title || 'Complaint Status Updated';
      body = body || argv.body || 'Your complaint status changed';
      data.complaint_id = argv.complaintId || 'c-' + Date.now();
      break;
    default:
      title = title || 'Test Notification';
      body = body || 'This is a test notification';
  }

  const doc = {
    title,
    body,
    type: typeMapping[module] || 'custom',
    priority: 'normal',
    universityId: uniId,
    userId: argv.userId || null,
    imageUrl: argv.imageUrl || null,
    imageBase64: argv.imageBase64 || null,
    data,
    isRead: false,
    isPushSent: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    const docRef = await db.collection('notifications').add(doc);
    console.log('Created notification doc:', docRef.id);

    if (send) {
      if (doc.userId) {
        const tokensSnap = await db.collection('users').doc(doc.userId).collection('fcmTokens').get();
        const tokens = tokensSnap.docs.map(d => d.id).filter(Boolean);
        if (tokens.length === 0) console.log('No tokens for user', doc.userId);
        else {
          const message = { notification: { title, body }, data, tokens };
          const resp = await admin.messaging().sendMulticast(message);
          console.log('sendMulticast results:', resp.responses.map(r => (r.success ? 'ok' : (r.error && r.error.message) || 'err')));
        }
      } else {
        if (!uniId) console.error('No uniId provided for broadcast');
        else {
          const message = { topic: `university_${uniId}`, notification: { title, body }, data };
          const resp = await admin.messaging().send(message);
          console.log('Sent to topic:', resp);
        }
      }
      await db.collection('notifications').doc(docRef.id).update({ isPushSent: true });
      console.log('Marked isPushSent=true');
    }

    process.exit(0);
  } catch (e) {
    console.error('Failed to create/send notification:', e);
    process.exit(1);
  }
}

main();
