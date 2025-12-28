/*
 * Local helper to send a notification document via FCM using a service account.
 * Usage:
 *   node tools/send_notification_local.js --serviceAccount=./serviceAccount.json --projectId=my-project-xxxx --notificationId=abc123
 *
 * This does NOT require deploying Cloud Functions. Run it from your development machine.
 * WARNING: keep your service account JSON private; don't commit it to source control.
 */

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

async function main() {
  const serviceAccountPath = argv.serviceAccount;
  const projectId = argv.projectId || process.env.GCLOUD_PROJECT;
  const notificationId = argv.notificationId;

  if (!serviceAccountPath || !notificationId) {
    console.error('Usage: node tools/send_notification_local.js --serviceAccount=./key.json --notificationId=<id> [--projectId=<projectId>]');
    process.exit(1);
  }

  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId || serviceAccount.project_id,
  });

  const db = admin.firestore();

  try {
    const docRef = db.collection('notifications').doc(notificationId);
    const snap = await docRef.get();
    if (!snap.exists) {
      console.error('Notification doc not found:', notificationId);
      process.exit(1);
    }

    const data = snap.data();
    const title = data.title || '';
    const body = data.body || '';
    const uniId = data.universityId || '';
    const targetUser = data.userId || null;
    const imageUrl = data.imageUrl || null;

    const payload = {
      notification: {
        title,
        body,
        image: imageUrl || undefined,
      },
      data: Object.assign({}, data.data || {}, { notificationId }),
    };

    if (targetUser) {
      const tokensSnap = await db.collection('users').doc(targetUser).collection('fcmTokens').get();
      const tokens = tokensSnap.docs.map(d => d.id).filter(Boolean);
      if (tokens.length === 0) {
        console.log('No tokens for user', targetUser);
        await docRef.update({ isPushSent: false });
        process.exit(0);
      }
      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log('Sent to user tokens, response:', response.results.map(r => r.error ? r.error.message : 'ok'));
    } else {
      if (!uniId) {
        console.error('No universityId to broadcast to');
        process.exit(1);
      }
      const topic = `university_${uniId}`;
      const resp = await admin.messaging().sendToTopic(topic, payload);
      console.log('Sent to topic', topic, 'response:', resp);
    }

    await docRef.update({ isPushSent: true });
    console.log('Marked notification isPushSent=true');
  } catch (e) {
    console.error('Error sending notification:', e);
    process.exit(2);
  }
}

main();
