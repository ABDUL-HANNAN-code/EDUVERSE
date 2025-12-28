#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = {};
  for (let i = 2; i < process.argv.length; i++) {
    const a = process.argv[i];
    if (!a.startsWith('--')) continue;
    const eq = a.indexOf('=');
    if (eq === -1) args[a.slice(2)] = true;
    else args[a.slice(2, eq)] = a.slice(eq + 1);
  }
  return args;
}

function loadServiceAccount(saPath) {
  if (!saPath) {
    console.error('Missing --serviceAccount=./path.json');
    process.exit(1);
  }
  const candidates = [path.resolve(process.cwd(), saPath), path.resolve(__dirname, saPath)];
  const found = candidates.find(p => fs.existsSync(p));
  if (!found) {
    console.error('Service account file not found. Checked:');
    candidates.forEach(p => console.error(' -', p));
    process.exit(1);
  }
  try {
    const raw = fs.readFileSync(found, 'utf8');
    return JSON.parse(raw);
  } catch (e) {
    console.error('Failed to read/parse service account JSON:', e.message);
    process.exit(1);
  }
}

async function main() {
  const argv = parseArgs();
  const saPath = argv.serviceAccount;
  const projectIdArg = argv.projectId;
  const send = !!argv.send;
  const uniId = argv.uniId || argv.uni;

  const sa = loadServiceAccount(saPath);
  const projectId = projectIdArg || sa.project_id || process.env.GCLOUD_PROJECT;

  admin.initializeApp({ credential: admin.credential.cert(sa), projectId });
  const db = admin.firestore();

  const modules = ['announcement','timetable','lostfound','marketplace','job','complaint'];

  for (const module of modules) {
    let title = '';
    let body = '';
    const data = {};
    const now = Date.now();

    switch (module) {
      case 'announcement':
        title = 'Test Announcement';
        body = 'Welcome back!';
        data.announcement_id = 'test-ann-' + now;
        break;
      case 'timetable':
        title = 'Timetable Updated';
        body = 'Class Math 101 schedule changed';
        data.timetable_id = 'tt-' + now;
        break;
      case 'lostfound':
        title = 'Item Found Posted';
        body = 'Someone posted about: test';
        data.post_id = 'lf-' + now;
        data.is_lost = false;
        break;
      case 'marketplace':
        title = 'New Item Listed';
        body = 'Used Phone listed for 5000';
        data.post_id = 'mp-' + now;
        break;
      case 'job':
        title = 'New Job Posting';
        body = 'ACME Corp posted a job';
        data.job_id = 'job-' + now;
        break;
      case 'complaint':
        title = 'Complaint Status Updated';
        body = 'Your complaint status changed';
        data.complaint_id = 'c-' + now;
        break;
      default:
        title = 'Test Notification';
        body = 'This is a test';
    }

    const doc = {
      title,
      body,
      type: module === 'lostfound' ? 'lostAndFound' : module === 'job' ? 'jobPosting' : module === 'complaint' ? 'complaintInProgress' : module,
      priority: 'normal',
      universityId: uniId || null,
      userId: null,
      imageUrl: null,
      imageBase64: null,
      data,
      isRead: false,
      isPushSent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      const docRef = await db.collection('notifications').add(doc);
      console.log('Created notification for', module, '->', docRef.id);

      if (send) {
        if (!uniId) console.error('No --uniId provided; skipping send for', module);
        else {
          // Ensure all data values are strings for FCM
          const stringData = {};
          for (const k of Object.keys(data)) stringData[k] = typeof data[k] === 'string' ? data[k] : JSON.stringify(data[k]);

          const message = { topic: `university_${uniId}`, notification: { title, body }, data: stringData };
          try {
            const resp = await admin.messaging().send(message);
            console.log('Sent', module, 'messageId:', resp);
            await db.collection('notifications').doc(docRef.id).update({ isPushSent: true });
          } catch (e) {
            console.error('Failed to send', module, e.message || e);
          }
        }
      }
    } catch (e) {
      console.error('Failed creating notification for', module, e.message || e);
    }
  }

  console.log('Done creating test notifications.');
  process.exit(0);
}

main();
