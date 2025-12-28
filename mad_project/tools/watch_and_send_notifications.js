#!/usr/bin/env node
/*
 * Watch and send unsent notifications locally using the Admin SDK.
 * Usage:
 *   node tools/watch_and_send_notifications.js --serviceAccount=./serviceAccount.json [--projectId=my-project-xxx] [--pollInterval=10]
 *
 * This polls for `notifications` documents where `isPushSent == false` and attempts
 * to deliver them via FCM using the service account. Marked `isPushSent=true` on success.
 *
 * WARNING: Keep your service account JSON private. This script runs locally and
 * does not require deploying Cloud Functions or enabling Blaze billing.
 */

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

async function main() {
  const serviceAccountPath = argv.serviceAccount;
  const projectId = argv.projectId || process.env.GCLOUD_PROJECT;
  const pollIntervalSec = parseInt(argv.pollInterval || '10', 10);

  if (!serviceAccountPath) {
    console.error('Usage: node tools/watch_and_send_notifications.js --serviceAccount=./key.json [--projectId=my-project] [--pollInterval=10]');
    process.exit(1);
  }

  const path = require('path');
  const fs = require('fs');

  // Resolve the service account path relative to the current working directory
  const resolvedPath = path.isAbsolute(serviceAccountPath)
    ? serviceAccountPath
    : path.resolve(process.cwd(), serviceAccountPath);

  let serviceAccount;
  try {
    if (!fs.existsSync(resolvedPath)) {
      // Provide helpful diagnostics: show common candidate locations in repo
      console.error('Service account file not found at:', resolvedPath);
      console.error('Try one of the known locations in this repo:');
      console.error(' - ./serviceAccount.json');
      console.error(' - ./assets/service_account.json');
      console.error(' - ./tools/serviceAccountKey.json');
      console.error('Or pass an absolute path to the JSON key via --serviceAccount=/full/path/key.json');
      process.exit(1);
    }
    serviceAccount = require(resolvedPath);
  } catch (e) {
    console.error('Failed to load service account JSON. Ensure path is correct and JSON is valid. Error:', e.message || e);
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId || serviceAccount.project_id,
  });

  const db = admin.firestore();

  console.log(`Watching unsent notifications every ${pollIntervalSec}s...`);

  async function processBatch() {
    try {
      const query = db.collection('notifications').where('isPushSent', '==', false).orderBy('createdAt').limit(50);
      const snap = await query.get();
      if (snap.empty) return;

      for (const doc of snap.docs) {
        const data = doc.data();
        const notificationId = doc.id;
        const title = data.title || '';
        const body = data.body || '';
        const uniId = data.universityId || null;
        const targetUser = data.userId || null;
        const imageUrl = data.imageUrl || null;

        // Ensure data map contains only string values (required by FCM)
        const rawData = Object.assign({}, data.data || {});
        const dataMap = {};
        Object.keys(rawData).forEach((k) => {
          const v = rawData[k];
          dataMap[k] = (typeof v === 'string') ? v : JSON.stringify(v);
        });
        dataMap.notificationId = notificationId;

        const payload = {
          notification: {
            title,
            body,
            image: imageUrl || undefined,
          },
          data: dataMap,
        };

        try {
          if (targetUser) {
            const tokensSnap = await db.collection('users').doc(targetUser).collection('fcmTokens').get();
            const tokens = tokensSnap.docs.map(d => d.id).filter(Boolean);
            if (tokens.length === 0) {
              console.log('[skip] No tokens for user', targetUser, 'doc:', notificationId);
              await doc.ref.update({ isPushSent: false });
              continue;
            }
            // use sendMulticast
            const message = {
              notification: { title, body },
              data: payload.data,
              tokens: tokens,
            };
            const resp = await admin.messaging().sendMulticast(message);
            console.log('[sent] notification', notificationId, 'to user', targetUser, 'results:', resp.responses.map(r => (r.success ? 'ok' : r.error ? r.error.message : 'failed')));
          } else {
            if (!uniId) {
              console.log('[skip] no uniId for broadcast, doc:', notificationId);
              await doc.ref.update({ isPushSent: false });
              continue;
            }
            const topic = `university_${uniId}`;
            const msg = {
              topic: topic,
              notification: { title, body },
              data: payload.data,
            };
            const sendResp = await admin.messaging().send(msg);
            console.log('[sent] notification', notificationId, 'to topic', topic, 'messageId:', sendResp);
          }

          await doc.ref.update({ isPushSent: true });
        } catch (err) {
          console.error('[error] sending notification', notificationId, err);
          try { await doc.ref.update({ lastError: String(err), lastAttempt: admin.firestore.FieldValue.serverTimestamp() }); } catch (_) {}
        }
      }
    } catch (e) {
      console.error('Error processing notifications batch:', e);
    }
  }

  // Poll loop
  setInterval(processBatch, Math.max(2000, pollIntervalSec * 1000));

  // Also run once immediately
  processBatch();
}

main();
