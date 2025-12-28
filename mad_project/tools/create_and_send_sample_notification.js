#!/usr/bin/env node
/*
 * Create a sample notification doc and send it via FCM using a service account.
 * Usage:
 *   node tools/create_and_send_sample_notification.js --serviceAccount=./serviceAccount.json --projectId=my-project-xxx --title="Hello" --body="Test" --uniId=uni123
 * Or target a user:
 *   node tools/create_and_send_sample_notification.js --serviceAccount=./serviceAccount.json --projectId=my-project-xxx --title="Hello" --body="Test" --userId=<uid>
 *
 * This does NOT require Cloud Functions; run it locally from your machine with Node.js installed.
 * WARNING: keep your service account JSON private.
 */

const admin = require('firebase-admin');
const fs = require('fs');

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
  const serviceAccountPath = argv.serviceAccount;
  const projectId = argv.projectId || process.env.GCLOUD_PROJECT;
  const title = argv.title || 'Sample Announcement';
  const body = argv.body || 'This is a sample notification generated locally.';
  const uniId = argv.uniId || null;
  const userId = argv.userId || null;

  if (!serviceAccountPath) {
    console.error('Missing --serviceAccount=./key.json');
    process.exit(1);
  }

  if (!fs.existsSync(serviceAccountPath)) {
    console.error('Service account file not found at:', serviceAccountPath);
    console.error('Place the JSON key file you downloaded from Google Cloud here, or pass the correct path via --serviceAccount=./path/to/key.json');
    process.exit(1);
  }

  let serviceAccount;
  try {
    serviceAccount = require(serviceAccountPath);
  } catch (e) {
    console.error('Failed to load service account JSON. Ensure it is valid JSON and the path is correct. Error:', e.message);
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId || serviceAccount.project_id,
  });

  const db = admin.firestore();

  try {
    // Create a notification doc
    const docRef = await db.collection('notifications').add({
      title,
      body,
      universityId: uniId || null,
      userId: userId || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isPushSent: false,
      data: {},
    });

    console.log('Created notification doc:', docRef.id);

    // Prepare payload
    const payload = {
      notification: {
        title,
        body,
      },
      data: { notificationId: docRef.id },
    };

    if (userId) {
      const tokensSnap = await db.collection('users').doc(userId).collection('fcmTokens').get();
      const tokens = tokensSnap.docs.map(d => d.id).filter(Boolean);
      if (tokens.length === 0) {
        console.log('No tokens found for user', userId);
      } else {
        // Use sendMulticast for multiple tokens
        const message = {
          notification: { title, body },
          data: payload.data,
          tokens: tokens,
        };
        try {
          const resp = await admin.messaging().sendMulticast(message);
          console.log('Sent to user tokens:', resp.responses.map(r => (r.success ? 'ok' : r.error ? r.error.message : 'failed')));
        } catch (err) {
          console.error('sendMulticast error:', err);
        }
      }
    } else {
      if (!uniId) {
        console.error('No uniId provided to broadcast to. Provide --uniId or --userId.');
        process.exit(1);
      }
      const topic = `university_${uniId}`;
      const message = {
        topic: topic,
        notification: { title, body },
        data: payload.data,
      };
      try {
        const resp = await admin.messaging().send(message);
        console.log('Sent to topic', topic, 'messageId:', resp);
      } catch (err) {
        console.error('send to topic error:', err);
      }
    }

    await docRef.update({ isPushSent: true });
    console.log('Marked notification isPushSent=true');
    process.exit(0);
  } catch (e) {
    console.error('Error creating or sending notification:', e);
    process.exit(2);
  }
}

main();
